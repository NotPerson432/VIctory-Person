# Starts the title with the settings this fork is played with (README.md, "How to run it").
#   scripts\play.ps1 -Exe <path of your own copy's executable>
# -Safe         without the newer, faster ways (the first thing to try when something is wrong)
# -RayTracing   the title's own ray-traced indirect light: lit interiors, about a third slower
# -Fsr4K        PC FidelityFX 4.1.2 at 3840x2160 (quality, balanced or performance)
# -Build        target\diag (the default, the build all measurements are of) or target\release
# -More         other settings: -More @{VICTORY_PANEL='1'}
# Frame rate (README.md, "Frame rate"):
# -Fast         -Ports and -SeriesS together: the fastest measured setup (about 45 ms against 57-75)
# -Ports        renderer patches 1, 2, 5, 6 and 7 (VICTORY_PORT_...), each measured faster, still being tested
# -SeriesS      the Series S profile: 1080p output, about 5 ms a frame less, a softer picture
# -Fps          the frame rate the title may go up to: 30 (the title's own), 60, 120, 0 for no limit;
#               below what the PC reaches (say 20) for even frames
# -Tearing      presents not held to the display's rate: for G-SYNC/FreeSync displays and -Fps 0
# -Warm         makes the pipelines earlier runs drew with before starting, so they do not stutter
#               (runs with -Warm write them down; it goes on where it was stopped)
# Run it from a normal window, not as administrator: the driver then keeps its shader cache elsewhere.
param(
    [Parameter(Mandatory)][string]$Exe,
    [switch]$Safe,
    [switch]$RayTracing,
    [ValidateSet('quality', 'balanced', 'performance')][string]$Fsr4K,
    [ValidateSet('diag', 'release')][string]$Build = 'diag',
    [switch]$Fast,
    [switch]$Ports,
    [switch]$SeriesS,
    [ValidateRange(0, 1000)][int]$Fps = -1,
    [switch]$Tearing,
    [switch]$Warm,
    [hashtable]$More = @{}
)
if ($Fast) { $Ports = $true; if (-not $Fsr4K) { $SeriesS = $true } }
if ($Safe -and $Ports) { Write-Host "-Safe leaves the newer ways out; -Ports and -Fast put them in. Pick one."; exit 1 }
if ($SeriesS -and $Fsr4K) { Write-Host "-Fsr4K needs the Series X profile; leave -SeriesS out."; exit 1 }
$settings = @{
    VICTORY_TEXTURE_NO_WAIT = '1'; VICTORY_RELAY = '2'; VICTORY_WIDE_BACK = '1'; VICTORY_CARD_REHASH_RUNS = '1'
    VICTORY_JOIN_COPIES = '1'; VICTORY_INDIRECT_WINDOW = '1'; VICTORY_RELAY_COPY = '1'; VICTORY_CARD_STEPS = '2'
    VICTORY_INDIRECT_BATCH = '2'; VICTORY_MAP_THREADS = '1'; VICTORY_TITLE_PRIORITIES = '0'; VICTORY_CARD_AWAKE = '1'
    VICTORY_SHOW_AFTER = '1'; VICTORY_AMBIENT = '0.8'; VICTORY_D3D12_DRED = 'light'
}
if ($Safe) {
    $settings.VICTORY_UNDER_WIDE = '0'; $settings.VICTORY_LAND_ECHO = '0'
} else {
    $settings.VICTORY_THIN = '1'; $settings.VICTORY_JOIN_PARTS = '8'; $settings.VICTORY_UPLOAD_AHEAD = '1'
}
if ($RayTracing) { $settings.VICTORY_BVH_BUILDER = '1' }
if ($Fsr4K) { $settings.VICTORY_FSR_4K = $Fsr4K.ToLowerInvariant() }
if ($Ports) {
    foreach ($port in 'CONSTANTS', 'DESCRIPTORS', 'CBV', 'GUARD', 'JOURNAL') { $settings["VICTORY_PORT_$port"] = '1' }
}
if ($Fps -ge 0) {
    # Milliseconds a frame, with a point whatever the system's language (0: no limit).
    $ms = if ($Fps -eq 0) { 0.0 } else { 1000.0 / $Fps }
    $settings.VICTORY_FRAME_INTERVAL_MS = $ms.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
}
if ($Tearing) { $settings.VICTORY_TEARING = '1' }
if ($Warm) { $settings.VICTORY_PIPELINE_BOOK = '1' }
$console = if ($SeriesS) { 'series-s' } else { 'series-x' }
foreach ($k in $More.Keys) { $settings[$k] = $More[$k] }

$victory = Join-Path $PSScriptRoot "..\target\$Build\victory.exe"
if (-not (Test-Path $victory)) { Write-Host "No $victory. Build it first (README.md)."; exit 1 }
if (-not (Test-Path $Exe)) { Write-Host "No $Exe."; exit 1 }
# (Other settings left over in this window go; where your files are stays.)
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR', 'VICTORY_FIDELITYFX_DIR'
$inherited = @(Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths })
foreach ($entry in $inherited) { Remove-Item "Env:$($entry.Name)" }
foreach ($k in $settings.Keys) { Set-Item "Env:$k" $settings[$k] }
$discarded = $inherited | Where-Object {
    $_.Name -notin $More.Keys -and -not $_.Value.Equals([Environment]::GetEnvironmentVariable($_.Name))
} | Sort-Object Name
if ($discarded) {
    Write-Host "Discarded inherited values for $($discarded.Name -join ', '). Use -More to pass them explicitly."
}
$Exe = (Resolve-Path $Exe).Path
Push-Location (Join-Path $PSScriptRoot '..')   # victory.toml is looked for here
try {
    if ($Warm) {
        # With the same settings as the run: some of them change the translated shaders.
        Write-Host "Making the pipelines earlier runs drew with (Ctrl+C ends it and the run; the next -Warm goes on from there)."
        & $victory warm --used
    }
    & $victory run $Exe --execute --console $console
} finally { Pop-Location }
