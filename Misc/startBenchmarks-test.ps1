Param(
    [String]$DBDirectoryPath,
    [String]$TestDefinitionsPath,
    [String]$StartBenchmarkModulePath
)

Import-Module "$StartBenchmarkModulePath"

Start-Benchmark -DBDirectoryPath "$DBDirectoryPath" -TestDefinitionsPath "$TestDefinitionsPath"

Remove-Module Start-Benchmark
Remove-Module Benchmark* -ErrorAction SilentlyContinue