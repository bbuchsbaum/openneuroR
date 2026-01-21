---
phase: 04-backends-handle
plan: 03
subsystem: download
tags: [backend-dispatch, auto-select, fallback, on_download]

dependency-graph:
  requires:
    - 04-01 (backend detection, S3 backend)
    - 04-02 (DataLad backend)
  provides:
    - Backend auto-selection (.select_backend)
    - Backend dispatch with fallback (.download_with_backend)
    - on_download() backend parameter
  affects:
    - 04-04 (handle API will use on_download with backend support)

tech-stack:
  added: []
  patterns:
    - Priority-based backend selection (datalad > s3 > https)
    - Error-class-based fallback (openneuro_backend_error)
    - Recursive fallback with try-catch

file-tracking:
  key-files:
    created:
      - R/backend-dispatch.R
    modified:
      - R/download.R
      - man/on_download.Rd

decisions:
  - id: datalad-first-priority
    choice: "DataLad > S3 > HTTPS priority order"
    rationale: "DataLad provides git-annex integrity verification, S3 is faster than HTTPS"
  - id: null-for-https-signal
    choice: "Return NULL to signal HTTPS fallback"
    rationale: "Clean separation: dispatch handles S3/DataLad, existing code handles HTTPS"
  - id: recursive-fallback
    choice: "Recursive call for fallback chain"
    rationale: "Simple, handles any depth of fallback (datalad -> s3 -> https)"

metrics:
  tasks: 2/2
  duration: ~3 min
  completed: 2026-01-21
---

# Phase 4 Plan 3: Backend Dispatch Summary

**Backend auto-selection with priority chain (DataLad > S3 > HTTPS), silent fallback on failure, and on_download() backend parameter**

## Performance

- **Duration:** ~3 min
- **Tasks:** 2/2
- **Files created:** 1
- **Files modified:** 2 (+ Rd files)

## Accomplishments

- Backend auto-selection based on availability and priority
- Silent fallback when backend fails (catches openneuro_backend_error)
- on_download() accepts backend parameter for explicit selection
- Manifest records which backend was used for each file

## Task Commits

1. **Task 1: Backend Dispatch Logic** - `dafa788`
   - Created R/backend-dispatch.R with .select_backend() and .download_with_backend()

2. **Task 2: Integrate Backend into on_download** - `cf62b6d`
   - Added backend parameter to on_download()
   - Integrated with backend dispatch
   - Updated roxygen documentation

## Files Created/Modified

**Created:**
- `R/backend-dispatch.R` - Backend selection and dispatch logic

**Modified:**
- `R/download.R` - Added backend parameter, integrated dispatch
- `man/on_download.Rd` - Updated documentation

**Generated (via roxygen):**
- `man/backend-dispatch.Rd`
- `man/dot-select_backend.Rd`
- `man/dot-download_with_backend.Rd`

## Technical Implementation

### Backend Selection Priority

```r
.select_backend(preferred = NULL)
# Priority: c("datalad", "s3", "https")
# If preferred specified and available: use it
# If preferred unavailable: warn and fallback
# Auto-select: first available in priority order
```

### Download with Fallback

```r
.download_with_backend(dataset_id, dest_dir, files, backend, quiet, timeout)
# 1. Select backend via .select_backend()
# 2. If HTTPS: return NULL (signal caller to use existing flow)
# 3. Execute S3 or DataLad download
# 4. On openneuro_backend_error: recursive call with next backend
#    - datalad -> s3 -> https
```

### Integration in on_download()

```r
on_download("ds000001", backend = "s3")  # Explicit S3
on_download("ds000001")                   # Auto-select best

# Flow:
# 1. Call .download_with_backend()
# 2. If returns success: update manifest with backend, return
# 3. If returns NULL (HTTPS): use existing .download_with_progress()
```

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Priority order | DataLad > S3 > HTTPS | DataLad has integrity, S3 is fast |
| NULL signal for HTTPS | Return NULL from dispatch | Clean separation of concerns |
| Recursive fallback | Recursive call with next backend | Simple, extensible fallback chain |
| Manifest backend field | Record which backend downloaded each file | Debugging and transparency |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

```
Testing .select_backend()...
Auto-select result: datalad
Explicit s3 select: s3
Explicit https select: https

R CMD check: Status: 1 WARNING, 3 NOTEs (pre-existing, no errors)

on_download signature:
function(id, tag, files, dest_dir, use_cache, quiet, verbose,
         force, backend, client)
# backend = NULL present
```

## Usage Examples

```r
# Auto-select best available backend
on_download("ds000001")
# i Using datalad backend

# Explicit backend selection
on_download("ds000001", backend = "s3")
# i Using s3 backend

# Force HTTPS (always available)
on_download("ds000001", backend = "https")
# i Using https backend

# When requested backend unavailable, falls back with warning
on_download("ds000001", backend = "datalad")
# If datalad not installed:
# ! Requested backend 'datalad' not available, falling back
# i Using s3 backend
```

## Next Phase Readiness

- Backend dispatch complete and integrated
- Ready for 04-04: on_handle() API (if planned)
- All three backends work with unified interface
- Manifest records backend for each downloaded file

---
*Phase: 04-backends-handle*
*Completed: 2026-01-21*
