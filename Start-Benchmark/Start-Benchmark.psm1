function Start-Benchmark
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [String]$DBDirectoryPath,
        [String]$ResultDataFilePath,
        [String]$TestDefinitionsPath,
        [Switch]$RestartTest
    )

    $systemInfo = Get-SystemInfo
    $dateString = Get-Date -Format "yyyyMMdd"
    $timeString = Get-Date -Format "HHmmss"

    if($null -eq $TestDefinitionsPath) {
        $TestDefinitionsPath = "$DBDirectoryPath\tests.json"
    }

    $resultData = $null
    # Determine result file path
    if($ResultDataFilePath) {
        $resultData = Get-ResultData -FilePath $ResultDataFilePath
    } else {
        # If a file path was not given
        $dateString = Get-Date -Format "yyyyMMdd"

        $matchedFiles = Get-ChildItem -LiteralPath $DBDirectoryPath | Where-Object {$_.Name -match "$dateString-.*-$($systemInfo.SerialNumber)-results\.json"}

        if($null -ne $matchedFiles) {
            if($matchedFiles -is [System.Array]) {
                # If we found multiple files

                foreach($f in $matchedFiles) {
                    $r = Get-ResultData -FilePath "$($f.FullName)"
                    if($null -eq $resultData) {
                        $resultData = $r
                    } elseif($r.Date -gt $resultData.Date) {
                        $resultData = $r
                    }
                }
            } else {
                # If we found only one file
                $resultData = Get-ResultData -FilePath "$($matchedFiles.FullName)"
            }
            
        }
    }

    $commonInformation = New-PSObject -Property @{
        "SysInfo"=$systemInfo;
        "PersistentData"=(Get-PersistentData -FilePath "$DBDirectoryPath\persistentdata.json");
    }

    $tests = Get-Tests -FilePath $TestDefinitionsPath

    $startNewRun = $true
    $testsToSkip = [System.Collections.ArrayList]@()
    if($null -ne $resultData -and !$resultData.TestsComplete) {
        foreach($test in $tests) {
            $matchedTest = Where-Object -InputObject $resultData.Tests -Property "Name" -EQ -Value $test.Name

            if($null -eq $matchedTest) {
                # If this applicable test wasn't included in the last run
                Write-Host -ForegroundColor Yellow "The last benchmarking run didn't finish."
                $response = Get-KeypressResponse -Prompt "Would you like to (c)ontinue, (r)estart, or (e)xit?: " -Options "c","r","e"
                if($response -eq 'c' -or $response -eq 'C') {
                    $startNewRun = $false
                } elseif($response -eq 'e' -or $response -eq 'E') {
                    exit 0
                }
                break
            } else {
                $testsToSkip += $test.Name
            }
        }
    }

    if($startNewRun) {
        $resultData = New-ResultData -FilePath "$DBDirectoryPath\$dateString-$timeString-$($systemInfo.SerialNumber)-results.json" -SysInfo $systemInfo
    }

    $i = 1
    foreach($test in $tests) {
        if(!$startNewRun -and $testsToSkip -contains $test.Name) {
            # Skip this test if it was already done in a previous run
            continue
        }

        Write-Host -ForegroundColor Magenta "Running test #$i"
        Write-Host -ForegroundColor White $test.Name
        Write-Host -ForegroundColor Gray $test.Description

        $command = Get-Command -Verb "Test" -Noun $test.CommandName -Module "BenchmarkTests"

        $result = &"$command" -TestObj $test -Common $commonInformation

        $resultData.Tests += $test

        if(!$result.Result.Successful) {
            $resultData.Passed = $false
            Write-Host -ForegroundColor Red "Test `"$($test.Name)`" failed: $($result.Result.Message)"
            if($test.StopOnFail) {
                Write-Host -ForegroundColor Red "This test must pass before the others can continue. Exiting now..."
                break
            }
        }

        Save-ResultData -ResultData $resultData

        $i += 1
    }

    $resultData.TestsComplete = $true
    Save-ResultData -ResultData $resultData
}

Export-ModuleMember -Function "Start-Benchmark"