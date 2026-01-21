---
phase: 04-backends-handle
verified: 2026-01-21T17:35:40Z
status: passed
score: 5/5 must-haves verified
---

# Phase 4: Backends + Handle Verification Report

**Phase Goal:** Researchers get best-available backend and pipeline-friendly lazy handles
**Verified:** 2026-01-21T17:35:40Z
**Status:** PASSED
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | S3 backend downloads datasets using AWS CLI (--no-sign-request) | VERIFIED | `.download_s3()` in R/backend-s3.R uses `args <- c("s3", "sync", "--no-sign-request", s3_uri, dest_dir)` at line 55 |
| 2 | DataLad backend downloads datasets using DataLad CLI with integrity checks | VERIFIED | `.download_datalad()` in R/backend-datalad.R clones from OpenNeuroDatasets GitHub and uses `datalad get` for git-annex integrity |
| 3 | Auto-select picks best available backend (DataLad > S3 > HTTPS) | VERIFIED | `.select_backend()` in R/backend-dispatch.R line 25: `priority <- c("datalad", "s3", "https")` |
| 4 | User can create lazy handle without triggering download | VERIFIED | `on_handle()` in R/handle.R creates S3 structure with `state = "pending"` without calling on_download() |
| 5 | User can fetch handle to materialize download and get filesystem path | VERIFIED | `on_fetch.openneuro_handle()` calls `on_download()`, updates state to "ready", sets path; `on_path()` returns path |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/backend-detect.R` | Backend availability detection | VERIFIED | 91 lines, exports `.backend_available()`, `.backend_status()`, `.find_aws_cli()` |
| `R/backend-s3.R` | S3 download via AWS CLI | VERIFIED | 90 lines, exports `.download_s3()` with processx::run(), --no-sign-request |
| `R/backend-datalad.R` | DataLad download via CLI | VERIFIED | 116 lines, exports `.datalad_action()`, `.download_datalad()` with clone+get |
| `R/backend-dispatch.R` | Auto-select and fallback | VERIFIED | 130 lines, exports `.select_backend()`, `.download_with_backend()` |
| `R/handle.R` | Lazy handle S3 class | VERIFIED | 246 lines, exports `on_handle()`, `on_fetch()`, `on_path()`, `print.openneuro_handle()` |
| `R/download.R` | on_download with backend param | VERIFIED | Line 91: `backend = NULL` parameter, line 184: calls `.download_with_backend()` |
| `NAMESPACE` | Handle exports registered | VERIFIED | Contains `export(on_handle)`, `export(on_fetch)`, `export(on_path)`, S3method registrations |
| `DESCRIPTION` | processx in Imports | VERIFIED | Line 23: `processx (>= 3.8.0)` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `on_download()` | Backend dispatch | `.download_with_backend()` | WIRED | download.R:184 calls dispatch |
| `.download_with_backend()` | S3 backend | `.download_s3()` | WIRED | backend-dispatch.R:104 |
| `.download_with_backend()` | DataLad backend | `.download_datalad()` | WIRED | backend-dispatch.R:103 |
| `.select_backend()` | Backend detection | `.backend_status()` | WIRED | backend-dispatch.R:39,52 |
| `.backend_status()` | Availability check | `.backend_available()` | WIRED | backend-detect.R:46 |
| `on_fetch()` | Download system | `on_download()` | WIRED | handle.R:148 |
| S3 backend | CLI execution | `processx::run()` | WIRED | backend-s3.R:72 |
| DataLad backend | CLI execution | `processx::run()` | WIRED | backend-datalad.R:73,98 |

### Requirements Coverage

| Requirement | Status | Notes |
|-------------|--------|-------|
| BACK-02: S3 backend with AWS CLI | SATISFIED | Full implementation with --no-sign-request |
| BACK-03: DataLad backend with git-annex integrity | SATISFIED | Clone from GitHub + datalad get |
| BACK-04: Auto-select best backend | SATISFIED | Priority chain with fallback |
| HAND-01: Lazy handle creation | SATISFIED | on_handle() creates pending handle |
| HAND-02: Handle fetching | SATISFIED | on_fetch() materializes download |
| HAND-03: Path extraction | SATISFIED | on_path() returns filesystem path |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| R/handle.R | 223 | "placeholder" in comment | INFO | Not a stub - comment about conditional display logic |

No blocking anti-patterns found.

### Human Verification Required

None - all criteria are programmatically verifiable through code inspection.

### Verification Summary

Phase 4 is fully implemented with all five success criteria verified:

1. **S3 Backend**: The `.download_s3()` function constructs AWS CLI commands with `--no-sign-request` for anonymous public bucket access, executes via `processx::run()`, and returns consistent result format.

2. **DataLad Backend**: The `.download_datalad()` function clones datasets from OpenNeuroDatasets GitHub organization and retrieves file content with git-annex integrity verification.

3. **Auto-Select**: The `.select_backend()` function implements priority-based selection (datalad > s3 > https) with session-cached detection to avoid repeated Sys.which() calls.

4. **Lazy Handle Creation**: The `on_handle()` function creates an S3-class object with `state = "pending"` without triggering any network calls.

5. **Handle Fetch/Path**: The `on_fetch()` method calls `on_download()` to materialize data and updates handle state to "ready"; `on_path()` returns the filesystem path from fetched handles.

All artifacts are substantive (673 total lines across 5 new files), properly wired together, and documented with roxygen2. The NAMESPACE exports all public functions and registers S3 methods correctly.

---

_Verified: 2026-01-21T17:35:40Z_
_Verifier: Claude (gsd-verifier)_
