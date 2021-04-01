#select current date for log file processing.
$date = Get-Date -Format "yyyy-MM-dd"

#define IP matching pattern
$ipmatch = "(\d{1,3}\.){3,}(\d{1,3})"

#setting IP range
$startip = $args[0]
$endIP = $args[1]

#setting user and password
$user = $args[2]
$password = $args[3]

#we need the last octed to be an integer...
[int]$first = $startip.Split('.')[3]
[int]$last = $endIP.Split('.')[3]
#...so we do that...
$oct = $startip.Split('.')
#...because otherwise, we won't be able to count through the range.
$currentIP = $oct[0] + "." + $oct[1] + "." + $oct[2] + "."


#set location to the psexec.exe directory
$workingFolder = "C:\Program Files (x86)\Naverisk\Agent\Packages"
if (Test-Path $workingFolder\SNMPPackage)
{ Set-Location $workingFolder\SNMPPackage }
else {
    Write-Output "We could not find $workingfolder. This means the Probe is not installed, so we will use the root Packages instead."
    Set-Location $workingFolder
}

#pstools download link
$pstools = "https://download.sysinternals.com/files/PSTools.zip"

#downloading and copying .exe tool.
if ((Test-Path $workingFolder\pstools.zip) -eq $false) {
    Import-Module BitsTransfer
    Start-BitsTransfer $pstools $workingFolder
    Expand-Archive $workingFolder\pstools.zip -Force

    Copy-Item .\pstools\PsExec.exe .\ -Force

    #in case the Agent.exe is in the wrong place, we can copy it to the right place.
    if (Test-Path "C:\Program Files (x86)\Naverisk\Agent\Packages\Agent.exe")
    { Copy-Item "C:\Program Files (x86)\Naverisk\Agent\Packages\Agent.exe" "C:\Program Files (x86)\Naverisk\Agent\Packages\SnmpPackage" }

}

#starting psexec processing per ip with details provided above.

function singleIPRun {
    Start-Process .\PsExec.exe -argumentlist \\$startip, "-accepteula -u $user -p $password -e -h -f -i -c AgentSetup.exe /overwrite /noconfirm"-NoNewWindow -Wait -RedirectStandardOutput out.txt -RedirectStandardError err.txt
    Get-Content out.txt
    Get-Content err.txt

}

function rangeIPRun {
    #if the ping succeeds, trigger a psexec connect
    Start-Process .\PsExec.exe -argumentlist \\$currentIP$i, "-accepteula -u $user -p $password -e -h -f -i -c AgentSetup.exe /overwrite /noconfirm"-NoNewWindow -Wait -RedirectStandardOutput out.txt -RedirectStandardError err.txt
    Get-Content out.txt
    Get-Content err.txt
}

if (($null -eq $endIP) -or $endIP -notmatch $ipmatch) {
    Write-Output "Only one IP address provided: $startip. Scanning..."

    if ((Test-NetConnection $startip -Port 135).TcpTestSucceeded -and (Test-NetConnection $startip -Port 445).TcpTestSucceeded) {
        Write-Output "$startip is open on 135 and 445. Starting deployment..."
        singleIPRun
    }
    elseif ((Test-NetConnection $startip -Port 135).TcpTestSucceeded -eq $false -and (Test-NetConnection $startip -Port 445).TcpTestSucceeded -eq $true) {
        Write-Output "$startip is only open on 445. Attempting to deploy."
        singleIPrun
    }
    elseif ((Test-NetConnection $startip -Port 135).TcpTestSucceeded -eq $true -and (Test-NetConnection $startip -Port 445).TcpTestSucceeded -eq $false) {
        Write-Output "$startip is only open on 135. Deployment is not posssible. Only discovery. Exiting"
    }
    else {
        Write-Output "$startip is not open to 135 and 445. Not able to deploy. Exiting."
    }
    

}
else {


    Write-Output "Scanning range $startip -> $endIP.`nThese TCP operations can take anywhere between 10-60 seconds/IP address.`n
Parallel processing is supported in the latest version of PowerShell Core."

    #count from 1 to 254
    for ($i = $first; $i -le $last; $i++) { 
        #assign the current $i value as the last octet of the IP range
        if ((Test-NetConnection $currentIP$i -Port 135).TcpTestSucceeded -and (Test-NetConnection $currentIP$i -Port 445).TcpTestSucceeded) {
            Write-Output "$currentIP$i is open on 135 and 445. Starting deployment..."
            singleIPRun
        }
        elseif ((Test-NetConnection $currentIP$i -Port 135).TcpTestSucceeded -eq $false -and (Test-NetConnection $currentIP$i -Port 445).TcpTestSucceeded -eq $true) {
            Write-Output "$currentIP$i is only open on 445. Attempting to deploy."
            singleIPrun
        }
        elseif ((Test-NetConnection $currentIP$i -Port 135).TcpTestSucceeded -eq $true -and (Test-NetConnection $currentIP$i -Port 445).TcpTestSucceeded -eq $false) {
            Write-Output "$currentIP$i is only open on 135. Deployment is not posssible. Only discovery. Exiting"
        }
        else {
            Write-Output "$currentIP$i is not open to 135 and 445. Not able to deploy. Exiting."
        }
    


    }
}
<# delete this line
$read = Get-Content "C:\ProgramData\Naverisk\Logs\Package_RemoteConsole $date.txt" -Raw
$read -replace $password, "*******" | Set-Content "C:\ProgramData\Naverisk\Logs\Package_RemoteConsole $date.txt"
#>
