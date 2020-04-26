function Start-Benchmark
{
    [CmdletBinding()]
    Param(
        [String]$DBDirectoryPath=(Get-Location).Path,
        [String]$ResultDataFilePath,
        [Switch]$RestartTest
    )

    $systemInfo = Get-SystemInfo

    $resultData = $null
    # Determine result file path
    if($ResultDataFilePath) {
        $resultData = Get-ResultData -FilePath $ResultDataFilePath
    } else {
        # If a file path was not given
        $dateString = Get-Date -Format "yyyyMMdd"

        $currentPath = Get-Location.Path

        $matchedFiles = Get-ChildItem -LiteralPath $currentPath | Where-Object {$_.Name -match "$dateString-.*-$($systemInfo.SerialNumber)-results\.json"}

        if($matchedFiles) {
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

    $startNewRun = $true
    if(!$resultData.TestsComplete) {
        :testLoop foreach($test in $resultData.Tests) {
            foreach($result in $test.Results) {
                $valueObject = $result.Value

                if(!$valueObject.Skipped -and !$valueObject.PSObject.Properties.Name -contains "Value") {
                    # If this value hasn't been filled yet

                    Write-Host -ForegroundColor Yellow "The last benchmarking run didn't finish."
                    $response = Get-KeypressResponse -Prompt "Would you like to (c)ontinue, (r)estart, or (e)xit?: " -Options "c","r","e"
                    if($response -eq 'c' -or $response -eq 'C') {
                        $startNewRun = $false
                    } elseif($response -eq 'e' -or $response -eq 'E') {
                        exit 0
                    }
                    break testLoop
                }
            }
        }
    }

    if($startNewRun) {
        $resultData = New-ResultData -FilePath $ResultDataFilePath -SysInfo $systemInfo
    }

    $i = 1
    foreach($test in Get-Tests) {
        Write-Host -ForegroundColor Magenta "Running test #$i"
        Write-Host -ForegroundColor White $test.Name
        Write-Host -ForegroundColor Gray $test.Description

        $command = Get-Command -Verb "Test" -Noun $test.CommandName -Module "BenchmarkTests"

        $result = 

        if(!$result.Successful) {
            Write-Host -ForegroundColor Red "Test `"$($test.Name)`" failed: $($result.Message)"
            if($test.StopOnFail) {
                Write-Host -ForegroundColor Red "This test must pass before the others can continue. Exiting now..."
                break
            }
        }

        $resultData

        $i += 1
    }
}

Export-ModuleMember -Function "Start-Benchmark"