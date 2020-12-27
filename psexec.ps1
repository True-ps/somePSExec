
#my half-assed psexec deployment attempt

write-host "Please specify the starting IP address of the IP range you would like to deploy:"
$startip = Read-Host
Write-Host "Please specify the end address of the IP range you would like to deploy:`nOptional - Leave this field empty if you want to scan & deploy only on the previous IP:"
$endIP = Read-Host
Write-Host "Please provide a username:`nDomain users must be added as domain\user:"
$user = 'deploy'
Write-Host "Please provide a password:"
$password = 'Abort12'
#set location to the psexec.exe directory
#set-location "c:\program files (x86)\naverisk\agent\packages\snmppackage"
$workingFolder = "C:\WinAgent\Agent\Packages\SnmpPackage"
Set-Location $workingFolder


[int]$first = $startip.Split('.')[3]
[int]$last =  $endIP.Split('.')[3]

$oct = $startip.Split('.')

$currentIP = $oct[0]+"."+$oct[1]+"."+$oct[2]+"."

$pstools = "https://download.sysinternals.com/files/PSTools.zip"

if ((Test-Path $workingFolder\pstools.zip) -eq $false)
{
Import-Module BitsTransfer
Start-BitsTransfer $pstools $workingFolder
Expand-Archive $workingFolder\pstools.zip -Force

Copy-Item .\pstools\PsExec.exe .\ -Force
}


if([string]::IsNullOrEmpty($endIP) -or $endIP -notcontains "*.*")
{
Write-Host "Only one IP address was provided. Starting scan and deploy on $startip. Please wait..."
Start-Process .\PsExec.exe -argumentlist \\192.168.1.38, "-accepteula -u $user -p $password -e -h -f -i -c AgentSetup.exe /overwrite /noconfirm"-NoNewWindow -Wait -RedirectStandardOutput out.txt -RedirectStandardError err.txt
Get-Content out.txt
Get-Content err.txt

}
else{

Write-Output "The following IP range was provided: $startip -> $endIP. These TCP operations take about 30-60 seconds/IP address.`n
For a much faster experience, please download and install Powershell Core on all your target devices, then ask your script developer to adapt this program to Powershell Core, for paralles processing."

#count from 1 to 254
for ($i = $first; $i -le $last; $i++)
{ 
#assign the current $i value as the last octet of the IP range
$ping = Test-NetConnection $currentIP$i -Port 445 | Select-Object TcpTestSucceeded


if ($ping.TcpTestSucceeded)
{
#if the ping succeeds, trigger a psexec connect
Start-Process .\PsExec.exe -argumentlist \\$currentIP$i, "-accepteula -u $user -p $password -e -h -f -i -c AgentSetup.exe /overwrite /noconfirm"-NoNewWindow -Wait -RedirectStandardOutput out.txt -RedirectStandardError err.txt
Get-Content out.txt
Get-Content err.txt

}
elseif (-not $ping.TcpTestSucceeded)
{
write-output "$currentIP$i has port 445 closed.
`nPort 445 is used by PSExec to connect with other devices.
`nPort 445 is the SMB port.
`nPlease perform the following changes on the target device to allow this operation to succeed:
1. Enable File & Printer Sharing(Start->Allow an app through Windows Firewall->Enable File and Printer Sharing);`n
2. run the following command from an administrative command prompt on your target device:
reg add HKLM\SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\POLICIES\SYSTEM /V LocalAccountTokenFilterPolicy /t REG_DWORD /d 1`n
3. Try again.
"
}

}
}
