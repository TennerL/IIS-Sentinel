param (
[string]$websiteNr = ""
)


$folders = @("nmap", "iis", "system")
foreach ($folder in $folders) {
    
    #$path = "C:\Users\administrator.SDNORD\Desktop\Sicherheit\reports\$folder"
    $path = Join-Path -Path $PSScriptRoot -ChildPath "reports\$($websiteNr)\$folder"


    $files = Get-ChildItem -Path $path -Filter *.json | Sort-Object LastWriteTime | Select-Object -ExpandProperty Name
    $files | ConvertTo-Json | Set-Content -Path "$path\index.json" -Encoding UTF8
}
