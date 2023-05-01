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

$ImageName = Get-Attr -obj $params -name name -failifempty $true -emptyattributefailmessage "missing required argument: name"
$group = Get-Attr -obj $params -name group
$FilePath = Get-Attr -obj $params -name dest

$state = Get-Attr -obj $params -name state -default "present"

if ("present", "absent" -notcontains $state) {
    Fail-Json $result "The state: $state doesn't exist; State can only be: present, absent, started or stopped"
}

Function InstallWDSImage {
    #group empty means a bootimage
    if ( $null -eq $group) {
        $CheckImage = Get-WdsBootImage -ImageName $ImageName
        if ( -not $CheckImage ) {
            Import-WdsBootImage -Path $FilePath
            $result.changed = $true
        }
        else {
            $result.changed = $false
        }
    }
    else {
        $CheckImage = Import-WDSInstallImage -ImageName $ImageName
        if ( -not $CheckImage ) {
            if ( -not (Get-WDSInstallGroup -Name $group) ) {
                New-WDSInstallImageGroup -Name $group
            }
            Import-WDSInstallImage -path $FilePath -ImageName $ImageName -ImageGroup $group
            $result.changed = $true
        }
        else {
            {
                $result.changed = $false
            }
        }
    }
}

Function RemoveWDSImage {
    $CheckImage = Import-WDSInstallImage -ImageName $ImageName

    if ($CheckImage) {
        Remove-WDSInstallImage -ImageName $ImageName -ImageGroup $group
        $CheckVM | Remove-VM -Force
        $result.changed = $true
    }
    else {
        $result.changed = $false
    }
}





Try {
    switch ($state) {
        "present" { InstallWDSImage }
        "absent" { RemoveWDSImage }
    }

    Exit-Json $result;
}
Catch {
    Fail-Json $result $_.Exception.Message
}