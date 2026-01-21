---
phase: 04-backends-handle
plan: 02
subsystem: download
tags: [datalad, git-annex, processx, cli-integration, integrity-verification]

# Dependency graph
requires:
  - phase: 02-download-engine
    provides: Download infrastructure and file listing
provides:
  - .datalad_action() function for clone vs update detection
  - .download_datalad() function for DataLad CLI integration
affects: [04-03-backend-dispatch, 04-04-handle]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - processx::run for CLI execution
    - wd parameter for command working directory
    - Clone vs update pattern for existing datasets

key-files:
  created:
    - R/backend-datalad.R
  modified: []

key-decisions:
  - "300s timeout for clone, configurable timeout for get (default 1800s)"
  - "Abort with openneuro_backend_error class for fallback support"
  - "Check .datalad directory to detect existing DataLad datasets"

patterns-established:
  - "Backend error class pattern: openneuro_backend_error enables fallback"
  - "Clone-then-get pattern for DataLad dataset retrieval"
  - "Action detection pattern for handling existing directories"

# Metrics
duration: 1min 15s
completed: 2026-01-21
---

# Phase 4 Plan 2: DataLad Backend Summary

**DataLad CLI integration with git-annex integrity verification, clone from OpenNeuroDatasets GitHub, and selective file retrieval via datalad get**

## Performance

- **Duration:** 1min 15s
- **Started:** 2026-01-21T17:21:59Z
- **Completed:** 2026-01-21T17:23:14Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- DataLad backend implementation with clone and get operations
- Handles existing DataLad datasets (update) vs new directories (clone)
- Selective file retrieval support with files parameter
- Error handling with openneuro_backend_error class for fallback chain

## Task Commits

Each task was committed atomically:

1. **Task 1: DataLad Backend Implementation** - `3ef0331` (feat)

## Files Created/Modified
- `R/backend-datalad.R` - DataLad backend with .datalad_action() and .download_datalad()

## Decisions Made
- **Clone timeout (300s):** 5 minutes sufficient for cloning metadata-only repository
- **Get timeout (1800s default):** 30 minutes default, configurable for large datasets
- **Error class (openneuro_backend_error):** Consistent with S3 backend, enables fallback dispatcher
- **Check .datalad directory:** Most reliable indicator of existing DataLad dataset

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - DataLad CLI must be installed by user. Backend dispatcher will handle unavailability via fallback.

## Next Phase Readiness

- DataLad backend ready for integration with backend dispatcher (04-03)
- Uses same error class pattern as S3 backend for consistent fallback
- Clone from GitHub OpenNeuroDatasets provides integrity via git-annex

---
*Phase: 04-backends-handle*
*Completed: 2026-01-21*
