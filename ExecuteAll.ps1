Import-Module WebAdministration

$websites = Get-Website

foreach ($site in $websites) {
    $siteId = $site.Id
    $siteName = $site.Name
    Write-Host "Bearbeite Website ID: $siteId (Name: $siteName)"


    $iis = Join-Path $PSScriptRoot -ChildPath "AnalyzeIISLogs.ps1"
    & $iis -websiteNr $site.Id; 

    $system = Join-Path $PSScriptRoot -ChildPath "CollectSystemInfo.ps1"
    & $system -websiteNr $site.Id; 

    $nmap = Join-Path $PSScriptRoot -ChildPath "ScanServer.ps1"
    & $nmap -websiteNr $site.Id;

    $index = Join-Path $PSScriptRoot -ChildPath "makeindex.ps1"
    & $index -websiteNr $site.Id;


    $bindings = Get-WebBinding -Name $siteName
    foreach ($binding in $bindings) {
        Write-Host " - Binding: $($binding.protocol) $($binding.bindingInformation)"
    }
}
