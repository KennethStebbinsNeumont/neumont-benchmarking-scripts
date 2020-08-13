Param(
    [String]$DBDirectoryPath,
    [String]$TestDefinitionsPath,
    [String]$StartBenchmarkModulePath
)

Remove-Module Start-Benchmark -ErrorAction SilentlyContinue
Remove-Module Benchmark* -ErrorAction SilentlyContinue

Import-Module "$StartBenchmarkModulePath" -ErrorAction Stop

Start-Benchmark -DBDirectoryPath "$DBDirectoryPath" -TestDefinitionsPath "$TestDefinitionsPath"