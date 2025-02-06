# F:\Drive-Index\CompileMasterList.ps1
$indexFilesFolder = "F:\Drive-Index\drive-index-files"
$masterListPath   = "F:\Drive-Index\TF Drive Index.txt"
$errorLogPath     = "F:\Drive-Index\CompileError.log"

try {
    if (Test-Path $errorLogPath) { Remove-Item $errorLogPath -Force }
    if (Test-Path $masterListPath) { Remove-Item $masterListPath -Force }

    "Master List generated on $(Get-Date)" | Out-File -FilePath $masterListPath -Encoding UTF8

    Get-ChildItem -Path $indexFilesFolder -File | Sort-Object Name | ForEach-Object {
        $fileName = $_.BaseName
        $header = "----------------< $fileName >----------------`n"
        Add-Content -Path $masterListPath -Value "`n$header"
        Get-Content -Path $_.FullName | Add-Content -Path $masterListPath
        Add-Content -Path $masterListPath -Value "`n"
    }

    Write-Output "Master list compiled to: $masterListPath"
}
catch {
    $errorMessage = "Error during compilation: $_"
    Write-Error $errorMessage
    $errorMessage | Out-File -FilePath $errorLogPath -Append
}
