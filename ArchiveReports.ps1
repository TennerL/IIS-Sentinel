$reportFolder = Join-Path -Path $PSScriptRoot -ChildPath "\reports\"

$archiveFolder = Join-Path -Path $PSScriptRoot -ChildPath "\archive\$(Get-Date -Format yyyy-MM-dd)"

if(-not(Test-Path -Path $archiveFolder)){
    New-Item -Path $archiveFolder -ItemType directory 
}

Move-Item -Path $reportFolder\* -Destination $archiveFolder
