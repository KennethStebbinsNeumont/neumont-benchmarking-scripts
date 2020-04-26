function Get-Function2 {
    return "VAL OF FUN2; Fun3: $(Get-Function3)"
}

Export-ModuleMember -Function Get-Function2