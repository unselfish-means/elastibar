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
setup is the shared one in the `curseforge-packaging` runbook in `wow-addons-skill`. The CurseForge
project ID is `## X-Curse-Project-ID: 1730569` in `Elastibar/Elastibar.toc`.

### Elastibar is in beta

Until the owner says Elastibar is out of beta, **every tag must contain `beta`**, for example
`1.0.1-beta1`, `1.0.1-beta2`, `1.1.0-beta1`. The packager decides the CurseForge release type only
from the tag name: a tag with `beta` uploads as a **Beta** file, and a tag without it, such as `1.0.1`,
uploads as a full **Release** to everyone. A pushed tag can't be cleanly taken back, so check the name
before pushing.

- `## Version` in the `.toc` is the same string as the tag, so `/reload` shows which beta is
  installed. Bump it in the PR that changes behavior.
- To release, from an up-to-date `main` whose `.toc` already has the new version:

  ```powershell
  git tag -m "Elastibar 1.0.1-beta1" 1.0.1-beta1 origin/main
  git push origin refs/tags/1.0.1-beta1
  ```

  The message makes the tag annotated, which the packager needs. Then check the run with
  `gh run list --workflow release.yml` and the file on CurseForge (type **Beta**, game version
  WoW: Forever). Release notes are reviewed by the owner before a tag is pushed, as in Reclaim.
- 1.0.0 was uploaded to CurseForge by hand to create the project, and has no git tag. The first tag's
  changelog therefore lists every commit since the repo began; replace it on CurseForge with the
  release notes.

When a release changes what players see, update [README.md](README.md) and paste it into the
CurseForge project's description.

## CurseForge project

| Field | Value |
|---|---|
| Project ID | 1730569 |
| Description | Paste [README.md](README.md) (choose Markdown in the editor) |
| Game version | WoW: Forever (Classic Plus), toc `16001` |
| Release type | Beta, until the owner says otherwise (see above) |
