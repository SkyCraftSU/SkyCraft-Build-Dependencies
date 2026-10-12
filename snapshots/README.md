# Dependency snapshots

Do not commit multi-gigabyte Gradle caches directly to Git.

For every archived build-environment snapshot, create a small metadata file here containing:

- project/revision;
- creation date;
- archive filename;
- archive size;
- SHA-256 checksum;
- storage/release location;
- Gradle user-home path used during creation;
- result of CLIENT `--offline` build;
- result of SERVER `--offline` build.

Example:

```text
Project: ae2stuff-0.5.1.16-gtnh
Commit: <git commit>
Archive: ae2stuff-build-env-2026-10-12.7z
SHA256: <sha256>
Location: <GitHub release asset / NAS / backup path>
CLIENT offline build: PASS
SERVER offline build: PASS
```

A snapshot should only be treated as a validated disaster-recovery source after it has been restored into a clean environment and both builds pass with `--offline`.
