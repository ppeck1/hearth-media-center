$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$launcherRoot = Join-Path $projectRoot "launcher"

function Assert-ProjectCondition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-ConfiguredArtPath {
    param([Parameter(Mandatory = $true)]$Value)

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string] -and $Value -isnot [pscustomobject]) {
        foreach ($child in $Value) {
            Get-ConfiguredArtPath -Value $child
        }
        return
    }

    if ($Value -is [pscustomobject]) {
        foreach ($property in $Value.PSObject.Properties) {
            if ($property.Name -eq "art" -and $property.Value -is [string]) {
                $property.Value
            }
            Get-ConfiguredArtPath -Value $property.Value
        }
    }
}

$menuPath = Join-Path $launcherRoot "config\menu.json"
$registryPath = Join-Path $launcherRoot "config\system-registry.json"
$menu = Get-Content -Raw -Path $menuPath | ConvertFrom-Json
$registry = Get-Content -Raw -Path $registryPath | ConvertFrom-Json

Assert-ProjectCondition ($menu.schema_version -eq 2) "menu.json schema_version must be 2."
Assert-ProjectCondition ($menu.items -is [array]) "menu.json items must be an array."
Assert-ProjectCondition ($menu.title -eq "Home") "menu.json must not restore the legacy greeting."
Assert-ProjectCondition ($registry.schema_version -eq 1) "system-registry.json schema_version must be 1."
Assert-ProjectCondition ($registry.families -is [array]) "system-registry.json families must be an array."
Assert-ProjectCondition ($registry.systems -is [array]) "system-registry.json systems must be an array."
Assert-ProjectCondition ($registry.systems.Count -eq 27) "Expected 27 configured systems."

$configuredArt = @(
    Get-ConfiguredArtPath -Value $menu
    Get-ConfiguredArtPath -Value $registry
)
foreach ($artPath in $configuredArt) {
    Assert-ProjectCondition ($artPath.StartsWith("res://")) "Artwork path is not a res:// path: $artPath"
    $relativePath = $artPath.Substring(6).Replace("/", "\")
    Assert-ProjectCondition (Test-Path -LiteralPath (Join-Path $launcherRoot $relativePath) -PathType Leaf) "Missing artwork: $artPath"
}

$requiredBackground = Join-Path $launcherRoot "assets\backgrounds\arcade-living-room-v4.png"
Assert-ProjectCondition (Test-Path -LiteralPath $requiredBackground -PathType Leaf) "Missing optimized home background."

$panelFiles = Get-ChildItem -Path (Join-Path $launcherRoot "assets\logos") -Filter "*-panel-v1.svg" -File
foreach ($panel in $panelFiles) {
    $panelText = Get-Content -Raw -Path $panel.FullName
    Assert-ProjectCondition (-not ($panelText -match "<image|data:image")) "Raster content is embedded in $($panel.Name)."
}

$mainScript = Get-Content -Raw -Path (Join-Path $launcherRoot "scripts\main.gd")
Assert-ProjectCondition ($mainScript.Contains("res://assets/backgrounds/arcade-living-room-v4.png")) "main.gd does not use the corrected home background."
Assert-ProjectCondition ($mainScript.Contains("res://assets/backgrounds/console-gallery-v1.png")) "main.gd does not use the console gallery background."
Assert-ProjectCondition ($mainScript.Contains("Time.get_time_dict_from_system()")) "Home heading does not use the local system clock."
Assert-ProjectCondition (-not $mainScript.Contains("name_label")) "Carousel item-name captions should not be rendered."
Assert-ProjectCondition (-not $mainScript.Contains("var marquee")) "Legacy yellow home metadata should not be rendered."
Assert-ProjectCondition (-not $mainScript.Contains("var breadcrumb")) "Legacy yellow breadcrumb should not be rendered."
Assert-ProjectCondition (-not $mainScript.Contains("Good evening")) "Legacy greeting remains in main.gd."

$privacyPatterns = @(
    "C:\\Users\\",
    "BEGIN [A-Z ]*PRIVATE KEY",
    "sk-[A-Za-z0-9_-]{20,}"
)
$privacyMatches = & rg -n --hidden -g "!tmp/**" -g "!.git/**" ($privacyPatterns -join "|") $launcherRoot 2>$null
if ($LASTEXITCODE -eq 0) {
    throw "Privacy marker found:`n$privacyMatches"
}
if ($LASTEXITCODE -gt 1) {
    throw "Privacy scan failed."
}

Write-Output "Static verification passed (PowerShell): $($configuredArt.Count) artwork references, 27 systems, and $($panelFiles.Count) vector service panels."
