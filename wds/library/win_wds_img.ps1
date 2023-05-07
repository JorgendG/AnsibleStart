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
$Unattendfile = Get-Attr -obj $params -name Unattendfile
$GroupName = Get-Attr -obj $params -name GroupName
$FilePath = Get-Attr -obj $params -name FilePath
$Answer = Get-Attr -obj $params -name Answer

$rootfolder = Get-Attr -obj $params -name rootfolder
$wdsusername = Get-Attr -obj $params -name wdsusername
$wdsuserpass = Get-Attr -obj $params -name wdsuserpass
$localadminpass = Get-Attr -obj $params -name localadminpass



$state = Get-Attr -obj $params -name state -default "present"

if ("present", "absent", "init", "answer" -notcontains $state) {
    Fail-Json $result "The state: $state doesn't exist; State can only be: present, absent, init or answer"
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
            #Fail-Json $result "The Unattendfile: $Unattendfile "
            Import-WDSInstallImage -path $FilePath -ImageName $ImageName -ImageGroup $GroupName -UnattendFile "C:\WDSImages\InstallImage.xml"
            [xml]$xml = Get-Content "C:\WDSImages\installOS.xml"
            $winpe = $xml.unattend.settings | Where-Object { $_.pass -eq 'windowsPE' }
            $winpe.component.Where( { $_.name -eq 'Microsoft-Windows-Setup' } ).WindowsDeploymentServices.ImageSelection.InstallImage.ImageName = $ImageName
            $winpe.component.Where( { $_.name -eq 'Microsoft-Windows-Setup' } ).WindowsDeploymentServices.ImageSelection.InstallImage.ImageGroup = $GroupName
            $xml.Save( "$rootfolder\WdsClientUnattend\$($Unattendfile)" )
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
        Remove-WDSInstallImage -ImageName $ImageName -ImageGroup $GroupName
        
        $result.changed = $true
    }
    else {
        $result.changed = $false
    }
}

Function InitWDSServer {
    $regvalue = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSTFTP -Name "RootFolder" -ErrorAction SilentlyContinue

    if ($null -eq $regvalue.RootFolder) {
        & wdsutil.exe /initialize-server /reminst:"$rootfolder" /standalone
        & WDSUTIL.exe /Set-Server /Transport /EnableTftpVariableWindowExtension:No
        $result.changed = $true
    }
    else {
        $result.changed = $false
    }
    CreateImageUnattend
    CreateOSUnattend
}

Function AnswerWDSServer {
    $clientsknown = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSPXE\Providers\BINLSVC -Name "netbootAnswerOnlyValidClients" -ErrorAction SilentlyContinue
    $clientsnone = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSPXE\Providers\BINLSVC -Name "netbootAnswerRequests" -ErrorAction SilentlyContinue

    if ( ($clientsnone.netbootAnswerRequests -eq "FALSE") -and ($Answer -eq "none")) {
        $result.changed = $false
        return
    }
    if (  ($Answer -eq "none")) {
        & wdsutil.exe /set-server /AnswerClients:"$Answer"
        $result.changed = $true
        return
    }
    if ( ($clientsknown.netbootAnswerOnlyValidClients -eq "TRUE") -and ($Answer -eq "known") ) {
        $result.changed = $false
        return
    }
    if (  ($Answer -eq "known")) {
        & wdsutil.exe /set-server /AnswerClients:"$Answer"
        $result.changed = $true
        return
    }
    if ( ($clientsknown.netbootAnswerOnlyValidClients -eq "TRUE") -and ($Answer -eq "all") ) {
        $result.changed = $false
        return
    }
    if (  ($Answer -eq "all")) {
        & wdsutil.exe /set-server /AnswerClients:"$Answer"
        $result.changed = $true
        return
    }
}

Function CreateImageUnattend {
    $testfile = Test-Path "C:\WdsImages\InstallImage.xml"

    if (-not $testfile) {
        $xmlunattend = [xml]'<unattend xmlns="urn:schemas-microsoft-com:unattend">
        <settings pass="generalize">
          <component name="Microsoft-Windows-Security-SPP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipRearm>1</SkipRearm>
          </component>
          <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
          </component>
          <component name="Microsoft-Windows-IE-InternetExplorer" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DisableFirstRunWizard>true</DisableFirstRunWizard>
          </component>
        </settings>
        <settings pass="specialize">
          <component name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipAutoActivation>true</SkipAutoActivation>
          </component>
          <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <TimeZone>GMT Standard Time</TimeZone>
            <ComputerName>%MACHINENAME%</ComputerName>
          </component>
          <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <fDenyTSConnections>false</fDenyTSConnections>
          </component>
          <component name="Microsoft-Windows-TerminalServices-RDP-WinStationExtensions" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserAuthentication>0</UserAuthentication>
          </component>
          <component name="Microsoft-Windows-IE-ESC" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <IEHardenAdmin>false</IEHardenAdmin>
            <IEHardenUser>false</IEHardenUser>
          </component>
          <component name="Microsoft-Windows-ServerManager-SvrMgrNc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DoNotOpenServerManagerAtLogon>true</DoNotOpenServerManagerAtLogon>
          </component>
          <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <FirewallGroups>
              <FirewallGroup wcm:action="add" wcm:keyValue="rd1">
                <Profile>all</Profile>
                <Active>true</Active>
                <Group>Remote Desktop</Group>
              </FirewallGroup>
            </FirewallGroups>
          </component>
        </settings>
        <settings pass="oobeSystem">
          <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserAccounts>
              <AdministratorPassword>
                <Value></Value>
                <PlainText>true</PlainText>
              </AdministratorPassword>
            </UserAccounts>
            <OOBE>
              <HideEULAPage>true</HideEULAPage>
              <SkipMachineOOBE>true</SkipMachineOOBE>
              <SkipUserOOBE>true</SkipUserOOBE>
              <NetworkLocation>Work</NetworkLocation>
              <ProtectYourPC>3</ProtectYourPC>
              <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
            </OOBE>
            <TimeZone>W. Europe Standard Time</TimeZone>
            <DisableAutoDaylightTimeSet>false</DisableAutoDaylightTimeSet>
          </component>
        </settings>
      </unattend>'
        $oobeSystem = $xmlunattend.unattend.settings | Where-Object { $_.pass -eq 'oobeSystem' }
        $oobeSystem.component.UserAccounts.AdministratorPassword.Value = $localadminpass

        $xmlunattend.Save( 'C:\WdsImages\InstallImage.xml' )
        $result.changed = $true
    }
}

Function CreateOSUnattend {
    $testfile = Test-Path "C:\WdsImages\InstallOS.xml"

    if (-not $testfile) {
        $xmlunattend = [xml]'<unattend xmlns="urn:schemas-microsoft-com:unattend">
        <settings pass="windowsPE">
          <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
              <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
          </component>
          <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <Diagnostics>
              <OptIn>false</OptIn>
            </Diagnostics>
            <DiskConfiguration>
              <WillShowUI>OnError</WillShowUI>
              <Disk wcm:action="add">
                <DiskID>0</DiskID>
                <WillWipeDisk>true</WillWipeDisk>
                <CreatePartitions>
                  <CreatePartition wcm:action="add">
                    <Order>1</Order>
                    <Size>100</Size>
                    <Type>EFI</Type>
                  </CreatePartition>
                  <CreatePartition wcm:action="add">
                    <Order>2</Order>
                    <Type>MSR</Type>
                    <Size>128</Size>
                  </CreatePartition>
                  <CreatePartition wcm:action="add">
                    <Order>3</Order>
                    <Type>Primary</Type>
                    <Extend>true</Extend>
                  </CreatePartition>
                </CreatePartitions>
                <ModifyPartitions>
                  <ModifyPartition wcm:action="add">
                    <Order>1</Order>
                    <PartitionID>1</PartitionID>
                    <Label>System</Label>
                    <Format>FAT32</Format>
                  </ModifyPartition>
                  <ModifyPartition wcm:action="add">
                    <Order>2</Order>
                    <PartitionID>3</PartitionID>
                    <Label>Local Disk</Label>
                    <Letter>C</Letter>
                    <Format>NTFS</Format>
                  </ModifyPartition>
                </ModifyPartitions>
              </Disk>
            </DiskConfiguration>
            <ImageInstall>
              <OSImage>
                <InstallTo>
                  <DiskID>0</DiskID>
                  <PartitionID>3</PartitionID>
                </InstallTo>
                <WillShowUI>OnError</WillShowUI>
                <InstallToAvailablePartition>false</InstallToAvailablePartition>
              </OSImage>
            </ImageInstall>
            <UserData>
              <AcceptEula>true</AcceptEula>
              <FullName>
              </FullName>
              <Organization>
              </Organization>
              <ProductKey>
                <WillShowUI>Never</WillShowUI>
              </ProductKey>
            </UserData>
            <EnableFirewall>true</EnableFirewall>
            <EnableNetwork>true</EnableNetwork>
            <WindowsDeploymentServices>
              <Login>
                <Credentials>
                  <Username>readonly</Username>
                  <Password></Password>
                  <Domain>wds01</Domain>
                </Credentials>
              </Login>
              <ImageSelection>
                <InstallImage>
                  <ImageName>Windows Server 2022 Ansible</ImageName>
                  <ImageGroup>Windows Server 2022</ImageGroup>
                </InstallImage>
                <InstallTo>
                  <DiskID>0</DiskID>
                  <PartitionID>3</PartitionID>
                </InstallTo>
              </ImageSelection>
            </WindowsDeploymentServices>
          </component>
        </settings>
      </unattend>'
        $winpe = $xmlunattend.unattend.settings | Where-Object { $_.pass -eq 'windowsPE' }
        $winpe.component.Where( { $_.name -eq 'Microsoft-Windows-International-Core-WinPE' } )
        $winpe.component.Where( { $_.name -eq 'Microsoft-Windows-Setup' } ).WindowsDeploymentServices.Login.Credentials.Username = $wdsusername
        $winpe.component.Where( { $_.name -eq 'Microsoft-Windows-Setup' } ).WindowsDeploymentServices.Login.Credentials.Password = $wdsuserpass
        $winpe.component.Where( { $_.name -eq 'Microsoft-Windows-Setup' } ).WindowsDeploymentServices.Login.Credentials.Domain = $env:COMPUTERNAME


        $xmlunattend.Save( 'C:\WdsImages\InstallOS.xml' )
        $result.changed = $true
    }
}


Try {
    switch ($state) {
        "present" { InstallWDSImage }
        "absent" { RemoveWDSImage }
        "init" { InitWDSServer }
        "answer" { AnswerWDSServer }
    }

    Exit-Json $result;
}
Catch {
    Fail-Json $result $_.Exception.Message
}