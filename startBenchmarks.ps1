Remove-Module Start-Benchmark -ErrorAction SilentlyContinue
Remove-Module Benchmark* -ErrorAction SilentlyContinue

Import-Module "$PSScriptRoot\Start-Benchmark\Start-Benchmark.psd1"

Start-Benchmark -DBDirectoryPath "$PSScriptRoot" -TestDefinitionsPath "$PSScriptRoot\tests.json"

Remove-Module Start-Benchmark
Remove-Module Benchmark* -ErrorAction SilentlyContinue