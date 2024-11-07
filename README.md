# LUA-based-Port-Security
LUA + TC Port Security
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Port Security Lua Script - User Guide</title>
<style>
    body {
        font-family: Arial, sans-serif;
        line-height: 1.6;
        margin: 20px;
    }
    h1, h2, h3 {
        color: #2c3e50;
    }
    pre {
        background-color: #f4f4f4;
        padding: 10px;
        overflow-x: auto;
    }
    code {
        background-color: #f4f4f4;
        padding: 2px 4px;
    }
    ul {
        margin-left: 20px;
    }
</style>
</head>
<body>

<h1>User Guide for the Port Security Lua Script</h1>

<p>This guide provides detailed instructions on how to use the Lua script designed to implement port security by limiting the number of allowed MAC addresses on a specified Ethernet interface.</p>

<h2>Overview</h2>

<p>The script monitors MAC addresses on a specified Ethernet interface and allows only a predefined number of MAC addresses to communicate through it. Any additional MAC addresses beyond the set limit are blocked. This is useful for enhancing network security by preventing unauthorized devices from accessing the network through that interface.</p>

<h2>Prerequisites</h2>

<p>Before running the script, ensure that you have the following:</p>

<ul>
    <li><strong>Operating System:</strong> A Unix-like operating system (e.g., Linux).</li>
    <li><strong>Lua Interpreter:</strong> The script requires Lua to be installed. You can install it using your package manager:
        <pre><code>sudo apt-get install lua5.3  # For Debian/Ubuntu
sudo yum install lua         # For CentOS/RHEL</code></pre>
    </li>
    <li><strong>Administrative Privileges:</strong> The script needs to execute system commands that require root privileges. You should run the script as the root user or use <code>sudo</code>.</li>
    <li><strong>Traffic Control Tools:</strong> The script uses the <code>tc</code> (traffic control) command and the <code>bridge</code> utility. Ensure these are installed:
        <pre><code>sudo apt-get install iproute2  # Includes 'tc' and 'bridge' commands</code></pre>
    </li>
</ul>

<h2>Usage</h2>

<p>The basic syntax for running the script is:</p>

<pre><code>sudo lua port_security.lua &lt;interface&gt; [--max-mac N] [--skip-sw]</code></pre>

<ul>
    <li><code>&lt;interface&gt;</code>: The Ethernet interface you want to monitor (e.g., <code>eth0</code>).</li>
    <li><code>--max-mac N</code>: (Optional) Set the maximum number of allowed MAC addresses. Default is <code>1</code>.</li>
    <li><code>--skip-sw</code>: (Optional) Enable hardware offloading by adding the <code>skip_sw</code> parameter to <code>tc</code> commands.</li>
</ul>

<h3>Examples</h3>

<ul>
    <li><strong>Monitor interface <code>eth0</code> with default settings:</strong>
        <pre><code>sudo lua port_security.lua eth0</code></pre>
    </li>
    <li><strong>Set maximum allowed MAC addresses to 3 on interface <code>eth1</code>:</strong>
        <pre><code>sudo lua port_security.lua eth1 --max-mac 3</code></pre>
    </li>
    <li><strong>Enable hardware offloading on interface <code>eth0</code>:</strong>
        <pre><code>sudo lua port_security.lua eth0 --skip-sw</code></pre>
    </li>
    <li><strong>Combine options:</strong>
        <pre><code>sudo lua port_security.lua eth1 --max-mac 2 --skip-sw</code></pre>
    </li>
</ul>

<h2>How the Script Works</h2>

<ol>
    <li><strong>Initialization:</strong>
        <ul>
            <li>Clears existing traffic control (<code>tc</code>) filters on the specified interface.</li>
            <li>Initializes the necessary <code>tc</code> chains and filters.</li>
            <li>Clears the Forwarding Database (FDB) entries for the interface.</li>
            <li>Sets up a default drop rule to block all traffic not explicitly allowed.</li>
        </ul>
    </li>
    <li><strong>Monitoring:</strong>
        <ul>
            <li>Continuously monitors the FDB for new MAC addresses appearing on the interface.</li>
            <li>Allows traffic from new MAC addresses up to the maximum limit.</li>
            <li>Logs and blocks any additional MAC addresses beyond the set limit.</li>
        </ul>
    </li>
    <li><strong>MAC Address Files:</strong>
        <ul>
            <li><strong>Allowed MAC Addresses:</strong>
                <ul>
                    <li>Stored in <code>/tmp/allowed_macs_&lt;interface&gt;.txt</code>.</li>
                    <li>Contains a list of MAC addresses currently allowed.</li>
                </ul>
            </li>
            <li><strong>Blocked MAC Addresses:</strong>
                <ul>
                    <li>Stored in <code>/tmp/blocked_macs_&lt;interface&gt;.txt</code>.</li>
                    <li>Contains a list of MAC addresses that have been blocked due to exceeding the limit.</li>
                </ul>
            </li>
        </ul>
    </li>
</ol>

<h2>Detailed Steps</h2>

<h3>1. Running the Script</h3>

<ul>
    <li><strong>Ensure You Have Root Privileges:</strong>
        <ul>
            <li>The script must be run with administrative privileges to execute system commands like <code>tc</code> and <code>bridge</code>.</li>
            <li>Use <code>sudo</code> if necessary.</li>
        </ul>
    </li>
    <li><strong>Execute the Script:</strong>
        <ul>
            <li>Use the Lua interpreter to run the script with the desired arguments.</li>
            <li>Example:
                <pre><code>sudo lua port_security.lua eth0 --max-mac 2</code></pre>
            </li>
        </ul>
    </li>
</ul>

<h3>2. Monitoring Output</h3>

<ul>
    <li><strong>Real-Time Feedback:</strong>
        <ul>
            <li>The script provides real-time feedback in the terminal.</li>
            <li>It displays the list of detected MAC addresses and indicates when a new MAC address is allowed or blocked.</li>
        </ul>
    </li>
    <li><strong>Allowed MAC Addresses:</strong>
        <ul>
            <li>When a new MAC address is allowed, you will see a message like:
                <pre><code>Added allowed MAC address: 00:11:22:33:44:55</code></pre>
            </li>
        </ul>
    </li>
    <li><strong>Blocked MAC Addresses:</strong>
        <ul>
            <li>When the maximum limit is reached, and a new MAC address is detected, you will see:
                <pre><code>Maximum number of allowed MAC addresses reached. Blocking new MAC address: 66:77:88:99:AA:BB</code></pre>
            </li>
        </ul>
    </li>
</ul>

<h3>3. Stopping the Script</h3>

<ul>
    <li><strong>Terminate Execution:</strong>
        <ul>
            <li>To stop the script, interrupt it by pressing <code>Ctrl+C</code> in the terminal.</li>
        </ul>
    </li>
</ul>

<h3>4. Modifying Allowed MAC Addresses</h3>

<ul>
    <li><strong>Manually Editing the Allowed MAC File:</strong>
        <ul>
            <li>You can manually add MAC addresses to the allowed list by editing the file <code>/tmp/allowed_macs_&lt;interface&gt;.txt</code>.</li>
            <li>After editing, restart the script to apply the changes.</li>
        </ul>
    </li>
    <li><strong>Refreshing Allowed MAC Addresses:</strong>
        <ul>
            <li>The script reads the allowed MAC addresses file during initialization.</li>
            <li>Any changes made to the file while the script is running will not take effect until the script is restarted.</li>
        </ul>
    </li>
</ul>

<h2>Important Notes</h2>

<ul>
    <li><strong>Impact on Network Traffic:</strong>
        <ul>
            <li>The script modifies network filters and can disrupt network connectivity on the specified interface.</li>
            <li>Use caution and, if possible, test in a controlled environment before deploying in production.</li>
        </ul>
    </li>
    <li><strong>Hardware Offloading (<code>--skip-sw</code>):</strong>
        <ul>
            <li>Enabling hardware offloading can improve performance by processing filters in network hardware.</li>
            <li>Ensure your network interface supports hardware offloading before using this option.</li>
        </ul>
    </li>
    <li><strong>System Compatibility:</strong>
        <ul>
            <li>The script relies on the <code>tc</code> and <code>bridge</code> commands, which are part of the <code>iproute2</code> package.</li>
            <li>Ensure your system has these utilities and they are compatible with the version of Lua installed.</li>
        </ul>
    </li>
    <li><strong>Permissions:</strong>
        <ul>
            <li>The script writes to files in <code>/tmp</code>. Ensure the user running the script has appropriate permissions.</li>
        </ul>
    </li>
</ul>

<h2>Troubleshooting</h2>

<ul>
    <li><strong>Error Messages:</strong>
        <ul>
            <li>If you encounter error messages related to executing system commands, check that:
                <ul>
                    <li>You have the necessary privileges.</li>
                    <li>The commands (<code>tc</code>, <code>bridge</code>) are installed and accessible.</li>
                </ul>
            </li>
        </ul>
    </li>
    <li><strong>No MAC Addresses Detected:</strong>
        <ul>
            <li>Ensure there is network activity on the interface.</li>
            <li>The script monitors the FDB, which is populated when devices communicate through the interface.</li>
        </ul>
    </li>
    <li><strong>Script Does Not Block Unallowed MAC Addresses:</strong>
        <ul>
            <li>Verify that the default drop rule is added successfully during initialization.</li>
            <li>Check for any error messages during the script startup.</li>
        </ul>
    </li>
</ul>

<h2>Customization</h2>

<ul>
    <li><strong>Adjusting Monitoring Frequency:</strong>
        <ul>
            <li>By default, the script checks for new MAC addresses every second.</li>
            <li>You can adjust the frequency by modifying the sleep duration in the <code>monitor_mac_addresses</code> function:
                <pre><code>os.execute("sleep 1")  -- Change '1' to the desired number of seconds</code></pre>
            </li>
        </ul>
    </li>
    <li><strong>Changing File Paths:</strong>
        <ul>
            <li>If you prefer to store the allowed and blocked MAC addresses in a different location, modify the <code>ALLOWED_MAC_FILE</code> and <code>BLOCKED_MAC_FILE</code> variables accordingly.</li>
        </ul>
    </li>
</ul>

<h2>Safety Precautions</h2>

<ul>
    <li><strong>Backup Configuration:</strong>
        <ul>
            <li>Before running the script, consider backing up your network configuration.</li>
            <li>Be prepared to restore settings in case of unintended network disruptions.</li>
        </ul>
    </li>
    <li><strong>Test Environment:</strong>
        <ul>
            <li>It's recommended to test the script in a non-production environment to understand its effects.</li>
        </ul>
    </li>
    <li><strong>Documentation:</strong>
        <ul>
            <li>Familiarize yourself with the <code>tc</code> and <code>bridge</code> commands.</li>
            <li>Understand how traffic control and filtering work on your system.</li>
        </ul>
    </li>
</ul>

<h2>Contact and Support</h2>

<ul>
    <li><strong>Script Maintenance:</strong>
        <ul>
            <li>Ensure the script is maintained and updated as needed, especially if there are changes to system utilities or the operating system.</li>
        </ul>
    </li>
    <li><strong>Further Assistance:</strong>
        <ul>
            <li>If you need help or have questions about the script, consider reaching out to network administrators or professionals experienced with Lua scripting and Linux networking.</li>
        </ul>
    </li>
</ul>

<hr>

<p>By following this guide, you should be able to effectively utilize the port security Lua script to enhance the security of your network by controlling access based on MAC addresses.</p>

</body>
</html>
