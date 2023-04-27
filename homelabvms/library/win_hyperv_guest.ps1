#!powershell
# This file is part of Ansible
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.

# WANT_JSON
# POWERSHELL_COMMON

$params = Parse-Args $args;

$result = @{};
Set-Attr $result "changed" $false;

$name = Get-Attr -obj $params -name name -failifempty $true -emptyattributefailmessage "missing required argument: name"
$memory = Get-Attr -obj $params -name memory -default '512MB'
$generation = Get-Attr -obj $params -name generation -default 2
$network_switch = Get-Attr -obj $params -name network_switch -default $null
$cpu = Get-Attr -obj $params -name cpu -default 1
$diskpath = Get-Attr -obj $params -name diskpath -default $null

$state = Get-Attr -obj $params -name state -default "present"

if ("present", "absent", "started", "stopped" -notcontains $state) {
    Fail-Json $result "The state: $state doesn't exist; State can only be: present, absent, started or stopped"
}

Function VMCreate {
    #Check If the VM already exists
    $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue

    if (!$CheckVM) {
        $cmd = "New-VM -Name $name"

        if ($memory) {
            $cmd += " -MemoryStartupBytes $memory"
        }

        if ($generation) {
            $cmd += " -Generation $generation"
        }

        if ($network_switch) {
            $cmd += " -SwitchName $network_switch"
        }

        if ($diskpath) {
            #If VHD already exists then attach it, if not create it
            if (Test-Path $diskpath) {
                $cmd += " -VHDPath $diskpath"
            }
            else {
                $cmd += " -NewVHDPath $diskpath -NewVHDSizeBytes 100GB"
            }
        }

        $null = invoke-expression $cmd
        $newmac = NextMac
        $null = Set-VMNetworkAdapter -vmname $name -StaticMacAddress $newmac
        $null = Set-VM -name $name -ProcessorCount $cpu -DynamicMemory
        # write-host NextMac
        $result.changed = $true
        $result.vmname = $name
        $result.macaddress = $newmac
    }
    else {
        $result.changed = $false
        $result.vmname = $name
        $result.macaddress = ($CheckVM | Get-VMNetworkAdapter | Select-Object MacAddress).macaddress
    }
}

Function VMDelete {
    $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue

    if ($CheckVM) {
        if ($CheckVM.State -ne 'Off') {
            $null = $CheckVM | Stop-VM -TurnOff -Force -ErrorAction SilentlyContinue
        }
        $CheckVM | Remove-VM -Force
        $result.changed = $true
    }
    else {
        $result.changed = $false
    }
}

Function VMStart {
    $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue

    if ($CheckVM) {
        if ($CheckVM.State -ne 'Running') {
            $null = $CheckVM | Start-VM -ErrorAction SilentlyContinue
            $result.changed = $true
        }
        else {
            $result.changed = $false
        }
    }
    else {
        Fail-Json $result "The VM: $name; Doesn't exists please create the VM first"
    }
}

Function VMShutdown {
    $CheckVM = Get-VM -name $name -ErrorAction SilentlyContinue

    if ($CheckVM) {
        if ( $CheckVM.State -ne 'Off') {
            $CheckVM | Stop-VM
            $result.changed = $true
        }
        else {
            $result.changed = $false
        }
    }
    else {
        Fail-Json $result "The VM: $name; Doesn't exists please create the VM first"
    }
}

function NextMac {
    $AllNICs = Get-VM | Get-VMNetworkAdapter | Where-Object { $_.MacAddress -ne "000000000000" } | Select-Object macaddress
    $hostmacs = get-vmhost | Select-Object MacAddressMinimum, MacAddressMaximum
        
    $macfound = $true
    $firstmac = $hostmacs.MacAddressMinimum
    $asint = [Convert]::ToInt64("0x$firstmac", 16)
    $x = 0
    do {
        $nextmac = $asint + $x
        $nextmac = '00{0:X10}' -f $nextmac

        $macfound = $AllNICs.MacAddress -contains $nextmac
        $x += 1
    }
    until (-not $macfound )
    $nextmac 
}


Try {
    switch ($state) {
        "present" { VMCreate }
        "absent" { VMDelete }
        "started" { VMStart }
        "stopped" { VMShutdown }
    }

    Exit-Json $result;
}
Catch {
    Fail-Json $result $_.Exception.Message
}