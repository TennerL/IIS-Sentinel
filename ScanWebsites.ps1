
Import-Module WebAdministration


$sites = Get-Website | ForEach-Object {
    [PSCustomObject]@{
        ID   = $_.ID
        Name = $_.Name
    }
}


$json = $sites | ConvertTo-Json -Depth 2


$json | Out-File -Encoding UTF8 -FilePath "./websites.json"

Write-Host "websites.json wurde erfolgreich erstellt."
