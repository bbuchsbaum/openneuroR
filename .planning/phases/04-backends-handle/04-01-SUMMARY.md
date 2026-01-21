---
phase: 04-backends-handle
plan: 01
subsystem: download-backends
tags: [s3, aws-cli, processx, backend-detection]

dependency-graph:
  requires:
    - 02-download-engine (download infrastructure)
    - 03-caching-layer (cache paths)
  provides:
    - Backend availability detection (.backend_available, .backend_status)
    - AWS CLI path discovery (.find_aws_cli)
    - S3 download function (.download_s3)
  affects:
    - 04-02 (backend dispatcher will use these)
    - 04-03 (handle will use backends)

tech-stack:
  added:
    - processx (>= 3.8.0)
  patterns:
    - Session-cached backend detection via local() closure
    - CLI execution via processx::run() with timeout
    - AWS CLI --no-sign-request for anonymous public bucket access

file-tracking:
  key-files:
    created:
      - R/backend-detect.R
      - R/backend-s3.R
    modified:
      - DESCRIPTION

decisions:
  - id: processx-for-cli
    choice: "processx::run() for CLI execution"
    rationale: "Robust timeout, error handling, no shell overhead"
  - id: session-cached-detection
    choice: "local() closure for session-level caching"
    rationale: "Avoid repeated Sys.which() calls while keeping lazy detection"
  - id: find-aws-cli-fallback
    choice: "Check common paths if Sys.which() fails"
    rationale: "AWS CLI may be installed but not in PATH"

metrics:
  tasks: 2/2
  duration: ~3 min
  completed: 2026-01-21
---

# Phase 4 Plan 1: Backend Detection and S3 Backend Summary

Backend availability detection via Sys.which() with session caching, plus S3 download backend using AWS CLI with --no-sign-request for public bucket access.

## What Was Built

### Backend Detection (R/backend-detect.R)

1. **`.backend_available(backend)`** - Check if specific backend is available:
   - "s3": Checks if AWS CLI is installed via `.find_aws_cli()`
   - "datalad": Checks for both `datalad` and `git-annex` commands
   - "https": Always returns TRUE (universal fallback)
   - Returns FALSE for unknown backends

2. **`.backend_status(backend, refresh)`** - Session-cached detection:
   - Uses `local()` closure to cache results for the session
   - Avoids repeated `Sys.which()` calls on each use
   - Optional `refresh=TRUE` to force re-check

3. **`.find_aws_cli()`** - Find AWS CLI executable:
   - First checks `Sys.which("aws")`
   - Falls back to common installation paths:
     - `/usr/local/bin/aws`
     - `/opt/homebrew/bin/aws` (Homebrew on Apple Silicon)
     - `~/.local/bin/aws`
     - Windows: `C:/Program Files/Amazon/AWSCLIV2/aws.exe`
   - Returns path or empty string

### S3 Backend (R/backend-s3.R)

1. **`.download_s3(dataset_id, dest_dir, files, quiet, timeout)`**:
   - Constructs S3 URI: `s3://openneuro.org/{dataset_id}`
   - Uses `aws s3 sync --no-sign-request` for anonymous access
   - Supports selective file downloads via `--exclude "*"` + `--include` patterns
   - Executes via `processx::run()` with configurable timeout (default 30 min)
   - Returns `list(success = TRUE, backend = "s3")` on success
   - Throws `openneuro_backend_error` class on failure (enables fallback)

### DESCRIPTION Updates

- Added `processx (>= 3.8.0)` to Imports

## How It Works

```r
# Check if S3 backend is available
.backend_status("s3")
# TRUE (if aws cli installed)

# Download dataset via S3
.download_s3("ds000001", "/path/to/dest", quiet = FALSE)

# Download specific files
.download_s3("ds000001", "/path/to/dest",
             files = c("participants.tsv", "sub-*/anat/*.nii.gz"))
```

## Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| CLI execution | processx::run() | Timeout support, proper error handling, no shell |
| Backend detection | Session-cached via local() | Avoid repeated Sys.which(), lazy detection |
| AWS CLI discovery | Fallback to common paths | AWS CLI may not be in PATH |
| S3 access | --no-sign-request | Anonymous access to public OpenNeuro bucket |
| Error class | openneuro_backend_error | Enables catch-by-class fallback logic |

## Commit Log

| Task | Commit | Description |
|------|--------|-------------|
| 1 | f5eb41f | Backend detection utilities |
| 2 | a17f1de | S3 backend implementation |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

```
Backend detection tests:
.backend_available("https"): TRUE
.backend_status("s3"): TRUE

S3 backend tests:
exists(".download_s3"): TRUE

R CMD check: Status: 1 WARNING, 3 NOTEs (pre-existing issues, no errors)
```

## Next Phase Readiness

**Ready for 04-02:** Backend dispatcher and DataLad backend can now use:
- `.backend_available()` and `.backend_status()` for detection
- `.download_s3()` as S3 implementation
- `openneuro_backend_error` class for fallback handling

**Dependencies delivered:**
- [ ] `.backend_available()` - Backend availability check
- [ ] `.backend_status()` - Cached backend status
- [ ] `.find_aws_cli()` - AWS CLI discovery
- [ ] `.download_s3()` - S3 download function
- [ ] processx in DESCRIPTION Imports
