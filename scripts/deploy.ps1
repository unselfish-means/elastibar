# Pushes a test build: copies each addon into the test client's AddOns folder as <Addon>-Test,
# with its .toc renamed and "-Test" on its title. A CurseForge install of the release keeps the
# plain folder name, so both can be installed; enable one at a time in the game's AddOns list.
# The game names saved variables after the folder, so the test build's data is separate too.
# Copies rather than links, so re-run this to test new edits, then /reload (restart for a new file).
param(
    [string]$AddOnsDir = "F:\Blizzard\World of Warcraft\_forever_\Interface\AddOns",
    [string[]]$Addons = @("Elastibar")
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $AddOnsDir)) { throw "AddOns folder not found: $AddOnsDir" }

foreach ($addon in $Addons) {
    $source = Join-Path $repoRoot $addon
    if (-not (Test-Path (Join-Path $source "$addon.toc"))) { throw "No $addon.toc in $source" }
    $testName = "$addon-Test"
    $dest = Join-Path $AddOnsDir $testName

    # Mirroring through a link would overwrite the link's target.
    $existing = Get-Item $dest -ErrorAction SilentlyContinue
    if ($existing -and $existing.LinkType) { throw "$dest is a link. Remove it, then deploy again." }

    robocopy $source $dest /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $addon (exit code $LASTEXITCODE)" }
    $global:LASTEXITCODE = 0 # 0-7 are success

    $toc = Join-Path $dest "$testName.toc"
    Move-Item (Join-Path $dest "$addon.toc") $toc -Force
    $text = [IO.File]::ReadAllText($toc) -replace '(?m)^(## Title(?:-\w+)?:[ \t]*)(.+?)(\r?)$', '${1}${2}-Test${3}'
    [IO.File]::WriteAllText($toc, $text)
    Write-Output "deployed $testName -> $dest"
}
