function Test-BIOSVersion
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [Object]$TestObj,
        [Object]$Common,
        [Object]$SysInfo,
        [Object]$PersistentData
    )

    if($null -eq $SysInfo) {
        if($null -eq $Common) {
            $SysInfo = Get-SystemInfo
        } else {
            $SysInfo = $Common.SysInfo
        }
    }

    if($null -eq $PersistentData) {
        if($null -eq $Common) {
            $PersistentData = Get-PersistentData
        } else {
            $PersistentData = $Common.PersistentData
        }
    }

    $result = $null
    
    $resultObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "BIOS Up-to-date"
    $valueObj = $resultObj.Value

    $biosVersion = $SysInfo.BiosVersion

    if(!$PersistentData.CurrentBIOSVersions) {
        Add-Member -InputObject $PersistentData -NotePropertyName "CurrentBIOSVersions" -NotePropertyValue @()
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
                Save-PersistentData $PersistentData
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

    if($null -eq $result) {
        # If no matching models were found in the database, create the entry
        Write-Host -ForegroundColor Yellow "No matching BIOS information found in database."
        $PersistentData.CurrentBIOSVersions += New-PSObject @{ "Manufacturer" = $sysInfo.Manufacturer; 
                                                                    "Model" = $sysInfo.Model; "BIOSVersion" = $sysInfo.BIOSVersion }
        Save-PersistentData $PersistentData
        Write-Host -ForegroundColor Cyan "Database has been updated."

        $result = @{ "Successful" = $true; "Message" = "No associated BIOS info existed in database." }
    }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}

function Test-IPDT
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [Object]$TestObj,
        [Object]$Common
    )

    $result = $null
    
    $resultObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "All Tests Passed"
    $valueObj = $resultObj.Value

    Write-Host -ForegroundColor White "Wait until the test completes, then indicate whether the test passed."

    $process = Start-Process -FilePath "C:\Program Files\Intel Corporation\Intel Processor Diagnostic Tool 64bit\Win-IPDT64.exe" -WorkingDirectory "C:\Program Files\Intel Corporation\Intel Processor Diagnostic Tool 64bit\" -PassThru

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
            [Object]$TestObj,
        [Object]$Common
    )
    
    $scoreObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Score"
    $scoreValueObj = $scoreObj.Value

    Write-Host -ForegroundColor White "Click `"Run`", wait until the test completes, then enter the given score."
    Write-Host -ForegroundColor White "The expected point range for this machine is $($scoreValueObj.Min)-$($scoreValueObj.Max)."

    $process = Start-Process -FilePath "C:\Program Files\Cinebench R20\Cinebench.exe" -WorkingDirectory "C:\Program Files\Cinebench R20" -PassThru

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
            [Object]$TestObj,
        [Object]$Common
    )

    $scoreObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Score"
    $scoreValueObj = $scoreObj.Value
    $tempObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Average GPU Core Temperature"
    $tempValueObj = $tempObj.Value

    Write-Host -ForegroundColor White "Click the `"1080p`" preset, wait until the test completes, then enter the given score and average GPU core temperature."
    Write-Host -ForegroundColor White "The expected point range for this machine is $($scoreValueObj.Min)-$($scoreValueObj.Max)."
    Write-Host -ForegroundColor White "The expected GPU core temperature range for this machine is $($tempValueObj.Min)-$($tempValueObj.Max)."

    $process = Start-Process -FilePath "C:\Program Files (x86)\Geeks3D\Benchmarks\FurMark\FurMark.exe" -WorkingDirectory "C:\Program Files (x86)\Geeks3D\Benchmarks\FurMark" -PassThru

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
            [Object]$TestObj,
        [Object]$Common
    )

    $scoreObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Score"
    $scoreValueObj = $scoreObj.Value
    $tempObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Average GPU Core Temperature"
    $tempValueObj = $tempObj.Value

    Write-Host -ForegroundColor White "Click the `"1080p`" preset, wait until the test completes, then enter the given score and average GPU core temperature."
    Write-Host -ForegroundColor White "The expected point range for this machine is $($scoreValueObj.Min)-$($scoreValueObj.Max)."
    Write-Host -ForegroundColor White "The expected GPU core temperature range for this machine is $($tempValueObj.Min)-$($tempValueObj.Max)."

    $process = Start-Process -FilePath "C:\Program Files (x86)\Geeks3D\Benchmarks\FurMark - iGPU\FurMark - iGPU.exe" -WorkingDirectory "C:\Program Files (x86)\Geeks3D\Benchmarks\FurMark - iGPU" -PassThru

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
            [Object]$TestObj,
        [Object]$Common
    )

    $scoreObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Score"
    $scoreValueObj = $scoreObj.Value
    $gpuTempObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Average GPU Core Temperature"
    $gpuTempValueObj = $gpuTempObj.Value
    $cpuTempObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Average CPU Max Core Temperature"
    $cpuTempValueObj = $cpuTempObj.Value

    Write-Host -ForegroundColor White "Open HWiNFO64 in sensors-only mode. Click `"Run`" in Heaven. Reset the counters in HWiNFO (click the clock icon)."
    Write-Host -ForegroundColor White "Click `"Benchmark`" in Heaven (or press F9), wait until the test completes, then enter the given score, average GPU core temperature, and average CPU max core temperature."
    Write-Host -ForegroundColor White "The expected point range for this machine is $($scoreValueObj.Min)-$($scoreValueObj.Max)."
    Write-Host -ForegroundColor White "The expected average GPU core temperature range for this machine is $($gpuTempValueObj.Min)-$($gpuTempValueObj.Max)."
    Write-Host -ForegroundColor White "The expected average CPU max core temperature range for this machine is $($cpuTempValueObj.Min)-$($cpuTempValueObj.Max)."

    if(Get-Process | Where-Object {$_.ProcessName -eq "HWiNFO64"} -eq $null) {
        # Start HWiNFO64 if it isn't already running
        Start-Process -FilePath "C:\Program Files\HWiNFO64\HWiNFO64.exe" -WorkingDirectory "C:\Program Files\HWiNFO64"
    }

    Start-Process -FilePath "C:\Program Files (x86)\Unigine\Heaven Benchmark 4.0\heaven.bat" -WorkingDirectory "C:\Program Files (x86)\Unigine\Heaven Benchmark 4.0"


    $scoreResponse = Get-DoubleResponse -Prompt "What score did Heaven give?: "
    $cpuTempResponse = Get-DoubleResponse -Prompt "What average CPU max core temperaturee did HWiNFO64 report?: "
    $gpuTempResponse = Get-DoubleResponse -Prompt "What average GPU core temperature did HWiNFO64 report?: "

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
    Add-Member -InputObject $cpuTempValueObj -NotePropertyName Value -NotePropertyValue $cpuTempResponse
    
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

    $launcherProcess = Get-Process | Where-Object {$_.ProcessName -eq "browser_x86"}
    $gameProcess = Get-Process | Where-Object {$_.ProcessName -eq "Heaven"}

    if(!$launcherProcess.HasExited -or !$gameProcess.HasExited) {
        Write-Host -ForegroundColor Cyan "Please close Heaven to continue (Do NOT close HWiNFO64)..."
        if(!$launcherProcess.HasExited) {
            $launcherProcess.WaitForExit()
        }
        if(!$gameProcess.HasExited) {
            $gameProcess.WaitForExit()
        }
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
            [Object]$TestObj,
        [Object]$Common
    )

    $tempObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Average CPU Max Core Temperature"
    $tempValueObj = $tempObj.Value

    Write-Host -ForegroundColor White "Open HWiNFO64 in sensors-only mode. Choose the `"Small FFTs`" preset in Prime95 and click `"OK`". Reset the counters in HWiNFO (click the clock icon)."
    Write-Host -ForegroundColor White "Wait for at least 15 minutes, then enter the average CPU max core temperature."
    Write-Host -ForegroundColor White "The expected CPU max core temperature range for this machine is $($tempValueObj.Min)-$($tempValueObj.Max)."

    $hwinfoProcess = Get-Process | Where-Object {$_.ProcessName -eq "HWiNFO64"}
    if($null -eq $hwinfoProcess) {
        # Start HWiNFO64 if it isn't already running
        $hwinfoProcess = Start-Process -FilePath "C:\Program Files\HWiNFO64\HWiNFO64.exe" -WorkingDirectory "C:\Program Files\HWiNFO64" -PassThru
    }
    $prime95Process = Start-Process -FilePath "C:\Program Files\Prime95\prime95.exe" -WorkingDirectory "C:\Program Files\Prime95" -PassThru

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
            [Object]$TestObj,
        [Object]$Common
    )
    
    $resultObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "No Errors Detected"
    $valueObj = $resultObj.Value

    Write-Host -ForegroundColor White "Wait until the test completes, then indicate whether the test passed."
    Write-Host -ForegroundColor White "This test is notoriously tricky. You may need to reboot a few times or boot into safe mode in order to get it to start."
    Write-Host -ForegroundColor White "If you cannot get the test to run, skip it and run the Windows Memory Diagnostic instead."

    $process = Start-Process -FilePath "C:\Program Files\MemTest64\MemTest64.exe" -WorkingDirectory "C:\Program Files\MemTest64" -PassThru

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
    
    if($null -ne $commentResponse -and "" -ne $commentResponse) {
        Add-Member -InputObject $valueObj -NotePropertyName Comment -NotePropertyValue $commentResponse
    }

    if(!$process.HasExited) {
        Write-Host -ForegroundColor Cyan "Please close MemTest64 to continue..."
        $process.WaitForExit()
    }

    if($testSkipped) {
        $result = @{ "Successful" = $false; "Skipped" = $true; "Message" = "Test skipped" }
    } else {
        $result = @{ "Successful" = $testPassed }
    }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}

function Test-WinMemDiag
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [Object]$TestObj,
        [Object]$Common
    )
    
    $resultObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "No Errors Detected"
    $valueObj = $resultObj.Value

    $response = Get-KeypressResponse -Prompt "Did MemTest64 start properly? (Y/N): " -Options 'y','Y','n','N'
    if($response -eq 'y' -or $response -eq 'Y') {
        # Skip this test if MemTest64 started properly
        Write-Host -ForegroundColor White "Skipping this test..."
        Add-Member -InputObject $valueObj -NotePropertyName Skipped -NotePropertyValue $true
        Add-Member -InputObject $valueObj -NotePropertyName Comment -NotePropertyValue "Test skipped because MemTest64 was already run."
        $result = @{ "Successful" = $false; "Skipped" = $true; "Message" = "Test skipped because MemTest64 was already run." }

        return @{ "Result"=$result; "TestObj"=$TestObj; }
    }

    $response = Get-KeypressResponse -Prompt "Have you already started this test? (Y/N/(S)kip): " -Options 'y','Y','n','N','s','S'

    $testSkipped = $false
    $testPassed = $false

    if($response -eq 'n' -or $response -eq 'N') {
        # If the test hasn't been started yet

        Write-Host -ForegroundColor White "Wait until the test completes, then indicate whether the test passed."
        Write-Host -ForegroundColor White "This test indicates whether it passed via a notification in the notification center. It may take a few minutes to appear after rebooting."

        Start-Process -FilePath "%windir%\system32\MdSched.exe" -WorkingDirectory "%windir%\system32" | Out-Null
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
    
        if($null -ne $commentResponse -and "" -ne $commentResponse) {
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

function Test-BasicsUSB
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [Object]$TestObj,
        [Object]$Common,
        [Int]$FailDelaySeconds=10
    )

    $cursorPositionBeforeTest = $host.UI.RawUI.CursorPosition
    $testPassed = $true
    foreach($result in $TestObj.Results) {
        Write-Host -ForegroundColor White $result.Name
        Write-Host -ForegroundColor White "Please connect a drive to the port indicated above."

        $cursorPositionBeforeLoop = $host.UI.RawUI.CursorPosition
        $removableDrive = $null
        $continue = $true
        while($continue) {
            foreach($i in (0..($FailDelaySeconds * 4))) {
                # Wait for 10 seconds for the drive to appear
                $removableDrive = Get-PSDrive | Where-Object { $_.Provider.Name -eq "FileSystem" -and $_.Root -notmatch $env:SystemDrive }
                if($null -eq $removableDrive) {
                    Write-Host -ForegroundColor Red "`rNo removable drive detected. $($FailDelaySeconds - [math]::Floor($i / 4)) second(s) remaining." -NoNewline
                    Start-Sleep -Milliseconds 250
                } else {
                    Write-Host -ForegroundColor Green "`rRemovable drive $($removableDrive.Name) detected.                                "
                    break
                }
            }
            
            if($null -eq $removableDrive) {
                Write-Host -ForegroundColor Yellow "`rNo removable drive was detected.                                     "
                $response = Get-KeypressResponse -Prompt "Try this port again? (Y/N): " -Options 'y','Y','n','N'
    
                if($response -eq 'n' -or $response -eq 'N') {
                    Write-Host -ForegroundColor Yellow "Marking this port as failed."
                    Add-Member -InputObject $result.Value -NotePropertyName Value -NotePropertyValue $false
                    Add-Member -InputObject $result.Value -NotePropertyName Comment -NotePropertyValue "This port did not detect any drives."
                    $continue = $false
                    $testPassed = $false
                }
            } else {
                $response = Get-KeypressResponse -Prompt "Can you read/write from/to the drive? (Y/N/(R)etry): " -Options 'y','Y','n','N','r','R'

                if($response -eq 'y' -or $response -eq 'Y') {
                    Add-Member -InputObject $result.Value -NotePropertyName Value -NotePropertyValue $true
                    $continue = $false
                } elseif($response -eq 'n' -or $response -eq 'N') {
                    Write-Host -ForegroundColor Yellow "Marking this port as failed."
                    Add-Member -InputObject $result.Value -NotePropertyName Value -NotePropertyValue $false
                    Add-Member -InputObject $result.Value -NotePropertyName Comment -NotePropertyValue "This port could not be written to or read from."
                    $continue = $false
                    $testPassed = $false
                }
            }
        }

    }

    return @{ "Result"=@{ "Successful" = $testPassed }; "TestObj"=$TestObj; }
}

function Test-BasicsDisplay
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [Object]$TestObj,
        [Object]$Common
    )

    $testPassed = $true
    
    $lcdObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "No LCD Defects Detected"
    $lcdValueObj = $lcdObj.Value

    Write-Host -ForegroundColor White "Test the display showing all white, black, red, green and blue."
    Write-Host -ForegroundColor White "Search for light spots, stuck pixels, and scratches in the top layer."

    $process = Start-Process -FilePath "C:\Program Files (x86)\MonitorTest\monitorTest.exe" -PassThru

    $response = Get-KeypressResponse -Prompt "Did the display pass? (Y/N): " -Options "y","Y","n","N"
    $commentResponse = Read-Host -Prompt "Do you have any comments? (Leave blank to skip): "

    if($response -eq 'y' -or $response -eq 'Y') {
        Add-Member -InputObject $lcdValueObj -NotePropertyName Value -NotePropertyValue $true
    } else { 
        Add-Member -InputObject $lcdValueObj -NotePropertyName Value -NotePropertyValue $false
        $testPassed = $false
    }
    
    if($null -ne $commentResponse -and "" -ne $commentResponse) {
        Add-Member -InputObject $lcdValueObj -NotePropertyName Comment -NotePropertyValue $commentResponse
    }

    if(!$process.HasExited) {
        Write-Host -ForegroundColor Cyan "Please close MonitorTest to continue..."
        $process.WaitForExit()
    }

    $touchObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Touchscreen Works"
    if($null -ne $touchObj) {
        $touchValueObj = $touchObj.Value
        # If we should also test the touch display.
        Write-Host -ForegroundColor White "Touchscreen Test."
        $process = Start-Process "www.neumont.edu"
        Write-Host -ForegroundColor White "Go to the web page and test that you can pinch zoom on it."
        if(!$process.HasExited) {
            Write-Host -ForegroundColor Cyan "Please close the browser to continue..."
            $process.WaitForExit()
        }
        Write-Host -ForegroundColor White "On the desktop, test dragging an icon around to all four corners of the display, then back to the center."
        Write-Host -ForegroundColor White "On the desktop, tap with 5 fingers and verify that all 5 taps appear."

        $response = Get-KeypressResponse -Prompt "Did the touch tests pass? (Y/N): " -Options "y","Y","n","N"
        $commentResponse = Read-Host -Prompt "Do you have any comments? (Leave blank to skip): "

        if($response -eq 'y' -or $response -eq 'Y') {
            Add-Member -InputObject $touchValueObj -NotePropertyName Value -NotePropertyValue $true
        } else {
            Add-Member -InputObject $touchValueObj -NotePropertyName Value -NotePropertyValue $false
            $testPassed = $false
        }
        
        if($null -ne $commentResponse -and "" -ne $commentResponse) {
            Add-Member -InputObject $touchValueObj -NotePropertyName Comment -NotePropertyValue $commentResponse
        }
    }

    return @{ "Result"=@{"Successful"=$testPassed}; "TestObj"=$TestObj; }
}

function Test-BasicsHDMI
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [Object]$TestObj,
        [Object]$Common
    )

    $result = $null
    
    $resultObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Image Was Displayed"
    $valueObj = $resultObj.Value

    Write-Host -ForegroundColor White "Connect the machine to an HDMI monitor and verify that an image from the laptop is displayed."
    Write-Host -ForegroundColor Yellow "Wait for a minimum of 30 seconds after connecting to the display before marking this test as failed."

    $response = Get-KeypressResponse -Prompt "Was an image displayed? (Y/N): " -Options "y","Y","n","N"

    if($response -eq 'y' -or $response -eq 'Y') {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
        $result = @{ "Successful" = $true; }
    } else {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $false
        $result = @{ "Successful" = $false;}
    }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}

function Test-BasicsSound
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [Object]$TestObj,
        [Object]$Common
    )

    $testPassed = $true
    
    $resultObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Speakers Passed"
    $valueObj = $resultObj.Value

    Write-Host -ForegroundColor White "Play the windows test tone and listen for channel balance, speaker rattling, or sound distortion."
    Write-Host -ForegroundColor Yellow "Verify beforehand that `"Audio Enhancemens`" are off in the speakers sound device advanced settings."

    $response = Get-KeypressResponse -Prompt "Do the speakers sound balanced and free from rattling and distortion? (Y/N): " -Options "y","Y","n","N"
    $commentResponse = Read-Host -Prompt "Do you have any comments? (Leave blank to skip): "

    if($response -eq 'y' -or $response -eq 'Y') {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
    } else {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $false
        $testPassed = $false
    }
    
    if($null -ne $commentResponse -and "" -ne $commentResponse) {
        Add-Member -InputObject $valueObj -NotePropertyName Comment -NotePropertyValue $commentResponse
    }
    
    $resultObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Headphone Jack Passed"
    $valueObj = $resultObj.Value

    Write-Host -ForegroundColor White "Connect headphones to the headphone jack, then play the windows test tone and listen for channel balance."

    $response = Get-KeypressResponse -Prompt "Do the sound balanced? (Y/N): " -Options "y","Y","n","N"
    $commentResponse = Read-Host -Prompt "Do you have any comments? (Leave blank to skip): "

    if($response -eq 'y' -or $response -eq 'Y') {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
    } else {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $false
        $testPassed = $false
    }
    
    if($null -ne $commentResponse -and "" -ne $commentResponse) {
        Add-Member -InputObject $valueObj -NotePropertyName Comment -NotePropertyValue $commentResponse
    }

    return @{ "Result"=$testPassed; "TestObj"=$TestObj; }
}

function Test-BasicsNetwork
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [Object]$TestObj,
        [Object]$Common
    )

    $testPassed = $true
    
    $resultObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Wi-Fi Connection Works"
    $valueObj = $resultObj.Value

    Write-Host -ForegroundColor White "Connect to Wi-Fi and verify that a webpage can be loaded."
    
    netsh wlan connect name=Neumont
    Write-Host -ForegroundColor White "Connecting to Neumont Wi-Fi..."
    Start-Sleep -Seconds 3
    $process = Start-Process -FilePath "www.msn.com"

    $response = Get-KeypressResponse -Prompt "Did the webpage load? (Y/N): " -Options "y","Y","n","N"

    if($response -eq 'y' -or $response -eq 'Y') {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
    } else {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $false
        $testPassed = $false
    }
    netsh wlan disconnect
    Write-Host -ForegroundColor White "Disconnecting from Neumont Wi-Fi..."
    Start-Sleep -Seconds 2

    $wiredValueObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Wired Connection Works"
    if($null -ne $wiredValueObj) {
        # If we should also test the touch display.
        Write-Host -ForegroundColor White "Connect the wired network adapter and verify that a webpage can be loaded."
        $response = Get-KeypressResponse -Prompt "Is the network adapter connected? (C)ontinue?: " -Options "c","C"
        $process = Start-Process -FilePath "www.yahoo.com"
        $response = Get-KeypressResponse -Prompt "Did the webpage load? (Y/N): " -Options "y","Y","n","N"

        if($response -eq 'y' -or $response -eq 'Y') {
            Add-Member -InputObject $wiredValueObj -NotePropertyName Value -NotePropertyValue $true
        } else {
            Add-Member -InputObject $wiredValueObj -NotePropertyName Value -NotePropertyValue $false
            $testPassed = $false
        }

        Write-Host -ForegroundColor Cyan "Please disconnect the wired network adapter."
    }

    return @{ "Result"=@{"Successful"=$testPassed}; "TestObj"=$TestObj; }
}

function Test-BasicsKeyboard
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [Object]$TestObj,
        [Object]$Common
    )

    $testPassed = $true
    
    $resultObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "All Keys Work"
    $valueObj = $resultObj.Value

    Write-Host -ForegroundColor White "Go to keyboardtester.com/tester.html and verify that every keyboard key registers in the OS."

    netsh wlan connect name=Neumont
    Write-Host -ForegroundColor White "Connecting to Neumont Wi-Fi..."
    Start-Sleep -Seconds 3
    $process = Start-Process -FilePath "www.keyboardtester.com/tester.html"
    # Wait a bit for the page to load, then disconnect from Wi-Fi
    Start-Sleep -Seconds 3
    netsh wlan disconnect

    $response = Get-KeypressResponse -Prompt "Did all the keys register? (Y/N): " -Options "y","Y","n","N"
    $commentResponse = Read-Host -Prompt "Do you have any comments? (Leave blank to skip): "

    if($response -eq 'y' -or $response -eq 'Y') {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
    } else {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $false
        $testPassed = $false
    }
    
    if($null -ne $commentResponse -and "" -ne $commentResponse) {
        Add-Member -InputObject $valueObj -NotePropertyName Comment -NotePropertyValue $commentResponse
    }

    return @{ "Result"=@{"Successful" = $testPassed}; "TestObj"=$TestObj; }
}

function Test-BasicsCursor
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [Object]$TestObj,
        [Object]$Common
    )

    $testPassed = $true
    
    $resultObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Trackpad Works"
    $valueObj = $resultObj.Value

    Write-Host -ForegroundColor White "Use the trackpad to move the cursor, left click, right click, and scroll."

    $response = Get-KeypressResponse -Prompt "Did the trackpad work normally? (Y/N): " -Options "y","Y","n","N"
    $commentResponse = Read-Host -Prompt "Do you have any comments? (Leave blank to skip): "

    if($response -eq 'y' -or $response -eq 'Y') {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
    } else {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $false
        $testPassed = $false
    }
    
    if($null -ne $commentResponse -and "" -ne $commentResponse) {
        Add-Member -InputObject $valueObj -NotePropertyName Comment -NotePropertyValue $commentResponse
    }

    $trackpointObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "TrackPoint Works"
    if($null -ne $trackpointObj) {
        $trackpointValueObj = $trackpointObj.Value
        # If we should also test the touch display.
        Write-Host -ForegroundColor White "Use the TrackPoint to move the cursor, left click, right click, and scroll."
        $response = Get-KeypressResponse -Prompt "Did the TrackPoint work normally? (Y/N): " -Options "y","Y","n","N"
        $commentResponse = Read-Host -Prompt "Do you have any comments? (Leave blank to skip): "

        if($response -eq 'y' -or $response -eq 'Y') {
            Add-Member -InputObject $trackpointValueObj -NotePropertyName Value -NotePropertyValue $true
        } else {
            Add-Member -InputObject $trackpointValueObj -NotePropertyName Value -NotePropertyValue $false
            $testPassed = $false
        }
    
        if($null -ne $commentResponse -and "" -ne $commentResponse) {
            Add-Member -InputObject $valueObj -NotePropertyName Comment -NotePropertyValue $commentResponse
        }
    }

    return @{ "Result"=@{"Successful" = $testPassed}; "TestObj"=$TestObj; }
}

function Test-BasicsCamera
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [Object]$TestObj,
        [Object]$Common
    )

    $result = $null
    
    $resultObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "Camera Works"
    $valueObj = $resultObj.Value

    Write-Host -ForegroundColor White "Open the Camera application and verify that the camera is working normally."
   
    $process = Start-Process "C:\Program Files\Camera\Camera.exe" -PassThru

    $response = Get-KeypressResponse -Prompt "Is the camera working normally? (Y/N): " -Options "y","Y","n","N"
    $commentResponse = Read-Host -Prompt "Do you have any comments? (Leave blank to skip): "

    if($response -eq 'y' -or $response -eq 'Y') {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
        $result = @{ "Successful" = $true; }
    } else {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $false
        $result = @{ "Successful" = $false; }
    }
    
    if($null -ne $commentResponse -and "" -ne $commentResponse) {
        Add-Member -InputObject $valueObj -NotePropertyName Comment -NotePropertyValue $commentResponse
    }

    return @{ "Result"=$result; "TestObj"=$TestObj; }
}

function Test-BasicsPhysical
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [Object]$TestObj,
        [Object]$Common
    )

    $result = $null

    $resultObj = $TestObj.Results | Where-Object -Property "Name" -EQ -Value "No Crashes Occurred"
    $valueObj = $resultObj.Value

    Write-Host -ForegroundColor White "Push down on the machine's keyboard, then pick the machine up and twist the chassis from the corners."

    $response = Get-KeypressResponse -Prompt "Is the machine still operating normally? (Y/N): " -Options "y","Y","n","N"
    $commentResponse = Read-Host -Prompt "Do you have any comments? (Leave blank to skip): "

    if($response -eq 'y' -or $response -eq 'Y') {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $true
        $result = @{ "Successful" = $true; }
    } else {
        Add-Member -InputObject $valueObj -NotePropertyName Value -NotePropertyValue $false
        $result = @{ "Successful" = $false;}
    }
    
    if($null -ne $commentResponse -and "" -ne $commentResponse) {
        Add-Member -InputObject $valueObj -NotePropertyName Comment -NotePropertyValue $commentResponse
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
Export-ModuleMember -Function "Test-BasicsUSB"
Export-ModuleMember -Function "Test-BasicsDisplay"
Export-ModuleMember -Function "Test-BasicsHDMI"
Export-ModuleMember -Function "Test-BasicsSound"
Export-ModuleMember -Function "Test-BasicsNetwork"
Export-ModuleMember -Function "Test-BasicsKeyboard"
Export-ModuleMember -Function "Test-BasicsCursor"
Export-ModuleMember -Function "Test-BasicsCamera"
Export-ModuleMember -Function "Test-BasicsPhysical"