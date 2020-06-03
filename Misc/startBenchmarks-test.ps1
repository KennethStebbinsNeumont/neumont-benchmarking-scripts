Param(
    [String]$DBDirecotryPath,
    [String]$TestDefinitionsPath,
    [String]$StartBenchmarkModulePath
)

Import-Module "$StartBenchmarkModulePath"

Start-Benchmark -DBDirectoryPath "$DBDirecotryPath" -TestDefinitionsPath "$TestDefinitionsPath"

Write-Host -ForegroundColor White "Press ENTER to exit..."
Read-Host | Out-Null

Remove-Module Start-Benchmark
Remove-Module Benchmark* -ErrorAction SilentlyContinue