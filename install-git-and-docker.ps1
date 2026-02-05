# ===============================
# Smart Git + Docker Installer
# ===============================

$ErrorActionPreference = "Stop"

function Is-Installed-Winget {
    param ($Id)
    winget list --id $Id --exact 2>$null | Select-String $Id
}

function Get-Version {
    param ($Command)
    try {
        (& $Command) -replace '[^\d\.]'
    } catch {
        return $null
    }
}

function Ask-YesNo {
    param ($Message)
    $r = Read-Host "$Message (Y/N)"
    return $r -match '^(Y|y)$'
}

Write-Host "`n=== Checking installed packages ===`n"

# ---- Git ----
$gitInstalled = Is-Installed-Winget "Git.Git"
$gitVersion = $null

if ($gitInstalled) {
    $gitVersion = Get-Version "git --version"
    Write-Host "✔ Git detected: $gitVersion"
} else {
    Write-Host "✘ Git not installed"
}

# ---- Docker ----
$dockerInstalled = Is-Installed-Winget "Docker.DockerDesktop"
$dockerVersion = $null

if ($dockerInstalled) {
    try {
        $dockerVersion = (docker version --format '{{.Server.Version}}')
    } catch {}
    Write-Host "✔ Docker Desktop detected: $dockerVersion"
} else {
    Write-Host "✘ Docker Desktop not installed"
}

Write-Host ""

# ===============================
# Installation phase
# ===============================

if (-not $gitInstalled) {
    Write-Host "Installing Git (latest, defaults)..."
    winget install -e --id Git.Git `
        --accept-package-agreements `
        --accept-source-agreements `
        --silent
}

if (-not $dockerInstalled) {
    Write-Host "Installing Docker Desktop (latest, defaults)..."
    winget install -e --id Docker.DockerDesktop `
        --accept-package-agreements `
        --accept-source-agreements `
        --silent
}

# ===============================
# IDE detection
# ===============================

Write-Host "`n=== IDE Detection ==="

$editors = @()

if (Get-Command code -ErrorAction SilentlyContinue) {
    $editors += "VS Code"
}
if (Test-Path "C:\Program Files\Notepad++\notepad++.exe") {
    $editors += "Notepad++"
}
if (Test-Path "C:\Program Files\JetBrains") {
    $editors += "PyCharm"
}

if ($editors.Count -gt 0) {
    Write-Host "Detected editors: $($editors -join ', ')"

    if (Ask-YesNo "Do you want to change Git default editor from vim?") {

        Write-Host "Choose editor:"
        $editors | ForEach-Object { Write-Host " - $_" }
        $choice = Read-Host "Type editor name"

        switch ($choice) {
            "VS Code"     { git config --global core.editor "code --wait" }
            "Notepad++"  { git config --global core.editor "notepad++" }
            "PyCharm"    { git config --global core.editor "pycharm" }
            default      { Write-Host "Unknown editor, skipping." }
        }

        Write-Host "✔ Git editor updated"
    }
} else {
    Write-Host "No supported IDEs detected"
}

# ===============================
# Upgrade check
# ===============================

Write-Host "`n=== Upgrade Check ==="

if ($gitInstalled) {
    if (Ask-YesNo "Check and upgrade Git if newer version exists?") {
        winget upgrade --id Git.Git `
            --accept-package-agreements `
            --accept-source-agreements `
            --silent
    }
}

if ($dockerInstalled) {
    if (Ask-YesNo "Check and upgrade Docker Desktop if newer version exists?") {
        winget upgrade --id Docker.DockerDesktop `
            --accept-package-agreements `
            --accept-source-agreements `
            --silent
    }
}

Write-Host "`n✔ Done."