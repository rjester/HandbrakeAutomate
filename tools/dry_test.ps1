. 'c:\SourceCode\AutomateHandbrake\src\Config.ps1'
. 'c:\SourceCode\AutomateHandbrake\src\Invoke-MakeMKV.ps1'

$drives = Invoke-MakeMKV-FindDrives
if ($drives) {
    Write-Host 'Drives with disc found:'
    $drives | Format-Table -AutoSize
} else {
    Write-Host 'No drives with disc detected'
}

if ($drives) {
    $titles = Invoke-MakeMKV-ListTitles -DriveIndex $drives[0].Index
    if ($titles) {
        Write-Host 'Titles:'
        $titles | Format-Table Index,Name,Duration,Size,Chapters -AutoSize
    } else {
        Write-Host 'No titles returned or unable to read disc'
    }
}
