$files = Get-ChildItem `
    .\TimeNest, `
    .\TimeNestWidgetExtension, `
    .\Tests `
    -Recurse -Filter *.swift

Write-Host "Checking $($files.Count) Swift files..."

foreach ($file in $files) {
    Write-Host "Checking: $($file.FullName)"

    swiftc -frontend -parse $file.FullName

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "FAILED: $($file.FullName)"
        exit 1
    }
}

Write-Host ""
Write-Host "Swift syntax check PASSED."
Write-Host "Checked $($files.Count) files."
exit 0