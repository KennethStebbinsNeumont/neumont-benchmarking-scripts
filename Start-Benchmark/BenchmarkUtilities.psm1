function Convert-WildcardToRegex
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [String]$WildcardText
    )

    $result = [Regex]::Escape($WildcardText)
    $result = $result -replace "\\\*", ".*"

    return $result
}

function New-PSObject
{
    Param(
        [Parameter(Position=1)]
            [System.Collections.Hashtable]$Property
    )

    if($Property) {
        return New-Object -TypeName PSObject -Property $Property
    } else {
        return New-Object -TypeName PSObject
    }
}

function Get-KeypressResponse
{
    Param(
        [String]$Prompt,
        [Char[]]$Options
    )

    if($Options) {
        $optionsString = ""
        $firstOptionAdded = $false
        foreach($option in $Options) {
            if(!$firstOptionAdded) {
                $optionsString += $option
                $firstOptionAdded = $true
            } else {
                $optionsString += ", $option"
            }
        }
    }

    while($true) {
        if($Prompt) {
            Write-Host -ForegroundColor White $Prompt -NoNewline
        }
        $response = $Host.UI.RawUI.ReadKey().Character
        Write-Host
        if(!$Options -or $Options -contains $response) {
            return $response
        } else {
            Write-Host -ForegroundColor White "Unrecognized response: $response. Options are $optionsString"
        }
    }
}

function Get-DoubleResponse
{
    Param(
        [String]$Prompt,
        [Double]$Minimum=[Double]::MinValue,
        [Double]$Maximum=[Double]::MaxValue
    )

    while($true) {
        if($Prompt) {
            Write-Host -ForegroundColor White $Prompt -NoNewline
        }
        $response = Read-Host
        try {
            $doubleResponse = [Double]$response

            if($doubleResponse -gt $Maximum -or $doubleResponse -lt $Minimum) {
                Write-Host -ForegroundColor White "Response out of range. Must be within [$Minimum-$Maximum], inclusive."
            } else {
                return $doubleResponse
            }
        } catch {
            Write-Host -ForegroundColor White "Response must be a number."
        }
    }
}

function Get-TypedResponse
{
    Param(
        [String]$Prompt
    )

    if($Prompt) {
        Write-Host -ForegroundColor White $Prompt -NoNewline
    }
    return Read-Host
}

function Get-SystemInfo
{
    $WMIWin32_ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $WMIWin32_BIOS = Get-WmiObject -Class Win32_BIOS

    $model_name = $WMIWin32_ComputerSystem.Model
    $mfr_name = $WMIWin32_ComputerSystem.Manufacturer
    $serial = $WMIWin32_BIOS.SerialNumber
    $biosVersion = $WMIWin32_BIOS.SMBIOSBIOSVersion
    
    return New-PSObject -Property @{
        "Model" = $model_name;
        "Manufacturer" = $mfr_name;
        "SerialNumber" = $serial;
        "BiosVersion" = $biosVersion;
    }
}

function Test-SysInfoMatch
{
    Param(
        [Parameter(Position=1)]
            [Object]$SysInfo=(Get-SystemInfo),
        [String]$Manufacturer,
        [String]$Model
    )

    return (!$Manufacturer -or $SysInfo.Manufacturer -match (Convert-WildcardToRegex $Manufacturer)) -and
                (!$Model -or $SysInfo.Model -match (Convert-WildcardToRegex $Model))
}

function Get-PersistentData
{
    Param(
        [String]$FilePath = "$PSScriptRoot\persistentdata.json"
    )

    $result = $null
    try {
        $result = Get-Content $FilePath -ErrorAction Stop | ConvertFrom-Json
    } catch {}

    if($null -eq $result) {
        $result = New-PSObject
    }

    # Add the file path as part of the object
    Add-Member -InputObject $result -NotePropertyName "FilePath" -NotePropertyValue "$FilePath"

    return $result
}

function Save-PersistentData
{
    Param(
        [Parameter(Mandatory=$true,Position=1)][PSObject]$PersistentData,
        [String]$FilePath
    )

    if(!$FilePath) {
        $FilePath = $PersistentData.FilePath
    }

    # Don't save the file path as part of the object
    $ClonedPersistentData = $PersistentData.PSObject.Copy()
    $ClonedPersistentData.PSObject.Properties.Remove("FilePath")

    ConvertTo-Json $ClonedPersistentData -Depth 100 | Out-File $FilePath
}

function New-ResultData
{
    Param(
        [Parameter(Mandatory=$true)]
            [String]$FilePath,
        [Object]$SysInfo=(Get-SystemInfo)
    )
    $date = Get-Date

    return New-PSObject -Property @{
        "FilePath" = $FilePath;
        "Date" = $date;
        "Device" = New-PSObject @{
            "Manufacturer" = $SysInfo.Manufacturer;
            "Model" = $SysInfo.Model;
            "SerialNumber" = $SysInfo.SerialNumber;
        };
        "Tests" = [System.Collections.ArrayList]@();
        "TestsComplete" = $false;
        "Passed" = $false;
    }
}

function Get-ResultData
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [String]$FilePath
    )

    $result = Get-Content $FilePath | ConvertFrom-Json

    # Add the file path as part of the object
    Add-Member -InputObject $result -NotePropertyName "FilePath" -NotePropertyValue "$FilePath"

    return $result
}

function Save-ResultData
{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
            [PSObject]$ResultData,
        [String]$FilePath
    )

    if(!$FilePath) {
        $FilePath = $ResultData.FilePath
    }

    # Don't save the file path as part of the object
    $ClonedResultData = $ResultData.PSObject.Copy()
    $ClonedResultData.PSObject.Properties.Remove("FilePath")

    ConvertTo-Json $ClonedResultData -Depth 100 | Out-File $FilePath
}
function Get-Tests
{
    Param(
        [Parameter(Mandatory=$true)]
            [String]$FilePath
    )

    $sysInfo = Get-SystemInfo
    $allTests = Get-Content $FilePath | ConvertFrom-Json

    $applicableTests = @()
    foreach($test in $allTests) {
        $applicableTest = $test.PSObject.Copy()
        $applicableTest.Results = @()
        foreach($result in $test.Results) {
            foreach($value in $result.Values) {
                if(Test-SysInfoMatch $sysInfo -Manufacturer $value.Manufacturer -Model $value.Model) {
                    # If we've found a matching result value
                    $newResult = $result.PSObject.Copy()
                    $newResult.PSObject.Properties.Remove("Values")

                    $valueObj = $value.PSObject.Copy()
                    if($value.Manufacturer) {
                        $valueObj.PSObject.Properties.Remove("Manufacturer")
                    }
                    if($value.Model) {
                        $valueObj.PSObject.Properties.Remove("Model")
                    }

                    Add-Member -InputObject $newResult -NotePropertyName "Value" -NotePropertyValue $valueObj

                    $applicableTest.Results += $newResult
                }
            }
        }
        if($applicableTest.Results.Count -gt 0) {
            $applicableTests += $applicableTest
        }
    }

    return $applicableTests
}

function Clear-Screen
{
    Param(
        [System.Management.Automation.Host.Coordinates]
            $BeginningPosition
    )

    $windowSize = $host.UI.RawUI.WindowSize
    $windowPosition = $host.UI.RawUI.WindowPosition

    if(!$BeginningPosition) {
        # If no beginning position was given, use the window's position
        $BeginningPosition = $windowPosition
    }
    
    $host.UI.RawUI.CursorPosition = $BeginningPosition

    # Clear the first row, leaving any characters to the left alone
    Write-Host (' ' * $windowSize.Width - $BeginningPosition.X)

    foreach($row in 0..($windowSize.Height + $windowPosition.Y - $BeginningPosition.Y + 2)) {
        Write-Host (' ' * $windowSize.Width)
    }

    $host.UI.RawUI.CursorPosition = $BeginningPosition

    return @{ "WindowSize" = $windowSize; "WindowPosition" = $windowPosition;
                "BeginningPosition" = $BeginningPosition;}
}

# Exports
Export-ModuleMember -Function "Convert-WildcardToRegex"
Export-ModuleMember -Function "New-PSObject"
Export-ModuleMember -Function "Get-KeypressResponse"
Export-ModuleMember -Function "Get-DoubleResponse"
Export-ModuleMember -Function "Get-TypedResponse"
Export-ModuleMember -Function "Get-SystemInfo"
Export-ModuleMember -Function "Test-SysInfoMatch"
Export-ModuleMember -Function "Get-PersistentData"
Export-ModuleMember -Function "Save-PersistentData"
Export-ModuleMember -Function "New-ResultData"
Export-ModuleMember -Function "Get-ResultData"
Export-ModuleMember -Function "Save-ResultData"
Export-ModuleMember -Function "Get-Tests"