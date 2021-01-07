
$startip = $args[0]
$endIP = $args[1]
if($null -eq $endIP)
{
Write-Output "Only one IP address provided: $startip. Scanning..."
}
else{
Write-Output "Scanning range $startip -> $endIP.`nThese TCP operations can take anywhere between 10-60 seconds/IP address.`n
Parallel processing is supported in the latest version of PowerShell Core."
}
$user = $args[2]
$password = $args[3]
#set location to the psexec.exe directory
$workingFolder = "C:\Program Files (x86)\Naverisk\Agent\Packages"
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


if([string]::IsNullOrEmpty($endIP))
{
Test-NetConnection $startip -Port 445

Start-Process .\PsExec.exe -argumentlist \\$startip, "-accepteula -u $user -p $password -e -h -f -i -c AgentSetup.exe /overwrite /noconfirm"-NoNewWindow -Wait -RedirectStandardOutput out.txt -RedirectStandardError err.txt
Get-Content out.txt
Get-Content err.txt

}
else{

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
$date = Get-Date -Format "yyyy-MM-dd"

$read = Get-Content "C:\ProgramData\Naverisk\Logs\Package_RemoteConsole $date.txt" -Raw
$read -replace $password, "*******" | Set-Content "C:\ProgramData\Naverisk\Logs\Package_RemoteConsole $date.txt"

