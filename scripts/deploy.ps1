# Links every addon folder in this repo (any top-level folder with a .toc) into
# the test client's AddOns folder as a junction, so edits are live after /reload.
# Safe to re-run: existing junctions are left alone; a real folder in the way is reported, not replaced.
param(
    [string]$AddOnsDir = "F:\Blizzard\World of Warcraft\_classic_beta_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $AddOnsDir)) { throw "AddOns folder not found: $AddOnsDir" }

Get-ChildItem -Path $repoRoot -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).toc") } |
    ForEach-Object {
        $link = Join-Path $AddOnsDir $_.Name
        $existing = Get-Item $link -ErrorAction SilentlyContinue
        if (-not $existing) {
            New-Item -ItemType Junction -Path $link -Target $_.FullName | Out-Null
            Write-Output "linked   $($_.Name)"
        } elseif ($existing.LinkType -eq "Junction" -and $existing.Target -contains $_.FullName) {
            Write-Output "ok       $($_.Name)"
        } else {
            Write-Warning "skipped  $($_.Name): $link exists and is not a junction to this repo"
        }
    }
