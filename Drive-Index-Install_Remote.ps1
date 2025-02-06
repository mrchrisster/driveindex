# Timeframe Drive Index Install Script
# Copyright Christoph Helms

$title    = 'TIMEFRAME FILMS'
$question = 'Would you like to install or uninstall Drive Index?'

$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Install'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Uninstall'))

$decision = $Host.UI.PromptForChoice($title, $question, $choices, -1)
if ($decision -eq 0) {

    #Check for file on Desktop
    $MainFolder = 'c:\'
    $Folder = Join-Path -Path $MainFolder -ChildPath Drive-Index

    #Check for Drive-Index folder
    if (Test-Path -Path $Folder) {
    } else {
    New-Item -Path $MainFolder -Name "Drive-Index" -ItemType "directory"
    }
    #Check for subfolder drive-index-files
    if (Test-Path -Path $Folder\drive-index-files) {
    } else {
    New-Item -Path $Folder -Name "drive-index-files" -ItemType "directory"
    }

    # Create script

$driveindexhome = @'
# Timeframe Drive Index Script v1
# Copyright Christoph Helms
# Make sure you allow Administrator unrestricted Powershell access by setting set-executionpolicy unrestricted
# Requires -version 2.1

# Setup Work Environment

$MainFolder = 'c:\'
$Folder = Join-Path -Path $MainFolder -ChildPath Drive-Index

#Check for Drive-Index folder
if (Test-Path -Path $Folder) {
} else {
    New-Item -Path $MainFolder -Name "Drive-Index" -ItemType "directory"
}
#Check for subfolder drive-index-files
if (Test-Path -Path $Folder\drive-index-files) {
} else {
    New-Item -Path $Folder -Name "drive-index-files" -ItemType "directory"
}

$indexfiles = "$Folder\drive-index-files\"
$masterlistpath = "$Folder\"
$masterlistname = "TF Drive Index.txt"


$drives =[System.IO.DriveInfo]::getdrives()
$driveselect = $drives | select-object VolumeLabel, Name | ?{$_.VolumeLabel -like 'WORK*' -or $_.VolumeLabel -like 'LOC*' -or $_.VolumeLabel -like 'ARCH*'}


Foreach ($drive in $driveselect) {

$path = Join-Path -Path $indexfiles -ChildPath $drive.volumelabel

#Good practice for SMB shares


Remove-Item $path -Recurse -ErrorAction Ignore

#Drive Content and GB per folder

$drivecontent = gci -literalpath $drive.name | 
  %{$f=$_; gci -r $_.FullName | 
    measure-object -property length -sum |
    select  @{Name="Name"; Expression={$f}}, 
            @{Name="Sum (GB)"; Expression={[math]::Round($_.sum / 1GB).ToString()+" GB" }}, Sum } | 
    format-table -property "Sum (GB)", Name
$drivecontent | out-file $path

(Get-Content $path | Select-Object -Skip 3) | Set-Content $path

#Free Space

$driveletter = $drive.name.Trim('\').trim(':')
$free_size = Get-psdrive $driveletter
$drivesize = [math]::Round($free_size.free / 1GB).ToString()+" GB" 
$appendtext = 'Free Space: ' + $drivesize
$appendtext | add-content $path



#Last Access

$date = Get-Date -format "yyyy-MMM-dd"
$cdate = Write-Output ', ' $date
$cuser = [Environment]::UserName
$appendtext = 'Last Access: ' + $cuser + $cdate
$appendtext | add-content $path
}

# Upload to ftp

$files = @(Get-ChildItem $indexfiles)
foreach ($file in $files) {

$request = [Net.WebRequest]::Create("ftp://ftpserver:2021/drive-index-files/$file")
$request.Credentials = New-Object System.Net.NetworkCredential("driveindex", "thisisonlyfordriveindex")
$request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile 

$fileStream = [System.IO.File]::OpenRead("$indexfiles\$file")
$ftpStream = $request.GetRequestStream()

$fileStream.CopyTo($ftpStream)

$ftpStream.Dispose()
$fileStream.Dispose()
}

'@

$driveindexhome > $Folder\drive-index-home.ps1


# Add to Task Scheduler, delete old task
$taskName = "Drive Index"
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
$taskExists = Get-ScheduledTask | Where-Object {$_.TaskName -like $taskName }


   $taskAction = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument '-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass c:\Drive-Index\drive-index-home.ps1'
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 60) -RepetitionDuration (New-TimeSpan -Days (365 * 20))
    Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $taskAction  -Description "Runs the Drive Index every hour"




Write-Output = "`n `n `n `n Success. (Ignore the red error messages)`n `n`nPlease click on the Windows icon at the bottom left now and search for 'Task Scheduler'. `nOpen it and confirm that you see an item called 'Drive Index' in Task Scheduler Library. `nDouble click it and click on 'Run wether User is logged in or not' and confirm with your Password. The password is your Microsoft account password if you didn't set up a local account."
Read-Host -Prompt "`n Once done, just press Enter to exit this window"





} else {
   $taskName = "Drive Index"
   Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}
