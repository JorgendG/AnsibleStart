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

$ImageName = Get-Attr -obj $params -name ImageName 
$GroupName = Get-Attr -obj $params -name GroupName
$FilePath = Get-Attr -obj $params -name FilePath

$state = Get-Attr -obj $params -name state -default "present"

if ("present", "absent", "init" -notcontains $state) {
    Fail-Json $result "The state: $state doesn't exist; State can only be: present, absent or init"
}

Function InstallWDSImage {
    #group empty means a bootimage
    if ( "" -eq $GroupName) {
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
        $CheckImage = Get-WDSInstallImage -ImageName $ImageName
        if ( -not $CheckImage ) {
            if ( -not (Get-WDSInstallImageGroup -Name $GroupName -ErrorAction SilentlyContinue) ) {
                New-WDSInstallImageGroup -Name $GroupName
            }
            Import-WDSInstallImage -path $FilePath -ImageName $ImageName -ImageGroup $GroupName
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

Function InitWDSServer {
    $regvalue = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSTFTP -Name "RootFolder" -ErrorAction SilentlyContinue

    if ($null -eq $regvalue.RootFolder) {
        & wdsutil.exe /initialize-server /reminst:"c:\RemoteInstall" /standalone
        & WDSUTIL.exe /Set-Server /Transport /EnableTftpVariableWindowExtension:No
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
        "init" { InitWDSServer }
    }

    Exit-Json $result;
}
Catch {
    Fail-Json $result $_.Exception.Message
}