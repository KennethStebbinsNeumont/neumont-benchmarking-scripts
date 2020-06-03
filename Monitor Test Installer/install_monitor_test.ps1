New-Item -Path 'C:\Program Files (x86)\MonitorTest\' -ItemType Directory -ErrorAction Continue -InformationAction Ignore

Copy-Item -Path "$PSScriptRoot\monitorTest.exe" -Destination 'C:\Program Files (x86)\MonitorTest\'