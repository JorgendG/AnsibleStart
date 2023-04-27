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
Set-Attr $result "changed" $true;

$name = Get-Attr -obj $params -name name -failifempty $true -emptyattributefailmessage "missing required argument: name"
$macaddress = Get-Attr -obj $params -name macaddress
$unattend = Get-Attr -obj $params -name unattend -default 'install2016ans.xml'


$state = Get-Attr -obj $params -name state -default "present"

if ("present","absent" -notcontains $state) {
    Fail-Json $result "The state: $state doesn't exist; State can only be: present, absent, started or stopped"
}

function NewWDSReservation {
    Get-WdsClient -DeviceName $name | Remove-WdsClient
    Get-WdsClient -DeviceId $macaddress | Remove-WdsClient
    $results = New-WdsClient -DeviceName $name -DeviceID $macaddress -PxePromptPolicy NoPrompt `
                -WdsClientUnattend "WdsClientUnattend\$unattend" -JoinDomain:$false 
    $result.changed = $true
}

function DeleteWDSReservation {
    $clientname = Get-WdsClient -DeviceName $name | Remove-WdsClient
    $clientmac = Get-WdsClient -DeviceId $macaddress | Remove-WdsClient
    if ($clientname -or $clientmac) {
        $result.changed = $true
    }
    else {
        $result.changed = $false
    }
}

Try {
    switch ($state) {
		"present" {
            NewWDSReservation
        }
        "absent" {
            DeleteWDSReservation
        }
	}

    Exit-Json $result;
} Catch {
    Fail-Json $result $_.Exception.Message
}
