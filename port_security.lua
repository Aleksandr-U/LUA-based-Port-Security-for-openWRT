#!/usr/bin/lua

-- Declare local variables for the interface and parameters
local IFACE
local MAX_MAC_ADDRESSES = 1
local SKIP_SW = false  -- Set to false by default; use '--skip-sw' to enable

-- Variables for storing files for MAC addresses
local ALLOWED_MAC_FILE
local BLOCKED_MAC_FILE

-- Flag to control the script's operation
local running = true

-- Tables for storing MAC addresses
local allowed_macs = {}
local blocked_macs = {}

-- Global counter for unique handles
local handle_counter = 1
local allowed_count = 0

-- Function to display usage message and exit the script
local function usage()
    io.write("Error: Ethernet port not specified.\n")
    io.write("Please specify the interface when running the script.\n")
    io.write("Usage: port_security.lua <interface> [--max-mac N] [--skip-sw]\n")
    os.exit(1)
end

-- Parsing command line arguments
local function parse_arguments()
    -- Check if at least one argument (interface) is provided
    if #arg < 1 then
        usage()
    end

    -- First argument is the interface
    IFACE = arg[1]
    if IFACE:sub(1, 3) ~= "eth" then
        io.write("Warning: Interface usually starts with 'eth'. No validity check performed.\n")
    end

    -- Create unique files for each port
    ALLOWED_MAC_FILE = "/tmp/allowed_macs_" .. IFACE .. ".txt"
    BLOCKED_MAC_FILE = "/tmp/blocked_macs_" .. IFACE .. ".txt"

    -- Process other arguments
    local i = 2
    while i <= #arg do
        if arg[i] == "--max-mac" and arg[i+1] then
            local num = tonumber(arg[i+1])
            if num and num > 0 then
                MAX_MAC_ADDRESSES = num
            else
                io.write("Warning: Invalid value for --max-mac. Using default value: " .. MAX_MAC_ADDRESSES .. "\n")
            end
            i = i + 1
        elseif arg[i] == "--skip-sw" then
            SKIP_SW = true
        else
            io.write("Warning: Unknown argument: " .. arg[i] .. "\n")
        end
        i = i + 1
    end
end

-- Function to execute system commands
local function exec_cmd(cmd, silent)
    if not silent then
        io.write("Executing command: " .. cmd .. "\n")
    end
    local handle = io.popen(cmd .. " 2>&1")
    local result = handle:read("*a")
    local success, _, _ = handle:close()
    if not success and not silent then
        io.write("Error executing command: " .. cmd .. "\n")
        io.write("Error message: " .. result .. "\n")
    end
    return success, result
end

-- Function to initialize filters
local function init_filters()
    -- Remove existing filters
    exec_cmd("tc qdisc del dev " .. IFACE .. " clsact 2>/dev/null", true)
    exec_cmd("tc qdisc add dev " .. IFACE .. " clsact", true)

    -- Clear MAC address files
    local file = io.open(ALLOWED_MAC_FILE, "w")
    if file then file:close() end

    file = io.open(BLOCKED_MAC_FILE, "w")
    if file then file:close() end

    -- Add rule in chain 0 to jump to chain 8000000
    local handle = get_unique_handle()
    local cmd = string.format("tc filter add dev %s ingress protocol all prio 1 handle %s flower action goto chain 8000000", IFACE, handle)
    exec_cmd(cmd, true)

    io.write("Filter initialization completed.\n")
end

-- Function to clear FDB
local function clear_fdb_entries()
    exec_cmd("bridge fdb flush dev " .. IFACE)
    io.write("FDB for interface " .. IFACE .. " cleared.\n")
end

-- Function to generate unique handle
local function get_unique_handle()
    local handle = string.format("0x%x", handle_counter)
    handle_counter = handle_counter + 1
    return handle
end

-- Function to add an allow rule for a MAC address
local function add_mac_rule(mac_address)
    -- Form hardware offload parameter
    local skip_sw_param = SKIP_SW and "skip_sw" or ""

    -- Generate unique handle
    local handle = get_unique_handle()

    -- Add allow rule for the MAC address in chain 8000000
    local cmd = string.format(
        "tc filter add dev %s ingress protocol all prio 10 handle %s chain 8000000 flower %s src_mac %s/ff:ff:ff:ff:ff:ff action pass",
        IFACE, handle, skip_sw_param, mac_address
    )
    local success, result = exec_cmd(cmd, true)
    if success then
        -- Add MAC address to allowed list
        allowed_macs[mac_address] = true

        -- Write MAC address to allowed file
        local file = io.open(ALLOWED_MAC_FILE, "a")
        if file then
            file:write(mac_address .. "\n")
            file:close()
        end

        io.write("\nAdded allowed MAC address: " .. mac_address .. "\n")
    else
        io.write("Failed to add allow rule for MAC address: " .. mac_address .. "\n")
        io.write("Error message: " .. result .. "\n")
    end
end

-- Function to add a default drop rule to block all other traffic
local function add_default_drop_rule()
    -- Form hardware offload parameter
    local skip_sw_param = SKIP_SW and "skip_sw" or ""

    -- Generate unique handle
    local handle = get_unique_handle()

    -- Add drop rule in chain 8000000
    local cmd = string.format(
        "tc filter add dev %s ingress protocol all prio 20 handle %s chain 8000000 flower %s action drop",
        IFACE, handle, skip_sw_param
    )
    local success, result = exec_cmd(cmd, true)
    if success then
        io.write("Default drop rule added to block all other traffic.\n")
    else
        io.write("Failed to add default drop rule.\n")
        io.write("Error message: " .. result .. "\n")
    end
end

-- Function to log blocked MAC addresses
local function log_blocked_mac(mac_address)
    -- Check if MAC address has already been blocked
    if not blocked_macs[mac_address] then
        blocked_macs[mac_address] = true

        -- Write MAC address to blocked file
        local file = io.open(BLOCKED_MAC_FILE, "a")
        if file then
            file:write(mac_address .. "\n")
            file:close()
        end

        io.write("\nMaximum number of allowed MAC addresses reached. Blocking new MAC address: " .. mac_address .. "\n")
    end
end

-- Function to get list of MAC addresses from FDB on the specified interface
local function get_mac_addresses_from_fdb()
    local success, result = exec_cmd("bridge fdb show dev " .. IFACE, true)
    if not success then
        io.write("Failed to get list of MAC addresses from FDB.\n")
        return {}
    end

    local macs = {}
    for line in result:gmatch("[^\r\n]+") do
        -- Check for 'extern_learn' or 'dynamic' in the line
        if line:find("extern_learn") or line:find("dynamic") then
            local mac = line:match("^(%S+)%s")
            if mac then
                macs[mac] = true
            end
        end
    end
    return macs
end

-- Function to monitor new MAC addresses
local function monitor_mac_addresses()
    while running do
        -- Get current MAC addresses from FDB
        local current_macs = get_mac_addresses_from_fdb()

        -- Form string to display current MAC addresses
        local mac_list = ""
        for mac in pairs(current_macs) do
            mac_list = mac_list .. mac .. " "
        end

        -- Update screen output
        io.write("\rDetected MAC addresses: " .. mac_list)
        io.flush()

        for mac in pairs(current_macs) do
            if not allowed_macs[mac] and not blocked_macs[mac] then
                if allowed_count < MAX_MAC_ADDRESSES then
                    add_mac_rule(mac)
                    allowed_count = allowed_count + 1
                else
                    log_blocked_mac(mac)
                end
            end
        end

        -- Delay before next check
        os.execute("sleep 1")
    end
end

-- Function to refresh the allowed MAC addresses file
local function refresh_allowed_mac_file()
    local file = io.open(ALLOWED_MAC_FILE, "r")
    if file then
        local new_macs = {}
        for line in file:lines() do
            local mac = line:match("^%s*(.-)%s*$")
            if mac ~= "" and not allowed_macs[mac] then
                new_macs[#new_macs + 1] = mac
            end
        end
        file:close()

        if #new_macs > 0 then
            -- Check if new MAC addresses can be added
            if allowed_count + #new_macs <= MAX_MAC_ADDRESSES then
                for _, mac in ipairs(new_macs) do
                    add_mac_rule(mac)
                    allowed_count = allowed_count + 1
                else
                    io.write("Cannot add new MAC addresses: limit exceeded.\n")
                end
            else
                io.write("Cannot add new MAC addresses: limit exceeded.\n")
            end
        end
    end
end

-- Main function
local function main()
    -- Parse command line arguments
    parse_arguments()

    -- Initialize filters
    init_filters()

    -- Clear FDB for the target interface
    clear_fdb_entries()

    -- Add default drop rule to block all other traffic
    add_default_drop_rule()

    -- Read previously allowed MAC addresses
    refresh_allowed_mac_file()

    -- Read previously blocked MAC addresses
    local file = io.open(BLOCKED_MAC_FILE, "r")
    if file then
        for line in file:lines() do
            local mac = line:match("^%s*(.-)%s*$")
            if mac ~= "" then
                blocked_macs[mac] = true
            end
        end
        file:close()
    end

    -- Start monitoring MAC addresses
    monitor_mac_addresses()
end

main()

