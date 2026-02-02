param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Args
)

$7zipPath = "C:\Program Files\7-Zip\7z.exe"
if (-not (Test-Path $7zipPath)) {
    Write-Error "7-Zip not found at $7zipPath"
    exit 1
}

# Find "to" keyword index
$toIdx = -1
for ($i = 0; $i -lt $Args.Count; $i++) {
    if ($Args[$i] -eq "to") {
        $toIdx = $i
        break
    }
}

if ($toIdx -eq -1) {
    Write-Error "Missing 'to' keyword"
    exit 1
}

# Get source part
$sourceString = $Args[0..($toIdx - 1)] -join " "

# Split by single quote that appears between paths
$sourcePaths = $sourceString -split '"' | Where-Object { $_ -ne "" }

# Get target folder
$TargetFolder = ($Args[($toIdx + 1)..($Args.Count - 1)] -join " ").Trim('"')

Write-Host "Found $($sourcePaths.Count) archives to extract"
Write-Host "Target: $TargetFolder`n"

if (-not (Test-Path $TargetFolder)) {
    New-Item -ItemType Directory -Path $TargetFolder | Out-Null
}

foreach ($src in $sourcePaths) {
    if (-not (Test-Path $src)) {
        Write-Warning "Skipping: $src (not found)"
        continue
    }
    
    $item = Get-Item $src
    $destFolder = Join-Path $TargetFolder $item.BaseName
    
    if ($item.PSIsContainer) {
        Write-Host "Skipping: $($item.Name) (already a folder)"
        continue
    }
    
    # Check for zip/rar extension or Windows compressed attribute
    if ($item.Extension -match '\.(zip|rar)$' -or $item.Attributes -match 'Compressed') {
        New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
        Write-Host "Extracting: $($item.Name) -> $destFolder"
        & $7zipPath x "$src" -o"$destFolder" -y | Out-Null
    } else {
        Write-Warning "Skipping: $($item.Name) (not zip/rar)"
    }
}

Write-Host "`nDone!"