param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

# 1. Reconstruct and Split
# We join all args and split by double-quotes to catch "Path1""Path2" style input
$raw = $Args -join " "
$allPaths = $raw -split '"' | Where-Object { $_ -match "\S" }

# 2. Find "to" and separate sources
$toIdx = $allPaths.IndexOf("to")
if ($toIdx -eq -1) {
    $sources = $allPaths
    $dest = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop")
} else {
    $sources = $allPaths[0..($toIdx - 1)]
    $dest = $allPaths[$toIdx + 1]
}

if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

# 3. Process Folders
foreach ($p in $sources) {
    $p = $p.Trim()
    if (!(Test-Path $p)) { Write-Host "Path not found: $p"; continue }

    $exes = Get-ChildItem -Path $p -Filter *.exe
    if ($exes.Count -eq 0) { Write-Host "No .exe in: $p"; continue }

    $target = $exes[0]
    if ($exes.Count -gt 1) {
        Write-Host "`nMultiple EXEs in $(Split-Path $p -Leaf):"
        for ($i=0; $i -lt $exes.Count; $i++) { Write-Host ("{0}: {1}" -f $i, $exes[$i].Name) }
        $choice = Read-Host "Select index for $($exes[0].BaseName)"
        if ($choice -ne "") { $target = $exes[[int]$choice] }
    }

    $lnkPath = Join-Path $dest "$($(Split-Path $p -Leaf)).lnk"
    if (Test-Path $lnkPath) { Write-Host "Skipped (exists): $(Split-Path $lnkPath -Leaf)"; continue }

    $ws = New-Object -ComObject WScript.Shell
    $s = $ws.CreateShortcut($lnkPath)
    $s.TargetPath = $target.FullName
    $s.WorkingDirectory = $p
    $s.Save()
    Write-Host "Created: $(Split-Path $lnkPath -Leaf)"
}