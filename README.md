# SkyCraft Build Dependencies

Centralized backup and recovery metadata for the SkyCraft Minecraft 1.7.10 build toolchain.

## Purpose

This repository preserves the information and scripts required to reproduce legacy mod builds even if old Maven repositories, GitHub release assets, or Gradle plugin endpoints disappear.

It intentionally does **not** store a full Gradle cache directly in Git. Large binary snapshots should be kept as release assets or external archives, while this repository stores manifests, hashes, source URLs, and recovery scripts.

## Current baseline

- Gradle: `8.5`
- RetroFuturaGradle: `1.4.2`
- Minecraft: `1.7.10`
- Forge: `10.13.4.1614`
- First validated consumer: `ae2stuff-0.5.1.16-gtnh`

## Repository layout

- `manifests/` — pinned versions, canonical source URLs, checksums and notes.
- `scripts/` — backup, restore and offline verification helpers.
- `snapshots/` — metadata describing archived dependency/cache snapshots.

## Recommended workflow

1. Build CLIENT and SERVER successfully online.
2. Stop Gradle/IDE build processes.
3. Create a full dependency-cache snapshot with `scripts/backup-gradle-environment.ps1`.
4. Store the generated archive outside Git or as a release asset.
5. Record its SHA-256 and location under `snapshots/`.
6. Restore on a clean machine and verify with `--offline`.

## Important

A single `retrofuturagradle-1.4.2.jar` is not enough for a reproducible build. The plugin marker, POM/module metadata, transitive plugin dependencies, Forge/Minecraft artifacts, mappings, Java toolchains, and project cache state can also be required.

## AE2 Stuff build and release from Windows

Use the scripts in this repository; do not copy them into each mod repository.

~~~powershell
cd C:\PROJECT\SkyCraft-Build-Dependencies
git pull
.\scripts\backup-gradle-environment.ps1 `
  -SourceProject "C:\PROJECT\ae2stuff-0.5.1.16-gtnh" `
  -Destination "D:\SKYCRAFT-BUILD-DEPS\ae2stuff-0.5.1.16-gtnh" `
  -GradleHome "C:\GradleCache"
~~~

To build and publish both JARs after installing GitHub CLI and running
`gh auth login`:

~~~powershell
.\scripts\release-ae2stuff.ps1 -SourceProject "C:\PROJECT\ae2stuff-0.5.1.16-gtnh"
~~~

The release script requires both `CLIENT/build/libs/ae2stuff-0.5.1.16-client.jar`
and `SERVER/build/libs/ae2stuff-0.5.1.16-server.jar`, checks their ZIP
structure, and publishes SHA-256 files alongside them. A failed build
prevents publication.
