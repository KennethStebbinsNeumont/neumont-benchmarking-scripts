Remove-Module Start-Benchmark -ErrorAction SilentlyContinue
Remove-Module Benchmark* -ErrorAction SilentlyContinue

Import-Module "$HOME\Documents\Scripts\Start-Benchmark\Start-Benchmark.psd1"

Start-Benchmark -DBDirectoryPath "$HOME\Documents\Scripts" -TestDefinitionsPath "$HOME\Documents\Scripts\tests.json" -ResultDataDirectoryPath "$HOME\Documents\Scripts\Results"

Write-Host -ForegroundColor White "Press ENTER to exit..."
Read-Host | Out-Null

Remove-Module Start-Benchmark
Remove-Module Benchmark* -ErrorAction SilentlyContinue