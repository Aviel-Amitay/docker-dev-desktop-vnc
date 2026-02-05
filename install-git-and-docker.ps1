# ===============================
# Smart Git + Docker + IDE Installer / Upgrader
# ===============================

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] $Message"
}

function Ask-YesNo {
    param([string]$Message)
    $r = Read-Host "$Message (Y/N)"
    return $r -match '^(Y|y)$'
}

function Invoke-Winget {
    param(
        [Parameter(Mandatory)][string[]]$Args
    )
    # 🔑 KEY CHANGE: make winget non-interactive and avoid msstore hangs by default where possible
    & winget @Args --disable-interactivity --accept-source-agreements 2>&1 | Out-String
}

function Is-Installed-Winget {
    param([Parameter(Mandatory)][string]$Id)

    $out = Invoke-Winget -Args @("list", "--id", $Id, "--exact", "--source", "winget")
    return ($out -match [regex]::Escape($Id))
}

function Get-InstalledVersion-Winget {
    param([Parameter(Mandatory)][string]$Id)

    # winget list output is not super structured, but for --exact it typically includes a row with Version column.
    $out = Invoke-Winget -Args @("list", "--id", $Id, "--exact", "--source", "winget")
    $line = ($out -split "`r?`n") | Where-Object { $_ -match [regex]::Escape($Id) } | Select-Object -First 1
    if (-not $line) { return $null }

    # Try best-effort parse: split by 2+ spaces
    $parts = $line -split '\s{2,}' | Where-Object { $_ -ne "" }
    # Usually: Name | Id | Version | Available | Source
    # We'll search for a token that looks like a version: digits.digits...
    $ver = $parts | Where-Object { $_ -match '^\d+(\.\d+){1,}.*$' } | Select-Object -First 1
    return $ver
}

function Get-CommandVersion {
    param(
        [Parameter(Mandatory)][string]$Command,
        [string[]]$Args = @("--version")
    )
    try {
        $raw = & $Command @Args 2>$null
        if (-not $raw) { return $null }
        ($raw | Out-String).Trim()
    } catch {
        return $null
    }
}

function Has-UpgradeAvailable {
    param([Parameter(Mandatory)][string]$Id)

    $out = Invoke-Winget -Args @("upgrade", "--id", $Id, "--exact", "--source", "winget")
    # When no upgrade exists, winget typically says "No installed package found matching input criteria."
    # or "No applicable update found." depending on version.
    if ($out -match 'No (installed package found|applicable update found|available upgrade found)') { return $false }

    # If the ID appears in output table, assume upgrade is available
    return ($out -match [regex]::Escape($Id))
}

function Install-Or-Upgrade {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$DisplayName
    )

    if (Is-Installed-Winget $Id) {
        $installedVer = Get-InstalledVersion-Winget $Id
        Write-Host "$DisplayName is installed. winget version: $installedVer" -ForegroundColor Green

        if (Has-UpgradeAvailable $Id) {
            Write-Host '$DisplayName: update available.' -ForegroundColor Yellow
            if (Ask-YesNo "Do you want to upgrade $DisplayName now?") {
                Write-Log "Upgrading $DisplayName..."
                Invoke-Winget -Args @("upgrade", "--id", $Id, "--exact", "--source", "winget", "--accept-package-agreements") | Out-Null
                Write-Host "$DisplayName upgraded." -ForegroundColor Green
            } else {
                Write-Host "Skipped upgrade for $DisplayName."
            }
        } else {
            Write-Host "$DisplayName is up to date (no upgrade detected)." -ForegroundColor DarkGreen
        }

    } else {
        Write-Host "$DisplayName is not installed." -ForegroundColor Cyan
        if (Ask-YesNo "Install $DisplayName?") {
            Write-Log "Installing $DisplayName..."
            Invoke-Winget -Args @("install", "--id", $Id, "--exact", "--source", "winget", "--accept-package-agreements") | Out-Null
            Write-Host "$DisplayName installed." -ForegroundColor Green
        } else {
            Write-Host "Skipped install for $DisplayName."
        }
    }
}

function Detect-IDEs {
    # Common IDEs and their winget IDs (winget source)
    $ides = @(
        [pscustomobject]@{ Name="Visual Studio Code"; Id="Microsoft.VisualStudioCode"; Cmd="code"; CmdArgs=@("--version") },
        [pscustomobject]@{ Name="PyCharm Community";  Id="JetBrains.PyCharm.Community"; Cmd="pycharm64"; CmdArgs=@("--version") },
        [pscustomobject]@{ Name="PyCharm Professional"; Id="JetBrains.PyCharm"; Cmd="pycharm64"; CmdArgs=@("--version") },
        [pscustomobject]@{ Name="IntelliJ IDEA Community"; Id="JetBrains.IntelliJIDEA.Community"; Cmd="idea64"; CmdArgs=@("--version") },
        [pscustomobject]@{ Name="IntelliJ IDEA Ultimate";  Id="JetBrains.IntelliJIDEA"; Cmd="idea64"; CmdArgs=@("--version") },
        [pscustomobject]@{ Name="WebStorm"; Id="JetBrains.WebStorm"; Cmd="webstorm64"; CmdArgs=@("--version") },
        [pscustomobject]@{ Name="Rider"; Id="JetBrains.Rider"; Cmd="rider64"; CmdArgs=@("--version") }
    )

    $installed = @()
    foreach ($ide in $ides) {
        if (Is-Installed-Winget $ide.Id) {
            $ver = Get-InstalledVersion-Winget $ide.Id
            $installed += [pscustomobject]@{ Name=$ide.Name; Id=$ide.Id; Version=$ver }
        }
    }
    return $installed
}

# ===============================
# Main
# ===============================

Write-Host ""
Write-Host "This script checks Git/Docker/IDEs and installs/upgrades using winget." -ForegroundColor Cyan

if (-not (Ask-YesNo "Continue?")) {
    Write-Host "Aborted by user."
    exit 0
}

Write-Log "Initializing winget sources..."
Invoke-Winget -Args @("source", "update") | Out-Null

Write-Log "Checking Git and Docker..."

# ---- Git ----
Install-Or-Upgrade -Id "Git.Git" -DisplayName "Git"
# Print real git version if command exists
$gitCmdVer = Get-CommandVersion -Command "git" -Args @("--version")
if ($gitCmdVer) { Write-Host "Git runtime: $gitCmdVer" -ForegroundColor DarkGray }

# ---- Docker Desktop ----
Install-Or-Upgrade -Id "Docker.DockerDesktop" -DisplayName "Docker Desktop"
# Print real docker version if command exists
$dockerCmdVer = Get-CommandVersion -Command "docker" -Args @("--version")
if ($dockerCmdVer) { Write-Host "Docker runtime: $dockerCmdVer" -ForegroundColor DarkGray }

Write-Host ""
Write-Log "Detecting IDEs..."

$installedIDEs = Detect-IDEs
if ($installedIDEs.Count -gt 0) {
    Write-Host "Detected installed IDE(s):" -ForegroundColor Green
    $installedIDEs | Format-Table Name, Version -AutoSize
} else {
    Write-Host "No common IDEs detected via winget." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "IDE preference check:" -ForegroundColor Cyan

# Choose preferred IDE prompt (simple + practical)
$preferred = Read-Host "Preferred IDE? (vscode / pycharm-community / pycharm-pro / none)"
switch ($preferred.ToLower()) {
    "vscode" {
        Install-Or-Upgrade -Id "Microsoft.VisualStudioCode" -DisplayName "Visual Studio Code"
    }
    "pycharm-community" {
        Install-Or-Upgrade -Id "JetBrains.PyCharm.Community" -DisplayName "PyCharm Community"
    }
    "pycharm-pro" {
        Install-Or-Upgrade -Id "JetBrains.PyCharm" -DisplayName "PyCharm Professional"
    }
    "none" {
        Write-Host "Skipping IDE changes."
    }
    default {
        Write-Host "Unknown option, skipping IDE changes."
    }
}

Write-Host ""
Write-Host "Done" -ForegroundColor Green

Write-Host ""
Write-Host "Installation complete succssfully" -ForegroundColor Green