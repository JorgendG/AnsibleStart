#Requires -Module Ansible.ModuleUtils.Legacy
#Requires -Module Ansible.ModuleUtils.Backup

Set-StrictMode -Version 2

$params = Parse-Args $args -supports_check_mode $false

$ipaddress = Get-AnsibleParam $params "ipaddress" -type "str" 
$ipsubnet = Get-AnsibleParam $params "ipsubnet" -type "str" -Default 24
$ipgw = Get-AnsibleParam $params "gateway" -type "str"
$adapter = Get-AnsibleParam $params "adapter" -type "str" -Default "Ethernet"
$state = Get-AnsibleParam $params "state" -type "str" -Default "present"

$result = @{
    changed = $false
}

if ($state -eq "absent") {

}
else {
    $ipadapter = Get-NetIPAddress -InterfaceAlias $adapter -AddressFamily IPv4

    if ($ipadapter.IPAddress -ne $ipaddress ) {
        try {
            New-NetIPAddress -InterfaceAlias $adapter -IPAddress $ipaddress -PrefixLength $ipsubnet -DefaultGateway $ipgw | Out-Null
            $result.changed = $true
        }
        catch {
            Fail-Json $result "An error occurred trying to configure the ipaddress, $($ipaddress). Error: $($_)"
        }

    }

    
}

Exit-Json $result