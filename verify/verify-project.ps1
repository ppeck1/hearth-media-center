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
$inputDefaultsPath = Join-Path $launcherRoot "config\input-profiles-defaults.json"
$inputPolicyPath = Join-Path $launcherRoot "config\app-input-policy.json"
$inputAdaptersPath = Join-Path $launcherRoot "config\input-adapters.json"
$menu = Get-Content -Raw -Path $menuPath | ConvertFrom-Json
$registry = Get-Content -Raw -Path $registryPath | ConvertFrom-Json
$inputDefaults = Get-Content -Raw -Path $inputDefaultsPath | ConvertFrom-Json
$inputPolicy = Get-Content -Raw -Path $inputPolicyPath | ConvertFrom-Json
$inputAdapters = Get-Content -Raw -Path $inputAdaptersPath | ConvertFrom-Json

Assert-ProjectCondition ($menu.schema_version -eq 2) "menu.json schema_version must be 2."
Assert-ProjectCondition ($menu.items -is [array]) "menu.json items must be an array."
Assert-ProjectCondition ($menu.title -eq "Home") "menu.json must not restore the legacy greeting."
Assert-ProjectCondition ($registry.schema_version -eq 1) "system-registry.json schema_version must be 1."
Assert-ProjectCondition ($registry.families -is [array]) "system-registry.json families must be an array."
Assert-ProjectCondition ($registry.systems -is [array]) "system-registry.json systems must be an array."
Assert-ProjectCondition ($registry.systems.Count -eq 27) "Expected 27 configured systems."
Assert-ProjectCondition ($inputDefaults.schema_version -eq 2) "input-profiles-defaults.json schema_version must be 2."
Assert-ProjectCondition ($inputDefaults.profiles.Count -eq 2) "Expected PS5 and standard remote input profiles."
Assert-ProjectCondition (($inputDefaults.profiles.id -contains "ps5") -and ($inputDefaults.profiles.id -contains "standard_remote")) "Required input profiles are missing."
Assert-ProjectCondition ($inputDefaults.device_assignments -is [array]) "Input device assignments must use structured selectors."
Assert-ProjectCondition ($inputPolicy.schema_version -eq 1) "app-input-policy.json schema_version must be 1."
Assert-ProjectCondition ($inputPolicy.adapters.steam -eq "native") "Steam must remain native controller passthrough."
Assert-ProjectCondition ($inputPolicy.adapters.retroarch -eq "native") "RetroArch must remain native controller passthrough."
Assert-ProjectCondition ($inputPolicy.destinations.netflix -eq "browser_streaming") "Netflix must use the browser streaming policy."
Assert-ProjectCondition ($inputPolicy.destinations.prime -eq "browser_streaming") "Prime Video must use its menu destination id without changing its Chrome profile path."
Assert-ProjectCondition ($inputPolicy.destinations.plex -eq "plex") "Plex must use the translated Plex policy."
Assert-ProjectCondition ($inputAdapters.schema_version -eq 1) "input-adapters.json schema_version must be 1."
Assert-ProjectCondition ($inputAdapters.adapters.keyboard_navigation.outputs.home -eq "bridge:return_to_hearth") "The bridge Home action must return safely to Hearth."

$requiredActions = @("navigate_up", "navigate_down", "navigate_left", "navigate_right", "select", "back", "home", "menu", "play_pause", "page_left", "page_right")
foreach ($profile in $inputDefaults.profiles) {
    foreach ($action in $requiredActions) {
        Assert-ProjectCondition ($null -ne $profile.bindings.$action) "Input profile '$($profile.id)' is missing '$action'."
        foreach ($binding in $profile.bindings.$action) {
            Assert-ProjectCondition ($binding.control -match "^(key|gamepad_button|gamepad_axis):") "Invalid input binding '$($binding.control)'."
        }
    }
}

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

$inputModules = @(
    "scripts\input\input_actions.gd",
    "scripts\input\input_event_codec.gd",
    "scripts\input\input_profile_store.gd",
    "scripts\input\input_manager.gd",
    "scripts\settings\input_settings.gd",
    "scenes\settings\input_settings.tscn",
    "tests\input_smoke.gd"
)
foreach ($module in $inputModules) {
    Assert-ProjectCondition (Test-Path -LiteralPath (Join-Path $launcherRoot $module) -PathType Leaf) "Missing input module: $module"
}

$bridgeModules = @(
    "input_bridge\hearth_input_bridge\config.py",
    "input_bridge\hearth_input_bridge\mapper.py",
    "input_bridge\hearth_input_bridge\cli.py",
    "input_bridge\hearth_input_bridge\evdev_source.py",
    "input_bridge\hearth_input_bridge\uinput_sink.py",
    "input_bridge\hearth_input_bridge\process_runner.py",
    "input_bridge\tests\test_bridge.py",
    "input_bridge\tests\test_linux_runtime.py",
    "launchers\run-with-input-bridge.sh"
)
foreach ($module in $bridgeModules) {
    Assert-ProjectCondition (Test-Path -LiteralPath (Join-Path $projectRoot $module) -PathType Leaf) "Missing input bridge module: $module"
}

$browserLauncher = Get-Content -Raw -Path (Join-Path $projectRoot "launchers\browser-service.sh")
$primeLauncher = Get-Content -Raw -Path (Join-Path $projectRoot "launchers\prime-video.sh")
$plexLauncher = Get-Content -Raw -Path (Join-Path $projectRoot "launchers\plex-htpc.sh")
Assert-ProjectCondition ($browserLauncher.Contains("run-with-input-bridge.sh")) "Browser services do not start the input bridge."
Assert-ProjectCondition ($primeLauncher.Contains("prime-video https://www.amazon.com/gp/video/storefront prime")) "Prime Video policy id must not replace its existing browser profile path."
Assert-ProjectCondition ($plexLauncher.Contains("run-with-input-bridge.sh plex")) "Plex does not start the input bridge."
Assert-ProjectCondition (Test-Path -LiteralPath (Join-Path $projectRoot "deploy\fedora\69-hearth-uinput.rules") -PathType Leaf) "Missing Fedora uinput rule."
Assert-ProjectCondition (Test-Path -LiteralPath (Join-Path $projectRoot "deploy\fedora\install-input-access.sh") -PathType Leaf) "Missing Fedora input setup script."
$uinputRule = Get-Content -Raw -Path (Join-Path $projectRoot "deploy\fedora\69-hearth-uinput.rules")
Assert-ProjectCondition ($uinputRule.Contains('TAG+="uaccess"')) "Fedora uinput rule must use active-user access."
Assert-ProjectCondition (-not ($uinputRule -match 'MODE="?0?666|GROUP="input"')) "Fedora uinput rule grants unsafe broad access."
Assert-ProjectCondition (Test-Path -LiteralPath (Join-Path $projectRoot "deploy\fedora\hearth-uinput.conf") -PathType Leaf) "Missing persistent uinput module configuration."

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

Write-Output "Static verification passed (PowerShell): $($configuredArt.Count) artwork references, 27 systems, 2 input profiles, and $($panelFiles.Count) vector service panels."
