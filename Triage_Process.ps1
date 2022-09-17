<#
.DESCRIPTION
This script was created for the purpose of triaging a suspicious process. The script will download the tools needed to 
suspend, extract, and zip up a dump file of a process that needs to be investigated. 

Version:           1
Author:            Mike Dunn
Creation Date:     September 2022
#>

$Target_PID = "PID GOES HERE"
$AccessKey = "ACCESS KEY GOES HERE"
$SecretKey = "SECRET KEY GOES HERE"
$Bucket = "NAME OF BUCKET"
$Folder = "NAME OF FOLDER TO UPLOAD RESULTS"
$Path = "C:\Windows\Temp\Triage"

function Create_Folder{
    New-Item -Path "C:\Windows\Temp" -Name Triage -ItemType Directory
    New-Item -Path $Path -Name DumpFile -ItemType Directory
    cd $Path
}

function Suspend_Process{
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/PSTools.zip" -OutFile $Path\PsTools.zip
    Expand-Archive -Path PsTools.zip -DestinationPath $Path
    .\pssuspend.exe -accepteula
    .\pssuspend.exe $Target_PID
}

function ProcDump{
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Procdump.zip" -OutFile $Path\Procdump.zip
    Expand-Archive -Path Procdump.zip -DestinationPath $Path -Force
    .\procdump.exe -i -accepteula
    .\procdump.exe -ma $Target_PID
}

function Zip_And_Move{
    Compress-Archive -Path .\*.dmp -DestinationPath .\Sample.zip
    Move-Item -Path .\Sample.zip -Destination .\DumpFile
    cd .\DumpFile
}

function Install_AWS{
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force
    Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Force
    Find-Module -Name AWSPowerShell | Save-Module -Path "C:\Program Files\WindowsPowerShell\Modules"
    Import-Module AWSPowerShell
}

function Upload_Sample{
    Set-AWSCredential -AccessKey $AccessKey -SecretKey $SecretKey -StoreAs Triage
    Initialize-AWSDefaultConfiguration -ProfileName Triage -Region us-east-1
    Write-S3Object -BucketName $Bucket -KeyPrefix $Folder -Folder C:\Windows\Temp\Triage\DumpFile
}

function Cleanup{
    Remove-AWSCredentialProfile -ProfileName Triage -Force
    cd $Path
    .\pssuspend.exe -r $Target_PID
    .\procdump.exe -u
    cd C:\Windows\Temp
    Remove-Item -Path C:\Windows\Temp\Triage -Force -Recurse
}

Create_Folder
Suspend_Process
ProcDump
Zip_And_Move
Install_AWS
Upload_Sample
Cleanup