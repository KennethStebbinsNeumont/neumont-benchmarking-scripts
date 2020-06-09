Copy-Item -Path "$PSScriptRoot\Scripts" -Destination "$HOME\Documents\" -Recurse -Force
New-Item -Type Directory -Path "$HOME\Documents\Scripts\Results" -Force | Out-Null
Move-Item -Path "$HOME\Documents\Scripts\startBenchmarks.ps1" -Destination "$HOME\Desktop" -Force