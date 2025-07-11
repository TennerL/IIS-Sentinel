param (
[string]$websiteNr = "",
[string]$timestamp = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss"),
[string]$reportFile = (Join-Path -Path $PSScriptRoot -ChildPath "\reports\$($websiteNr)\system\system_$timestamp.json"),
[string]$reportFolder = (Join-Path -Path $PSSCriptRoot -ChildPath "\reports\$($websiteNr)\system")
)


if(-not(Test-Path -Path $reportFolder)){
    New-Item -Path $reportFolder -ItemType directory 
}


# OS Info
$osInfo = Get-CimInstance Win32_OperatingSystem

# Uptime berechnen
$lastBootTime = $osInfo.LastBootUpTime
$now = Get-Date
$uptime = $now - $lastBootTime

# Letztes Update ermitteln
$latestUpdate = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1


$baseVersion = $osInfo.Version
$ubr = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name UBR | Select-Object -ExpandProperty UBR
$fullVersion = "$baseVersion.$ubr"


$data = [PSCustomObject]@{
    Timestamp = $timestamp
    DefenderStatus = Get-MpComputerStatus
    PendingUpdates = (Get-WindowsUpdate -AcceptAll -IgnoreReboot).Count
    FirewallState = (Get-NetFirewallProfile | Select-Object Name, Enabled)
    LastBootTime = $lastBootTime
    Uptime = $uptime.ToString("dd\.hh\:mm\:ss")  # Tage.Stunden:Minuten:Sekunden
    LatestUpdate = if ($latestUpdate) { $latestUpdate.HotFixID } else { "Keine Updates gefunden" }
    OSName = $osInfo.Caption
    Build = $fullVersion
    OSBuild = $fullVersion
}

$data | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $reportFile


# 2. VSRT (Vulnerability Scan) mit Shodan CVE API
$cpe = "cpe:2.3:o:microsoft:windows_server_2019:$fullVersion"
$encodedCpe = [System.Net.WebUtility]::UrlEncode($cpe)
$apiUrl = "https://cvedb.shodan.io/cves?cpe23=$encodedCpe"

#try {
    $cvData = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
    $sorted = $cvData | Sort-Object -Property cvss -Descending | Select-Object -First 10

    $vulReport = [PSCustomObject]@{
        OSBuild       = $fullVersion
        TopVulnerabilities = $sorted
    }

    $vulReport | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path -Path $PSScriptRoot -ChildPath "\reports\$($websiteNr)\system\vulnerabilities_$timestamp.json")
#}
#catch {
#    Write-Warning "CVE-Abfrage fehlgeschlagen: $_"
#}