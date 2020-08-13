# https://blog.expta.com/2017/03/how-to-self-elevate-powershell-script.html
# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
     $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
     Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
     Exit
    }
}

if (!Test-Path -LiteralPath 'C:\Program Files (x86)\MonitorTest\' -Type Container) {
    try {
        New-Item -Path 'C:\Program Files (x86)\MonitorTest\' -ItemType Directory -ErrorAction Stop | Out-Null
        Write-Host -ForegroundColor Cyan "Created installation directory at C:\Program Files (x86)\MonitorTest\"
    } catch {
        Write-Host -ForegroundColor Red "Unable to create a folder at C:\Program Files (x86)\MonitorTest\"
        Write-Host -ForegroundColor White "Press ENTER to exit..."
        Read-Host | Out-Null
        exit 1
    }
}

try {
    Copy-Item -Path "$PSScriptRoot\monitorTest.exe" -Destination 'C:\Program Files (x86)\MonitorTest\' -Force -ErrorAction Stop
    Write-Host -ForegroundColor Cyan "Copied monitorTest.exe into installation directory"
} catch {
    Write-Host -ForegroundColor Red "Unable to copy monitorTest.exe from script's root directory to installation directory."
    Write-Host -ForegroundColor White "Press ENTER to exit..."
    Read-Host | Out-Null
    exit 1
}