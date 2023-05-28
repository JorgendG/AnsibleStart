#Requires -Module Ansible.ModuleUtils.Legacy
#Requires -Module Ansible.ModuleUtils.Backup

Set-StrictMode -Version 2

$params = Parse-Args $args -supports_check_mode $false

$name = Get-AnsibleParam $params "name" -type "str" -Default "NuGet"
$state = Get-AnsibleParam $params "state" -type "str" -Default "present"

$result = @{
    changed = $false
}

if ( $state -eq 'present') {

    if ( Get-PackageProvider $Name -ErrorAction SilentlyContinue) {
        $result.changed = $false
    }
    else {
        try {
            Install-PackageProvider -Name $Name -Force
            $result.changed = $true
        }
        catch {
            Fail-Json $result "Failed to install the required PowerShell PackageProvider. Error: $($_)"
        }
    }
}

if ( $state -eq 'absent') {

    if ( -not (Get-PackageProvider $Name)) {
        $result.changed = $false
    }
    else {
        # todo
    }
}

Exit-Json $result