# F:\Drive-Index\Monitor-FolderAndCompile.ps1

$folderToWatch = "F:\Drive-Index\drive-index-files"
$compileScript = "F:\Drive-Index\current\CompileMasterList.ps1"
$lastRunFile   = "F:\Drive-Index\current\LastRun.txt"

$cooldownInterval = 600000000  # 60 seconds in file time units (file time units: 1 sec = 10,000,000)
$debounceTime     = 30         # seconds to wait for file activity to settle

Write-Host "Monitoring '$folderToWatch' for changes..."

# Function to capture the current folder state (concatenating each file's name and last write time)
function Get-FolderState {
    param ($folderPath)
    # In PS 2.0, filter files using PSIsContainer
    $files = Get-ChildItem -Path $folderPath | Where-Object { -not $_.PSIsContainer } | Sort-Object Name
    return ($files | ForEach-Object { $_.Name + $_.LastWriteTime.Ticks }) -join ","
}

# Read last run time from disk (if available) or initialize to zero.
if (Test-Path $lastRunFile) {
    $lastRunTime = [int64](Get-Content -Path $lastRunFile)
} else {
    $lastRunTime = 0
}

# Initialize the previous folder state in memory (we won’t write this to disk)
$previousState = Get-FolderState $folderToWatch

while ($true) {
    Start-Sleep -Seconds 5  # Check for changes every 5 seconds

    $currentState = Get-FolderState $folderToWatch
    $currentTime = [int64](Get-Date).ToFileTimeUtc()

    if ($currentState -ne $previousState) {
        Write-Host "Change detected at $(Get-Date). Waiting for stability..."
        
        # Wait a debounce period to allow changes to settle
        Start-Sleep -Seconds $debounceTime
        
        # Re-capture the folder state
        $newState = Get-FolderState $folderToWatch
        
        if ($newState -eq $currentState) {
            # Check if the cooldown period has elapsed since the last run
            if (($currentTime - $lastRunTime) -ge $cooldownInterval) {
                Write-Host "Stable change detected. Updating master list..."
                $lastRunTime = $currentTime
                # Save the new last run time to disk
                $lastRunTime | Out-File -FilePath $lastRunFile -Force
                # Execute the master list compilation script using a new PowerShell process
                powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$compileScript"
            }
            else {
                Write-Host "Skipping update (cooldown period active)."
            }
            # Update the in-memory previous state so that further loops don't trigger unnecessarily.
            $previousState = $currentState
        }
        else {
            Write-Host "New changes detected during debounce. Restarting wait..."
            # Optionally update the in-memory previous state to the latest snapshot
            $previousState = $newState
        }
    }
}
