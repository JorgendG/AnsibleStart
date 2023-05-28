#Requires -Module Ansible.ModuleUtils.Legacy
#Requires -Module Ansible.ModuleUtils.Backup

Start-Transcript c:\windows\temp\submit.txt
Set-StrictMode -Version 2

$params = Parse-Args $args -supports_check_mode $false

$reqfile = Get-AnsibleParam $params "reqfile" -type "str"
$crtfile = Get-AnsibleParam $params "crtfile" -type "str"
$CACommonName = Get-AnsibleParam $params "CACommonName" -type "str" 
$state = Get-AnsibleParam $params "state" -type "str" -Default "present"

$result = @{
    changed = $false
}

if ($state -eq "absent") {

}
else {
    
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

Exit-Json $result