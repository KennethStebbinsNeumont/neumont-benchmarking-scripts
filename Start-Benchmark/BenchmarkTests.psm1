function Test-BIOSVersion
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [System.Management.Automation.PSCustomObject]$TestObj,
        [Parameter(Position=2)]
            [System.Management.Automation.PSCustomObject]$SysInfo=(Get-SystemInfo),
        [Parameter(Position=3)]
            [System.Management.Automation.PSCustomObject]$PersistentData=(Get-PersistentData)
    )

    $result = $null

    $valueObj = $TestObj.Results[0].Value

    $PersistentData = Get-PersistentData

    if($SysInfo.Manufacturer -eq "LENOVO") {
        $biosVersion = Convert-WildcardToRegex $SysInfo.BiosVersion
    } else {
        $biosVersion = $SysInfo.BiosVersion
    }

    foreach($entry in $PersistentData.CurrentBIOSVersions) {
        if(Test-SysInfoMatch -SysInfo $SysInfo -Manufacturer $entry.Manufacturer -Model $entry.Model) {
            # If we've found this machine's model in the PersistentData current bios version database

            $currentVersion = $entry.BIOSVersion
            if($biosVersion -lt $currentVersion) {
                # If this machine's BIOS is out of date
                Write-Host -ForegroundColor Yellow "This machine's BIOS version ($biosVersion) is lower than the current BIOS version ($currentVersion)."
                Write-Host -ForegroundColor Yellow "Update BIOS then reboot."

                Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $false
                $result = @{ "Successful" = $false; "Message" = "BIOS out of date" }
            } elseif($biosVersion -gt $currentVersion) {
                # If the database entry is out of date
                Write-Host -ForegroundColor Cyan "This machine's BIOS version ($biosVersion) is higher than the database's current BIOS version ($currentVersion)."
                $entry.BIOSVersion = $biosVersion
                Write-Host -ForegroundColor Cyan "Database has been updated."

                Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
                $result = @{ "Successful" = $true; "Message" = "BIOS up to date" }
            } else {
                # If both BOS versions are the same
                Write-Host -ForegroundColor Green "BIOS is up to date ($biosVersion)"

                Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
                $result = @{ "Successful" = $true; "Message" = "BIOS up to date" }
            }

            break
        }
    }

    # If no matching models were found in the database, create the entry
    Write-Host -ForegroundColor Yellow "No matching BIOS information found in database."
    $PersistentData.CurrentBIOSVersions += New-PSObject @{ "Manufacturer" = $sysInfo.Manufacturer; 
                                                                "Model" = $sysInfo.Model; "BIOSVersion" = $sysInfo.BIOSVersion }
    Save-PersistentData $PersistentData
    Write-Host -ForegroundColor Cyan "Database has been updated."

    $result = @{ "Successful" = $true; "Message" = "No associated BIOS info existed in database." }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}

function Test-IPDT
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [System.Management.Automation.PSCustomObject]$TestObj
    )

    $result = $null
    
    $valueObj = $TestObj.Results[0].Value

    Write-Host -ForegroundColor White "Wait until the test completes, then indicate whether the test passed."

    $process = Start-Process -FilePath "C:\Program Files\IPDT\IPDT.exe" -PassThru

    $response = Get-KeypressResponse -Prompt "Did the suite of tests pass? (Y/N): " -Options "y","Y","n","N"

    if($response -eq 'y' -or $response -eq 'Y') {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
        $result = @{ "Successful" = $true; }
    } else {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $false
        $result = @{ "Successful" = $false;}
    }

    if(!$process.HasExited) {
        Write-Host -ForegroundColor Cyan "Please close IPDT to continue..."
        $process.WaitForExit()
    }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}

function Test-Cinebench
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [System.Management.Automation.PSCustomObject]$TestObj
    )

    $scoreValueObj = $TestObj.Results[0].Value

    Write-Host -ForegroundColor White "Click `"Run`", wait until the test completes, then enter the given score."
    Write-Host -ForegroundColor White "The expected point range for this machine is $($scoreValueObj.Min)-$($scoreValueObj.Max)."

    $process = Start-Process -FilePath "C:\Program Files\Cinebench\Cinebench.exe" -PassThru

    $scoreResponse = Get-DoubleResponse -Prompt "What score did Cinebench give?: "

    $testPassed = $true
    $comments = @()

    if($scoreResponse -gt $scoreValueObj.Min) {
        if($scoreResponse -gt $scoreValueObj.Max) {
            $comment = "Score was greater than the expected maximum."
            Write-Host -ForegroundColor Cyan $comment
            Add-Member -InputObject $scoreValueObj -NotePropertyName Comment -NotePropertyValue $comment
            $comments += $comment
        }
    } else {
        $comment = "Score was greater than the expected maximum."
        Write-Host -ForegroundColor Red $comment
        $comments += $comment
        $testPassed = $false
    }
    Add-Member -InputObject $scoreValueObj -NotePropertyName Value -NotePropertyValue $scoreResponse

    if(!$process.HasExited) {
        Write-Host -ForegroundColor Cyan "Please close Cinebench to continue..."
        $process.WaitForExit()
    }

    $commentString = ""
    foreach($comment in $comments) {
        if($commentString -ne "") {
            $commentString += " $comment"
        } else {
            $commentString += "$comment"
        }
    }

    $result = @{ "Successful" = $testPassed; "Message" = $commentString }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}

function Test-FurMarkdGPU
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [System.Management.Automation.PSCustomObject]$TestObj
    )

    $scoreValueObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Score"
    $tempValueObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Average GPU Core Temperature"

    Write-Host -ForegroundColor White "Click the `"1080p`" preset, wait until the test completes, then enter the given score and average GPU core temperature."
    Write-Host -ForegroundColor White "The expected point range for this machine is $($scoreValueObj.Min)-$($scoreValueObj.Max)."
    Write-Host -ForegroundColor White "The expected GPU core temperature range for this machine is $($tempValueObj.Min)-$($tempValueObj.Max)."

    $process = Start-Process -FilePath "C:\Program Files\FurMark\FurMark.exe" -PassThru

    $scoreResponse = Get-DoubleResponse -Prompt "What score did FurMark give?: "
    $tempResponse = Get-DoubleResponse -Prompt "What average GPU core temperature did FurMark report?: "

    $testPassed = $true
    $comments = @()

    if($scoreResponse -gt $scoreValueObj.Min) {
        if($scoreResponse -gt $scoreValueObj.Max) {
            $comment = "Score was greater than the expected maximum."
            Write-Host -ForegroundColor Cyan $comment
            Add-Member -InputObject $scoreValueObj -NotePropertyName Comment -NotePropertyValue $comment
            $comments += $comment
        }
    } else {
        $comment = "Score was lower than the expected minimum."
        Write-Host -ForegroundColor Red $comment
        $comments += $comment
        $testPassed = $false
    }
    Add-Member -InputObject $scoreValueObj -NotePropertyName Value -NotePropertyValue $scoreResponse
    
    if($tempResponse -lt $tempValueObj.Max) {
        if($tempResponse -lt $tempValueObj.Min) {
            $comment = "Average GPU core temperature was lower than the expected minimum."
            Write-Host -ForegroundColor Cyan $comment
            Add-Member -InputObject $tempValueObj -NotePropertyName Comment -NotePropertyValue $comment
            $comments += $comment
        }
    } else {
        $comment = "Average GPU core temperature was higher than the expected maximum."
        Write-Host -ForegroundColor Red $comment
        $comments += $comment
        $testPassed = $false
    }
    Add-Member -InputObject $tempValueObj -NotePropertyName Value -NotePropertyValue $tempResponse

    if(!$process.HasExited) {
        Write-Host -ForegroundColor Cyan "Please close FurMark to continue..."
        $process.WaitForExit()
    }

    $commentString = ""
    foreach($comment in $comments) {
        if($commentString -ne "") {
            $commentString += " $comment"
        } else {
            $commentString += "$comment"
        }
    }

    $result = @{ "Successful" = $testPassed; "Message" = $commentString }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}

function Test-FurMarkiGPU
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [System.Management.Automation.PSCustomObject]$TestObj
    )

    $scoreValueObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Score"
    $tempValueObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Average GPU Core Temperature"

    Write-Host -ForegroundColor White "Click the `"1080p`" preset, wait until the test completes, then enter the given score and average GPU core temperature."
    Write-Host -ForegroundColor White "The expected point range for this machine is $($scoreValueObj.Min)-$($scoreValueObj.Max)."
    Write-Host -ForegroundColor White "The expected GPU core temperature range for this machine is $($tempValueObj.Min)-$($tempValueObj.Max)."

    $process = Start-Process -FilePath "C:\Program Files\FurMark (iGPU)\FurMark.exe" -PassThru

    $scoreResponse = Get-DoubleResponse -Prompt "What score did FurMark give?: "
    $tempResponse = Get-DoubleResponse -Prompt "What average Intel GPU core temperature did FurMark report?: "

    $testPassed = $true
    $comments = @()

    if($scoreResponse -gt $scoreValueObj.Min) {
        if($scoreResponse -gt $scoreValueObj.Max) {
            $comment = "Score was greater than the expected maximum."
            Write-Host -ForegroundColor Cyan $comment
            Add-Member -InputObject $scoreValueObj -NotePropertyName Comment -NotePropertyValue $comment
            $comments += $comment
        }
    } else {
        $comment = "Score was lower than the expected minimum."
        Write-Host -ForegroundColor Red $comment
        $comments += $comment
        $testPassed = $false
    }
    Add-Member -InputObject $scoreValueObj -NotePropertyName Value -NotePropertyValue $scoreResponse
    
    if($tempResponse -lt $tempValueObj.Max) {
        if($tempResponse -lt $tempValueObj.Min) {
            $comment = "Average GPU core temperature was lower than the expected minimum."
            Write-Host -ForegroundColor Cyan $comment
            Add-Member -InputObject $tempValueObj -NotePropertyName Comment -NotePropertyValue $comment
            $comments += $comment
        }
    } else {
        $comment = "Average GPU core temperature was higher than the expected maximum."
        Write-Host -ForegroundColor Red $comment
        $comments += $comment
        $testPassed = $false
    }
    Add-Member -InputObject $tempValueObj -NotePropertyName Value -NotePropertyValue $tempResponse

    if(!$process.HasExited) {
        Write-Host -ForegroundColor Cyan "Please close FurMark to continue..."
        $process.WaitForExit()
    }

    $commentString = ""
    foreach($comment in $comments) {
        if($commentString -ne "") {
            $commentString += " $comment"
        } else {
            $commentString += "$comment"
        }
    }

    $result = @{ "Successful" = $testPassed; "Message" = $commentString }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}

function Test-Heaven
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [System.Management.Automation.PSCustomObject]$TestObj
    )

    $scoreValueObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Score"
    $gpuTempValueObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Average GPU Core Temperature"
    $cpuTempValueObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Average CPU Max Core Temperature"

    Write-Host -ForegroundColor White "Open HWiNFO64 in sensors-only mode. Click `"Run`" in Heaven. Reset the counters in HWiNFO (click the clock icon)."
    Write-Host -ForegroundColor White "Click `"Benchmark`" in Heaven (or press F9), wait until the test completes, then enter the given score, average GPU core temperature, and average CPU max core temperature."
    Write-Host -ForegroundColor White "The expected point range for this machine is $($scoreValueObj.Min)-$($scoreValueObj.Max)."
    Write-Host -ForegroundColor White "The expected average GPU core temperature range for this machine is $($gpuTempValueObj.Min)-$($gpuTempValueObj.Max)."
    Write-Host -ForegroundColor White "The expected average CPU max core temperature range for this machine is $($cpuTempValueObj.Min)-$($cpuTempValueObj.Max)."

    if(Get-Process | Where-Object {$_.ProcessName -eq "HWiNFO64"} -eq $null) {
        # Start HWiNFO64 if it isn't already running
        Start-Process -FilePath "C:\Program Files\HWiNFO\HWiNFO64.exe" | Out-Null
    }

    $process = Start-Process -FilePath "C:\Program Files\Heaven\Heaven.exe" -PassThru

    $scoreResponse = Get-DoubleResponse -Prompt "What score did Heaven give?: "
    $gpuTempResponse = Get-DoubleResponse -Prompt "What average GPU core temperature did HWiNFO64 report?: "
    $cpuTempResponse = Get-DoubleResponse -Prompt "What average CPU max core temperaturee did HWiNFO64 report?: "

    $testPassed = $true
    $comments = @()
    
    if($scoreResponse -gt $scoreValueObj.Min) {
        if($scoreResponse -gt $scoreValueObj.Max) {
            $comment = "Score was greater than the expected maximum."
            Write-Host -ForegroundColor Cyan $comment
            Add-Member -InputObject $scoreValueObj -NotePropertyName Comment -NotePropertyValue $comment
            $comments += $comment
        }
    } else {
        $comment = "Score was lower than the expected minimum."
        Write-Host -ForegroundColor Red $comment
        $comments += $comment
        $testPassed = $false
    }
    Add-Member -InputObject $scoreValueObj -NotePropertyName Value -NotePropertyValue $scoreResponse
    
    if($gpuTempResponse -lt $gpuTempValueObj.Max) {
        if($gpuTempResponse -lt $gpuTempValueObj.Min) {
            $comment = "Average GPU core temperature was lower than the expected minimum."
            Write-Host -ForegroundColor Cyan $comment
            Add-Member -InputObject $gpuTempValueObj -NotePropertyName Comment -NotePropertyValue $comment
            $comments += $comment
        }
    } else {
        $comment = "Average GPU core temperature was higher than the expected maximum."
        Write-Host -ForegroundColor Red $comment
        $comments += $comment
        $testPassed = $false
    }
    Add-Member -InputObject $gpuTempValueObj -NotePropertyName Value -NotePropertyValue $gpuTempResponse
    
    if($cpuTempResponse -lt $cpuTempValueObj.Max) {
        if($cpuTempResponse -lt $cpuTempValueObj.Min) {
            $comment = "Average CPU max core temperature was lower than the expected minimum."
            Write-Host -ForegroundColor Cyan $comment
            Add-Member -InputObject $cpuTempValueObj -NotePropertyName Comment -NotePropertyValue $comment
            $comments += $comment
        }
    } else {
        $comment = "Average CPU max core temperature was higher than the expected maximum."
        Write-Host -ForegroundColor Red $comment
        $comments += $comment
        $testPassed = $false
    }
    Add-Member -InputObject $gpuTempValueObj -NotePropertyName Value -NotePropertyValue $gpuTempResponse

    if(!$process.HasExited) {
        Write-Host -ForegroundColor Cyan "Please close Heaven to continue (Do NOT close HWiNFO64)..."
        $process.WaitForExit()
    }

    $commentString = ""
    foreach($comment in $comments) {
        if($commentString -ne "") {
            $commentString += " $comment"
        } else {
            $commentString += "$comment"
        }
    }

    $result = @{ "Successful" = $testPassed; "Message" = $commentString }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}
function Test-Prime95
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [System.Management.Automation.PSCustomObject]$TestObj
    )

    $tempValueObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Average CPU Max Core Temperature"

    Write-Host -ForegroundColor White "Open HWiNFO64 in sensors-only mode. Choose the `"Small FFTs`" preset in Prime95 and click `"OK`". Reset the counters in HWiNFO (click the clock icon)."
    Write-Host -ForegroundColor White "Wait for at least 15 minutes, then enter the average CPU max core temperature."
    Write-Host -ForegroundColor White "The expected CPU max core temperature range for this machine is $($tempValueObj.Min)-$($tempValueObj.Max)."

    $hwinfoProcess = Get-Process | Where-Object {$_.ProcessName -eq "HWiNFO64"}
    if($null -eq $hwinfoProcess) {
        # Start HWiNFO64 if it isn't already running
        $hwinfoProcess = Start-Process -FilePath "C:\Program Files\HWiNFO\HWiNFO64.exe" -PassThru
    }
    $prime95Process = Start-Process -FilePath "C:\Program Files\Prime95\Prime95.exe" -PassThru

    $tempResponse = Get-DoubleResponse -Prompt "What average CPU max core temperature did HWiNFO64 report?: "
    
    $testPassed = $true
    $comments = @()

    if($tempResponse -lt $tempValueObj.Max) {
        if($tempResponse -lt $tempValueObj.Min) {
            $comment = "Average CPU max core temperature was lower than the expected minimum."
            Write-Host -ForegroundColor Cyan $comment
            Add-Member -InputObject $tempResponse -NotePropertyName "Comment" -NotePropertyValue $comment
            $comments += $comment
        }
    } else {
        $comment = "Average GPU core temperature was higher than the expected maximum."
        Write-Host -ForegroundColor Red $comment
        Add-Member -InputObject $tempResponse -NotePropertyName "Comment" -NotePropertyValue $comment
        $comments += $comment
        $testPassed = $false
    }
    Add-Member -InputObject $tempValueObj -NotePropertyName Value -NotePropertyValue $tempResponse

    if(!$prime95Process.HasExited) {
        Write-Host -ForegroundColor Cyan "Please close Prime95 to continue..."
        $prime95Process.WaitForExit()
    }

    if(!$hwinfoProcess.HasExited) {
        Write-Host -ForegroundColor Cyan "Please close HWiNFO64 to continue (you may need to right-click on the HWiNFO icon in the system tray and click `"Exit`")..."
        $hwinfoProcess.WaitForExit()
    }

    $commentString = ""
    foreach($comment in $comments) {
        if($commentString -ne "") {
            $commentString += " $comment"
        } else {
            $commentString += "$comment"
        }
    }

    $result = @{ "Successful" = $testPassed; "Message" = $commentString }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}

function Test-MemTest64
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [System.Management.Automation.PSCustomObject]$TestObj
    )
    
    $valueObj = $TestObj.Results[0].Value

    Write-Host -ForegroundColor White "Wait until the test completes, then indicate whether the test passed."
    Write-Host -ForegroundColor White "This test is notoriously tricky. You may need to reboot a few times or boot into safe mode in order to get it to start."
    Write-Host -ForegroundColor White "If you cannot get the test to run, skip it and run the Windows Memory Diagnostic instead."

    $process = Start-Process -FilePath "C:\Program Files\MemTest64\MemTest64.exe" -PassThru

    $response = Get-KeypressResponse -Prompt "Did the test pass? (Y/N/(S)kip): " -Options 'y','Y','n','N','s','S'
    $commentResponse = Read-Host -Prompt "Do you have any comments? (Leave blank to skip): "

    $testPassed = $false
    $testSkipped = $false

    if($response -eq 'y' -or $response -eq 'Y') {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
        $testPassed = $true
    } elseif($response -eq 'n' -or $response -eq 'N') {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $false
    } else {
        # If skipped
        Add-Member -InputObject $valueObj -NotePropertyName Skipped -NotePropertyValue $true
        $testSkipped = $true
    }
    
    if($commentResponse -ne "") {
        Add-Member -InputObject $valueObj -NotePropertyName Comment -NotePropertyValue $commentResponse
    }

    if(!$process.HasExited) {
        Write-Host -ForegroundColor Cyan "Please close MemTest64 to continue..."
        $process.WaitForExit()
    }

    if($testSkipped) {
        $result = @{ "Successful" = $false; "Message" = "Test skipped" }
    } else {
        $result = @{ "Successful" = $testPassed }
    }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}

function Test-WinMemDiag
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [System.Management.Automation.PSCustomObject]$TestObj
    )
    
    $valueObj = $TestObj.Results[0].Value

    $response = Get-KeypressResponse -Prompt "Did MemTest64 start properly? (Y/N): " -Options 'y','Y','n','N'
    if($response -eq 'y' -or $response -eq 'Y') {
        # Skip this test if MemTest64 started properly
        Write-Host -ForegroundColor White "Skipping this test..."
        Add-Member -InputObject $valueObj -NotePropertyName Skipped -NotePropertyValue $true
        Add-Member -InputObject $valueObj -NotePropertyName Comment -NotePropertyValue "Test skipped because MemTest64 was already run."
        $result = @{ "Successful" = $false; "Message" = "Test skipped because MemTest64 was already run." }

        return @{ "Result"=$result; "TestObj"=$TestObj; }
    }

    $response = Get-KeypressResponse -Prompt "Have you already started this test? (Y/N/(S)kip): " -Options 'y','Y','n','N','s','S'

    $testSkipped = $false
    $testPassed = $false

    if($response -eq 'n' -or $response -eq 'N') {
        # If the test hasn't been started yet

        Write-Host -ForegroundColor White "Wait until the test completes, then indicate whether the test passed."
        Write-Host -ForegroundColor White "This test indicates whether it passed via a notification in the notification center. It may take a few minutes to appear after rebooting."

        Start-Process -FilePath "C:\Windows\System32\WindowsMemoryDiagnostic.exe"
    } elseif($response -eq 'y' -or $response -eq 'Y') {
        # If we're returning after rebooting
        $response = Get-KeypressResponse -Prompt "Did the test pass? (Y/N/(S)kip): " -Options 'y','Y','n','N','s','S'
        $commentResponse = Read-Host -Prompt "Do you have any comments? (Leave blank to skip): "

        if($response -eq 'y' -or $response -eq 'Y') {
            Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
            $testPassed = $true
        } elseif($response -eq 'n' -or $response -eq 'N') {
            Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $false
        } else {
            # If skipped
            Add-Member -InputObject $valueObj -NotePropertyName Skipped -NotePropertyValue $true
            $testSkipped = $true
        }
    
        if($commentResponse -ne "") {
            Add-Member -InputObject $valueObj -NotePropertyName Comment -NotePropertyValue $commentResponse
        }
    }

    if($testSkipped) {
        $result = @{ "Successful" = $false; "Message" = "Test skipped" }
    } else {
        $result = @{ "Successful" = $testPassed }
    }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}

# Exports
Export-ModuleMember -Function "Test-BIOSVersion"
Export-ModuleMember -Function "Test-IPDT"
Export-ModuleMember -Function "Test-Cinebench"
Export-ModuleMember -Function "Test-FurMarkdGPU"
Export-ModuleMember -Function "Test-FurMarkiGPU"
Export-ModuleMember -Function "Test-Heaven"
Export-ModuleMember -Function "Test-Prime95"
Export-ModuleMember -Function "Test-MemTest64"
Export-ModuleMember -Function "Test-WinMemDiag"