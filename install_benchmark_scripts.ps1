Copy-Item -Path "$PSScriptRoot\Scripts" -Destination "$HOME\Documents\" -Recurse -Force
Move-Item -Path "$HOME\Documents\Scripts\startBenchmarks.ps1" -Destination "$HOME\Desktop" -Force