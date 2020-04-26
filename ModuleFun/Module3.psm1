function Get-Function3 {
    return "value of function 3!"
}

function Test-Function3 {
    return "TESTTTTT3"
}

Export-ModuleMember -Function Get-Function3
Export-ModuleMember -Function Test-Function3