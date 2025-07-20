param (
    [string]$websiteNr = "",
    [string]$InputFolder = "C:\inetpub\logs\LogFiles\W3SVC$($websiteNr)",
    [string]$OutputFolder = "$PSScriptRoot\reports\$($websiteNr)\iis",
    [string]$ApiKey = "XXXX"
)


# AbuseIPDB API URL (Check IP)
$apiUrlTemplate = "https://api.abuseipdb.com/api/v2/check?ipAddress={0}&maxAgeInDays=90"

# Ordner erstellen, falls nicht vorhanden
if (!(Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

$cutoffDate = (Get-Date).AddDays(-7)
$logFiles = Get-ChildItem -Path $InputFolder -Filter *.log -Recurse |
    Where-Object { $_.LastWriteTime -ge $cutoffDate }

$allIPs = @()

# Alle Logs sammeln
$allLogsRaw = @()
$currentFields = @()

foreach ($logFile in $logFiles) {
    $lines = Get-Content $logFile.FullName
    $headerSet = $false
    $lineNumber = 0

    foreach ($line in $lines) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ($line -like "#Fields:*") {
            $fieldLine = $line.Substring(8).Trim()
            $currentFields = $fieldLine -split ' '
            $headerSet = $true
            continue
        }

        if ($line.StartsWith("#")) { continue }

        if ($headerSet) {
            $values = $line -split ' '
            if ($values.Count -eq $currentFields.Count) {
                $entry = [ordered]@{}
                for ($i = 0; $i -lt $currentFields.Count; $i++) {
                    $entry[$currentFields[$i]] = $values[$i]
                }
                $entry["LogFile"] = $logFile.FullName
                $allLogsRaw += $entry
            } else {
                Write-Warning "Spaltenanzahl stimmt nicht überein in $($logFile.FullName) (Zeile $lineNumber)"
            }
        } else {
            Write-Warning "Keine Felddefinition vor Datenzeile in Datei $($logFile.FullName) (Zeile $lineNumber)"
        }
    }
}




# Ausgabe mit Zeitstempel
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outputFile = Join-Path $OutputFolder "iislog_$timestamp.json"
$allLogs = $allLogsRaw

$allLogs | ConvertTo-Json -Depth 5 | Out-File -Encoding UTF8 $outputFile


foreach ($logFile in $logFiles) {
    $lines = Get-Content $logFile.FullName
    $currentFields = @()
    $headerSet = $false

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -like "#Fields:*") {
            $currentFields = $line.Substring(8).Trim() -split ' '
            $headerSet = $true
            continue
        }
        if ($line.StartsWith("#") -or -not $headerSet) { continue }

        $values = $line -split ' '
        if ($values.Count -eq $currentFields.Count) {
            $entry = @{}
            for ($i = 0; $i -lt $currentFields.Count; $i++) {
                $entry[$currentFields[$i]] = $values[$i]
            }
            if ($entry.ContainsKey("c-ip")) {
                $allIPs += $entry["c-ip"]
            }
        }
    }
}


# --- IPs bereinigen und gruppieren ---
$ipGroups = $allIPs | Where-Object { $_ } |
    Group-Object | Sort-Object Count -Descending

$distinctIPs = $ipGroups | ForEach-Object {
    [PSCustomObject]@{
        IP = $_.Name
        Count = $_.Count
    }
} 

# Beispiel-Whitelist
$whitelist = @("127.0.0.1", "192.168.0.1", "10.0.0.1", "217.91.74.126")

# Funktion zur Erkennung von lokalen/private IPs
function Is-LocalIP {
    param([string]$ip)
    return ($ip -match "^127\." -or `
            $ip -match "^10\." -or `
            $ip -match "^192\.168\." -or `
            $ip -match "^172\.(1[6-9]|2[0-9]|3[0-1])\.")
}

function Invoke-AbuseIPDBCheck {
    param (
        [string]$ip,
        [string]$apiKey
    )

    $uri = "https://api.abuseipdb.com/api/v2/check?ipAddress=$ip&maxAgeInDays=90"
    
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept", "application/json")
    $headers.Add("Key", $apiKey)

    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET
        return $response.data
    }
    catch {
        return @{ error = "Request failed: $($_.Exception.Message)" }
    }
}



# --- AbuseIPDB Prüfung ---
$checkedResults = @()

#$distinctIPs = $distinctIPs | Select-Object -First 1


foreach ($item in $distinctIPs) {
    $ip = $item.IP
    $count = $item.Count

    if ($whitelist -contains $ip -or (Is-LocalIP $ip)) {
        $checkedResults += [PSCustomObject]@{
            ip           = $ip
            sourceCount  = $count
            whitelisted  = $true
            note         = "Local or whitelisted - skipped"
        }
        continue
    }

    Start-Sleep -Seconds 1  # Free tier rate limit

    $data = Invoke-AbuseIPDBCheck -ip $ip -apiKey $ApiKey

    if ($data.error) {
        $checkedResults += [PSCustomObject]@{
            ip           = $ip
            sourceCount  = $count
            error        = $data.error
        }
    }
    else {
        $checkedResults += [PSCustomObject]@{
            ip                     = $ip
            sourceCount            = $count
            abuseConfidenceScore   = $data.abuseConfidenceScore
            countryCode            = $data.countryCode
            usageType              = $data.usageType
            isp                    = $data.isp
            domain                 = $data.domain
        }
    }
}

# --- Ergebnisse speichern ---
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outputIPFile = Join-Path $OutputFolder "checked_ips_$timestamp.json"

$checkedResults | ConvertTo-Json -Depth 5 | Out-File -Encoding UTF8 $outputIPFile

Write-Host "IP-Check abgeschlossen: $outputIPFile"
