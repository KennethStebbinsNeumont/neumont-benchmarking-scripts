Import-Module "$PSScriptRoot\Start-Benchmark\Start-Benchmark.psd1"

Start-Benchmark -DBDirectoryPath "$PSScriptRoot"

Remove-Module Start-Benchmark