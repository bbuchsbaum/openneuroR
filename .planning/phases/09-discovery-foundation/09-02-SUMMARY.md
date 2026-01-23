---
phase: 09-discovery-foundation
plan: 02
subsystem: api
tags: [discovery, derivatives, fmriprep, github-api, caching]

# Dependency graph
requires:
  - phase: 09-01
    provides: Session cache and GitHub API integration
provides:
  - on_derivatives() function for discovering derivative datasets
  - Embedded derivatives detection via on_files()
  - OpenNeuroDerivatives GitHub search integration
  - Source preference (embedded over GitHub)
affects: [10-derivative-downloads, future-derivative-workflows]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Multi-source discovery with deduplication"
    - "Cache-first API pattern with refresh bypass"

key-files:
  created:
    - R/discovery.R
    - man/on_derivatives.Rd
  modified:
    - R/utils-response.R
    - NAMESPACE

key-decisions:
  - "Embedded derivatives preferred over GitHub when same pipeline exists in both"
  - "Cache key includes both dataset_id and sources parameter"
  - "Empty tibble returned for missing derivatives (not error)"

patterns-established:
  - "Discovery functions use .discovery_cache for session caching"
  - "Multi-source functions handle errors gracefully (one source failing doesn't break others)"

# Metrics
duration: 4min
completed: 2026-01-23
---

# Phase 9 Plan 02: Main on_derivatives() Summary

**on_derivatives() function discovering fMRIPrep/MRIQC/fitlins from both embedded BIDS derivatives and OpenNeuroDerivatives GitHub org, with session caching and embedded preference**

## Performance

- **Duration:** 4 min
- **Started:** 2026-01-23T15:28:37Z
- **Completed:** 2026-01-23T15:32:17Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Implemented on_derivatives() returning tibble with 9 columns (dataset_id, pipeline, source, version, n_subjects, n_files, total_size, last_modified, s3_url)
- Embedded derivatives detection via .detect_embedded_derivatives() using on_files() API
- GitHub search via .find_derivatives_in_github() using cached .list_openneuro_derivatives_repos()
- Deduplication: embedded derivatives take precedence over GitHub when same pipeline exists
- Session caching with refresh=TRUE bypass option
- Source filtering via sources= parameter

## Task Commits

Each task was committed atomically:

1. **Task 1: Empty derivatives tibble helper** - `39a29fe` (feat)
2. **Task 2: Main on_derivatives() function** - `5539011` (feat)

## Files Created/Modified
- `R/utils-response.R` - Added .empty_derivatives_tibble() helper
- `R/discovery.R` - Main on_derivatives(), .detect_embedded_derivatives(), .find_derivatives_in_github()
- `NAMESPACE` - Added on_derivatives export
- `man/on_derivatives.Rd` - Full documentation with examples
- `man/discovery.Rd` - File documentation
- `man/dot-detect_embedded_derivatives.Rd` - Helper documentation
- `man/dot-find_derivatives_in_github.Rd` - Helper documentation
- `man/dot-empty_derivatives_tibble.Rd` - Helper documentation

## Decisions Made
- Embedded derivatives take precedence over OpenNeuroDerivatives when same pipeline exists in both sources (per CONTEXT.md guidance)
- Cache key includes sorted sources parameter to allow different cache entries for different source combinations
- API errors during embedded check propagate "not found" errors but swallow network errors to allow GitHub check to proceed
- GitHub API errors logged as warning but don't fail the function

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- on_derivatives() ready for use in discovery workflows
- Future phase 10 can build on_download_derivatives() using s3_url column
- GitHub rate limiting handled via session caching (30 req/min throttle + session cache)

---
*Phase: 09-discovery-foundation*
*Completed: 2026-01-23*
