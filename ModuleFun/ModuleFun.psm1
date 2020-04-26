function Start-ModuleFun {
    Write-Host "Function2: $(Get-Function2)"
    Write-Host "Function3: $(Get-Function3)"

    Get-Command -Verb Test -Module "Module2","Module3" | % {Write-Host $_.Name}
}

Export-ModuleMember -Function "Start-ModuleFun"