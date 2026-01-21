---
phase: 03-caching-layer
plan: 01
subsystem: caching
tags: [cache, jsonlite, atomic-writes, manifest]

# Dependency graph
requires:
  - phase: 02-download-engine
    provides: Download infrastructure that will use cache
provides:
  - CRAN-compliant cache path resolution via tools::R_user_dir
  - Atomic JSON manifest read/write operations
  - File tracking structure for cache-aware downloads
affects: [03-02 cache-aware-download, 03-03 cache-management]

# Tech tracking
tech-stack:
  added: [jsonlite]
  patterns: [atomic-write-pattern, R_user_dir-caching]

key-files:
  created: [R/cache-path.R, R/cache-manifest.R]
  modified: [DESCRIPTION]

key-decisions:
  - "Use tools::R_user_dir for CRAN-compliant cache paths"
  - "Atomic writes via temp-file-then-move pattern"
  - "Human-readable JSON manifests (pretty = TRUE)"
  - "Graceful handling of corrupt manifest files (warn and treat as empty)"

patterns-established:
  - "Cache location pattern: .on_cache_root() -> .on_dataset_cache_path() -> .on_file_cache_path()"
  - "Atomic write pattern: write to temp file, then fs::file_move to destination"
  - "Error class: openneuro_cache_error for cache-specific failures"

# Metrics
duration: 2min
completed: 2026-01-21
---

# Phase 3 Plan 1: Cache Infrastructure Summary

**CRAN-compliant cache paths via tools::R_user_dir plus atomic JSON manifest I/O with jsonlite**

## Performance

- **Duration:** 2 min
- **Started:** 2026-01-21T14:28:17Z
- **Completed:** 2026-01-21T14:30:11Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Cache path resolution using CRAN-compliant tools::R_user_dir() (Mac/Linux/Windows appropriate)
- Atomic manifest writes (temp file then move) to prevent partial/corrupt files
- Human-readable JSON manifests with file tracking (path, size, downloaded_at, backend)
- Graceful handling of corrupt manifests (warn and treat as empty)

## Task Commits

Each task was committed atomically:

1. **Task 1: Cache path helpers** - `3575364` (feat)
2. **Task 2: Manifest read/write with atomic writes** - `c9c4193` (feat)

## Files Created/Modified
- `R/cache-path.R` - Cache location helpers (.on_cache_root, .on_dataset_cache_path, .on_file_cache_path)
- `R/cache-manifest.R` - Manifest operations (.read_manifest, .write_manifest, .update_manifest, .new_manifest)
- `DESCRIPTION` - Added jsonlite (>= 1.8.0) to Imports

## Decisions Made
- **tools::R_user_dir for cache paths:** CRAN-compliant, platform-appropriate, no manual path construction
- **Atomic write pattern:** Prevents corrupt manifests from interrupted writes; follows existing pattern from download-utils.R
- **Pretty JSON output:** Human-readable manifests for debugging; minor disk overhead acceptable
- **Corrupt manifest handling:** Warn and treat as empty rather than fail; enables recovery from edge cases

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all verification passed on first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Cache infrastructure ready for cache-aware download integration (03-02)
- Manifest format established for cache management functions (03-03)
- All internal helpers follow existing code patterns (.prefix, @keywords internal)

---
*Phase: 03-caching-layer*
*Completed: 2026-01-21*
