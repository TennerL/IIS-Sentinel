param (
[string]$websiteNr = ""
)


$servers = @(
    "nihonsaba.net"
)

# Speicherort der Ergebnisse
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outputDir = Join-Path -Path $PSScriptRoot -ChildPath "reports\$($websiteNr)\nmap"
$jsonFile = "$outputDir\nmap_$timestamp.json"
if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}


$results = @()
foreach ($server in $servers) {
    $nmapOutput = nmap -Pn -sV $server | Out-String

    $results += [PSCustomObject]@{
        Server = $server
        Timestamp = $timestamp
        Output = $nmapOutput
    }
}

# JSON speichern
$results | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonFile -Encoding UTF8
