param(
    [string]$Action,
    [string]$Name,
    [string]$Path
)

$ShortcutFile = Join-Path $PSScriptRoot "shortcuts.txt"

# Create file if missing
if (-not (Test-Path $ShortcutFile)) {
    New-Item -ItemType File -Path $ShortcutFile | Out-Null
}

# -------------------------
# Load shortcuts
# -------------------------
$Shortcuts = @{}

Get-Content $ShortcutFile | ForEach-Object {
    if ($_ -match "^\s*([^=]+)\s*=\s*(.+)\s*$") {
        $Shortcuts[$matches[1]] = $matches[2]
    }
}

# -------------------------
# Save shortcuts
# -------------------------
function Save-Shortcuts {
    $Shortcuts.GetEnumerator() |
        Sort-Object Name |
        ForEach-Object { "$($_.Name)=$($_.Value)" } |
        Set-Content $ShortcutFile
}

# -------------------------
# Commands
# -------------------------
switch ($Action) {

    "add" {
        if (-not $Name -or -not $Path) {
            Write-Host "Usage: open add <name> <path>"
            exit 1
        }

        $Shortcuts[$Name] = $Path
        Save-Shortcuts
        Write-Host "Added: $Name -> $Path"
    }

    "remove" {
        if (-not $Name) {
            Write-Host "Usage: open remove <name>"
            exit 1
        }

        if ($Shortcuts.Remove($Name)) {
            Save-Shortcuts
            Write-Host "Removed: $Name"
        } else {
            Write-Host "Shortcut not found: $Name"
        }
    }

    "list" {
        if ($Shortcuts.Count -eq 0) {
            Write-Host "No shortcuts defined."
            exit
        }

        $Shortcuts.GetEnumerator() |
            Sort-Object Name |
            ForEach-Object {
                "{0,-12} {1}" -f $_.Name, $_.Value
            }
    }

    default {
        if (-not $Action) {
            Write-Host "Usage:"
            Write-Host "  open <name>"
            Write-Host "  open add <name> <path>"
            Write-Host "  open remove <name>"
            Write-Host "  open list"
            exit
        }

        if (-not $Shortcuts.ContainsKey($Action)) {
            Write-Host "Unknown shortcut: $Action"
            Write-Host "Use: open list"
            exit 1
        }

        $Target = $Shortcuts[$Action]

        if (Test-Path $Target) {
            Invoke-Item $Target
        } else {
            Start-Process $Target
        }
    }
}
