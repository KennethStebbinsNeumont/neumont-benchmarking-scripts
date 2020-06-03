function Start-Benchmark
{
    [CmdletBinding()]
    Param(
        [String]$DBDirectoryPath,
        [String]$ResultDataFilePath,
        [String]$TestDefinitionsPath,
        [Switch]$RestartTest
    )

    $systemInfo = Get-SystemInfo
    $dateString = Get-Date -Format "yyyyMMdd"
    $timeString = Get-Date -Format "HHmmss"

    if($null -eq $DBDirectoryPath) {
        $DBDirectoryPath = (Get-Location).Path
    }

    if($null -eq $TestDefinitionsPath) {
        $TestDefinitionsPath = "$DBDirectoryPath\tests.json"
    }

    $resultData = $null
    # Determine result file path
    if($ResultDataFilePath) {
        $resultData = Get-ResultData -FilePath $ResultDataFilePath
    } else {
        # If a file path was not given
        $matchedFiles = Get-ChildItem -LiteralPath $DBDirectoryPath | Where-Object {$_.Name -match "\d{8}-\d{6}-$($systemInfo.SerialNumber)-results\.json"}

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
    $lastRunTest = ""
    if($null -ne $resultData -and !$resultData.TestsComplete) {
        foreach($test in $tests) {
            $matchedTest = Where-Object -InputObject $resultData.Tests -FilterScript {$_.Name -eq $test.Name}

            if($null -eq $matchedTest) {
                # If this applicable test wasn't included in the last run
                Write-Host -ForegroundColor Yellow "The last benchmarking run didn't finish."
                Write-Host -ForegroundColor Yellow "Last run test: $lastRunTest"
                $response = Get-KeypressResponse -Prompt "Would you like to (c)ontinue, (r)estart, or (e)xit?: " -Options 'c', 'C', 'e', 'R', 'e', 'E'
                if($response -eq 'c' -or $response -eq 'C') {
                    $startNewRun = $false
                } elseif($response -eq 'e' -or $response -eq 'E') {
                    exit 0
                }
                break
            } else {
                $testsToSkip += $test.Name
                $lastRunTest = $test.Name
            }
        }
    }

    if($startNewRun) {
        $resultData = New-ResultData -FilePath "$DBDirectoryPath\$dateString-$timeString-$($systemInfo.SerialNumber)-results.json" -SysInfo $systemInfo
    }

    Write-Host -ForegroundColor Cyan "The transcript of this run is being saved to $($resultData.FilePath)"

    $i = 0
    foreach($test in $tests) {
        $i += 1

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

        if(!$result.Result.Successful -and !$result.Result.Skipped) {
            $resultData.Passed = $false
            Write-Host -ForegroundColor Red "Test `"$($test.Name)`" failed: $($result.Result.Message)"
            if($test.StopOnFail) {
                Write-Host -ForegroundColor Red "This test must pass before the others can continue. Exiting now..."
                break
            }
        }

        Save-ResultData -ResultData $resultData
    }

    $resultData.TestsComplete = $true
    Save-ResultData -ResultData $resultData

    Write-Host
    Write-Host

    if($resultData.Passed) {
        Write-Host -ForegroundColor Green "All tests passed."
    } else {
        Write-Host -ForegroundColor Red "One or more tests failed:"
        Write-Host
        :testLoop foreach($test in $resultData.Tests) {
            $failedResultStrings = [System.Collections.ArrayList]@()
            :resultLoop foreach($result in $test.Results) {
                $valueObj = $result.Value
                if($result.Type -eq "Boolean" -and $valueObj.Value -ne $valueObj.Expected) {
                    $failedResultStrings.Add("$($result.Name) actual value ($($valueObj.Value)) did not match expected value ($($valueObj.Expected)).")
                    if($valueObj.Comment) {
                        $failedResultStrings.Add($valueObj.Comment) | Out-Null
                    }
                } elseif($result.Type -eq "Number") {
                    if($result.HigherIsBetter -and $valueObj.Value -lt $valueObj.Min) {
                        $failedResultStrings.Add("$($result.Name) value ($($valueObj.Value)) was lower than minimum value ($($valueObj.Min)).")
                    } elseif(!$result.HigherIsBetter -and $valueObj.Value -gt $valueObj.Max) {
                        $failedResultStrings.Add("$($result.Name) value ($($valueObj.Value)) was higher than maximum value ($($valueObj.Max)).")
                    }
                }
            }

            if($failedResultStrings.Count -gt 0) {
                # If at least one result has failed
                Write-Host -ForegroundColor Red "$($test.Name) failed."
                foreach($string in $failedResultStrings) {
                    Write-Host -ForegroundColor Red "`t$string"
                }
                Write-Host
            }
        }
        
    }

    Write-Host
    Write-Host -ForegroundColor White "The transcript of this test has been saved to $($resultData.FilePath)"

    $response = Get-KeypressResponse -Prompt "Would you like to open the result file? (Y/N): " -Options 'y', 'Y', 'n', 'N'

    if($response -eq 'y' -or $response -eq 'Y') {
        Start-Process -FilePath "notepad.exe" -ArgumentList "$($resultData.FilePath)"
    }

    Write-Host
}

Export-ModuleMember -Function "Start-Benchmark"