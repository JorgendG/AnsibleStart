#Requires -Module Ansible.ModuleUtils.Legacy
#Requires -Module Ansible.ModuleUtils.Backup

Start-Transcript c:\windows\temp\submit.txt
Set-StrictMode -Version 2

$params = Parse-Args $args -supports_check_mode $false

$reqfile = Get-AnsibleParam $params "reqfile" -type "str"
$crtfile = Get-AnsibleParam $params "crtfile" -type "str"
$careg = Get-AnsibleParam $params "careg" -type "str"
$caregvalue = Get-AnsibleParam $params "caregvalue" -type "str"
$CACommonName = Get-AnsibleParam $params "CACommonName" -type "str" 
$state = Get-AnsibleParam $params "state" -type "str" -Default "present"
$action = Get-AnsibleParam $params "action" -type "str"

$result = @{
    changed = $false
}

function SubmitRequest {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "$($ENV:SystemRoot)\System32\Certreq.exe"
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = "-Config `"rootca\$CACommonName`" -Submit $reqfile"
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $RequestResult = $p.StandardOutput.ReadToEnd()
    $result.changed = $true
    Write-Host $RequestResult

    $MatchesReqs = [Regex]::Match($RequestResult, 'RequestId:\s([0-9]*)')
    If ($MatchesReqs.Groups.Count -lt 2) {
        Throw "$CACommonName $reqfile Error getting Request ID from SubCA certificate submission."
    }
    [int]$RequestId = $MatchesReqs.Groups[1].Value
    #Write-Verbose "Issuing $RequestId in $($Using:Node.CACommonName)"
    [String]$SubmitResult = & "$($ENV:SystemRoot)\System32\CertUtil.exe" -Resubmit $RequestId
    If ($SubmitResult -notlike 'Certificate issued.*') {
        Throw "Unexpected result issuing SubCA request."
    }
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "$($ENV:SystemRoot)\System32\Certreq.exe"
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = "-Config `"rootca\$CACommonName`" -Retrieve $RequestId $crtfile"
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
}

function InstallCrt {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "$($ENV:SystemRoot)\System32\Certutil.exe"
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = "-installCert $crtfile"
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()

    $RequestResult = $p.StandardOutput.ReadToEnd()
    $result.changed = $true
    Write-Host $RequestResult
}

function ConfigCA {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "$($ENV:SystemRoot)\System32\Certutil.exe"
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = "-setreg $crtfile"
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
}

function SetCAReg {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "$($ENV:SystemRoot)\System32\certutil.exe"
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = '-setreg CA\' + "$careg `"$caregvalue`""
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $RequestResult = $p.StandardOutput.ReadToEnd()
}

if ($state -eq "absent") {

}
else {
    if ( $action -eq 'submit' ) {
        SubmitRequest
    }
    if ( $action -eq 'install' ) {
        InstallCrt
    }
    if ( $action -eq 'config' ) {
        ConfigCA
    }
    if ( $action -eq 'reg' ) {
        SetCAReg
    }
    
}

Exit-Json $result