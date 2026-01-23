---
phase: 10-spaces-and-s3-backend
plan: 01
subsystem: discovery
tags: [bids, spaces, s3, aws-cli, fmriprep, derivatives]

# Dependency graph
requires:
  - phase: 09-discovery-foundation
    provides: on_derivatives(), .discovery_cache
provides:
  - on_spaces() function for discovering derivative output spaces
  - Space extraction helpers for BIDS filenames
  - S3 file listing for openneuro-derivatives bucket
affects: [filtering, download-derivatives]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - BIDS space entity parsing via regex
    - S3 file listing via AWS CLI processx
    - Sampling first 2-3 subjects for efficient space discovery

key-files:
  created:
    - R/discovery-spaces.R
    - man/on_spaces.Rd
    - man/dot-extract_space_from_filename.Rd
    - man/dot-extract_spaces_from_files.Rd
    - man/dot-list_derivative_files_embedded.Rd
    - man/dot-list_derivative_files_s3.Rd
  modified:
    - NAMESPACE

key-decisions:
  - "Space extraction via _space-([A-Za-z0-9]+) regex pattern"
  - "Do NOT infer T1w from files without space entity (BIDS convention)"
  - "Sample first 2-3 subjects for embedded sources (efficiency)"
  - "Use --page-size 500 for S3 listing (sufficient sampling)"

patterns-established:
  - "on_spaces(derivative_row) takes single tibble row from on_derivatives()"
  - "Graceful handling of missing AWS CLI with warning"
  - "Session caching with source-aware cache keys"

# Metrics
duration: 7min
completed: 2026-01-23
---

# Phase 10 Plan 01: on_spaces() Function Summary

**Space discovery for derivative datasets via BIDS filename parsing and S3 file listing**

## Performance

- **Duration:** 7 min
- **Started:** 2026-01-23T22:07:00Z
- **Completed:** 2026-01-23T22:14:00Z
- **Tasks:** 2
- **Files created:** 6 (R/discovery-spaces.R + 5 man files)

## Accomplishments

- Created on_spaces() function to discover available output spaces for derivatives
- Implemented space extraction from BIDS filenames using _space- entity regex
- Added S3 file listing for openneuro-derivatives bucket via AWS CLI
- Implemented efficient sampling (first 2-3 subjects) for embedded sources
- Session caching prevents redundant API/S3 calls

## Task Commits

Each task was committed atomically:

1. **Task 1: Space extraction helpers and S3 file listing** - `fe2e017` (feat)
2. **Task 2: Main on_spaces() function with caching** - `3e3ff40` (docs - exported as part of 10-02 metadata commit)

Note: Task 2 artifacts (NAMESPACE export, man/on_spaces.Rd) were committed with 10-02 plan due to execution order overlap.

## Files Created/Modified

- `R/discovery-spaces.R` - on_spaces() and 4 helper functions
- `man/on_spaces.Rd` - Exported function documentation
- `man/dot-extract_space_from_filename.Rd` - Internal helper docs
- `man/dot-extract_spaces_from_files.Rd` - Internal helper docs
- `man/dot-list_derivative_files_embedded.Rd` - Embedded source helper docs
- `man/dot-list_derivative_files_s3.Rd` - S3 source helper docs
- `NAMESPACE` - Added on_spaces export

## Decisions Made

1. **Space regex pattern**: `_space-([A-Za-z0-9]+)` captures common BIDS space labels
2. **No T1w inference**: Files without space entity are NOT assumed to be T1w (per BIDS convention, native space often omits the entity)
3. **Sampling strategy**: First 2-3 subjects for embedded sources, 500 items for S3 (sufficient to discover all space variants)
4. **Cache key format**: `spaces_{dataset_id}_{pipeline}_{source}` for granular caching

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Rd brace escaping in backend-s3.R**
- **Found during:** Task 2 verification (R CMD check)
- **Issue:** `{pipeline}/{dataset_id}-{pipeline}` in @param caused checkRd warnings
- **Fix:** Changed to `<pipeline>/<dataset_id>-<pipeline>` backtick format
- **Files modified:** R/backend-s3.R, man/dot-download_s3.Rd
- **Verification:** R CMD check passes with 0 warnings
- **Committed in:** 3e3ff40 (part of 10-02 metadata commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor documentation fix for R CMD check compliance. No scope creep.

## Issues Encountered

None - plan executed smoothly.

## User Setup Required

None - no external service configuration required.

Note: AWS CLI is optional. If not installed, on_spaces() will warn and return empty vector for openneuro-derivatives sources.

## Next Phase Readiness

- on_spaces() ready for integration with filtering/download workflows
- Researcher can now query `on_derivatives("ds000102") |> slice(1) |> on_spaces()` to discover available spaces
- S3 listing foundation ready for derivative downloads in future phases

---
*Phase: 10-spaces-and-s3-backend*
*Completed: 2026-01-23*
