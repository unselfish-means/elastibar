# Elastibar

A WoW: Forever addon (toc `16001`, Retail-style API) that adds extra action bars you can resize in
Edit Mode and show on your own visibility rules.

[README.md](README.md) is the player-facing description, and it's also the description pasted into
CurseForge. It lists only what's on `main`. Keep development notes out of it; they belong in the
files below.

## Where things are

- `Elastibar/` is the addon folder. The `.toc` lists every file in load order, so a new file must be
  added there or it never loads.
- `ElastibarProbe/` is a dev-only addon that records what the client supports. It never ships
  (`.pkgmeta` ignores it).
- [docs/README.md](docs/README.md) is the design: why Elastibar exists, what's out of v1, and the
  per-area specs in `docs/specs/`, with each requirement tagged Decided, Proposed, or Open.
- [docs/platform.md](docs/platform.md) has the WoW: Forever API facts, combat lockdown rules, and the
  [development](docs/platform.md#development) workflow: deploying with `scripts/deploy.ps1`, running
  the `tests/` suites, using the probe, and the GitHub account setup.

## Releasing

A pushed tag runs [.github/workflows/release.yml](.github/workflows/release.yml), which packages the
addon with the BigWigs packager (following [.pkgmeta](.pkgmeta)) and uploads it to CurseForge. The
setup is the shared one in the `curseforge-packaging` runbook in `wow-addons-skill`. CurseForge uploads
need `## X-Curse-Project-ID` in `Elastibar/Elastibar.toc`, which isn't there yet.

When a release changes what players see, update [README.md](README.md) and paste it into the
CurseForge project's description.
