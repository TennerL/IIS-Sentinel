# === CONFIG ===
$VulnersApiKey = "XXXX"
$OutputFile    = "$PSScriptRoot\VulnerabilityReport.json"

$ProgramsToCheck = @(
  @{ Vendor="Microsoft"; Product="IIS"; VersionFunc={
      $reg = Get-ItemProperty "HKLM:\Software\Microsoft\InetStp" -ErrorAction SilentlyContinue
      if ($reg) { "$($reg.MajorVersion).$($reg.MinorVersion)" } else { $null }
    }},
  @{ Vendor="PHP"; Product="php"; VersionFunc={
      $exe = Get-Command php.exe -ErrorAction SilentlyContinue
      if ($exe) { (Get-Item $exe.Source).VersionInfo.ProductVersion }
    }},
  @{ Vendor="Python"; Product="python"; VersionFunc={
      $exe = Get-Command python.exe -ErrorAction SilentlyContinue
      if ($exe) { (Get-Item $exe.Source).VersionInfo.ProductVersion }
    }},
  @{ Vendor="Node.js"; Product="node"; VersionFunc={
      $exe = Get-Command node.exe -ErrorAction SilentlyContinue
      if ($exe) { (Get-Item $exe.Source).VersionInfo.ProductVersion }
    }}
)

function Query-VulnersBatch($softList) {
  $body = @{ apiKey = $VulnersApiKey; software = $softList } | ConvertTo-Json -Depth 5
  return Invoke-RestMethod -Uri "https://vulners.com/api/v4/audit/software/" `
    -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
}

# === Collect software versions ===
$softwareList = @()
foreach ($p in $ProgramsToCheck) {
  $ver = & $p.VersionFunc
  if ($ver) {
    Write-Host "✓ Found $($p.Product) v$ver"
    $softwareList += @{
      vendor  = $p.Vendor
      product = $p.Product
      version = $ver
    }
  } else {
    Write-Warning "✗ $($p.Product) not found"
  }
}

if ($softwareList.Count -eq 0) {
  Write-Warning "No software found"
  return
}

Write-Host "`n📦 Sending to Vulners:"
$softwareList | ConvertTo-Json -Depth 3 | Write-Host

# === API Call ===
try {
  $resp = Query-VulnersBatch $softwareList
} catch {
  Write-Error "API call failed: $_"
  return
}

# === Parse Response ===
$Results = @()
foreach ($entry in $resp.result) {
  $Results += @{
    Product         = $entry.input.product
    Version         = $entry.input.version
    MatchedCPE      = $entry.matched_criteria
    Vulnerabilities = $entry.vulnerabilities
  }
}

$Results | ConvertTo-Json -Depth 5 | Out-File $OutputFile -Encoding UTF8
Write-Host "`n✅ Saved to $OutputFile"
