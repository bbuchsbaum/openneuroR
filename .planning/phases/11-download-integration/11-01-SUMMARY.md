---
phase: 11-download-integration
plan: 01
subsystem: download
tags: [derivatives, fmriprep, bids, s3, filtering]

# Dependency graph
requires:
  - phase: 09-discovery-foundation
    provides: on_derivatives() for pipeline discovery
  - phase: 10-spaces-and-s3-backend
    provides: .extract_space_from_filename(), .download_with_backend(bucket=)
provides:
  - on_download_derivatives() function for downloading derivative data
  - Filter helpers for space, suffix, and subject filtering
  - BIDS-compliant cache path structure for derivatives
affects: [11-02, 11-03, cache-management, future-derivative-features]

# Tech tracking
tech-stack:
  added: []  # No new dependencies
  patterns:
    - Filter chain pattern (AND logic) for file filtering
    - BIDS suffix extraction with compound extension handling
    - Derivative cache path structure: {cache}/{dataset}/derivatives/{pipeline}/

key-files:
  created:
    - R/download-derivatives.R
    - man/on_download_derivatives.Rd
  modified:
    - NAMESPACE

key-decisions:
  - "Space matching is exact (not prefix) to avoid unexpected results"
  - "Files without _space- entity (native space) always included when filtering"
  - "Files without clear suffix (metadata) always included when filtering"
  - "dry_run returns tibble with path, size, size_formatted, dest_path"

patterns-established:
  - "Filter chain pattern: apply filters sequentially with AND logic"
  - "BIDS suffix extraction: strip compound extensions before parsing"
  - "Derivative cache path: derivatives inside dataset folder"

# Metrics
duration: 3min
completed: 2026-01-23
---

# Phase 11 Plan 01: Download Derivatives Summary

**on_download_derivatives() function with subject, space, and suffix filtering for downloading fMRIPrep/MRIQC derivatives**

## Performance

- **Duration:** 3 min
- **Started:** 2026-01-24T01:00:48Z
- **Completed:** 2026-01-24T01:03:26Z
- **Tasks:** 3 (combined into single implementation)
- **Files created:** 14 (R source + man pages)

## Accomplishments

- Main on_download_derivatives() function with full parameter support
- Filter by subjects (literal IDs or regex pattern)
- Filter by output space (exact match, native space files always included)
- Filter by BIDS suffix (bold, T1w, mask, etc.)
- dry_run mode for previewing downloads
- BIDS-compliant cache structure: {cache}/{dataset}/derivatives/{pipeline}/
- Full roxygen2 documentation with examples

## Task Commits

All three tasks were combined into a single implementation:

1. **Task 1-3: on_download_derivatives + filter helpers + documentation** - `ff2f062` (feat)

## Files Created/Modified

- `R/download-derivatives.R` - Main download function and all filter helpers
- `NAMESPACE` - Export for on_download_derivatives
- `man/on_download_derivatives.Rd` - User documentation
- `man/dot-*.Rd` - Internal helper documentation (12 files)

## Decisions Made

1. **Space matching is exact** - Prevents unexpected matches (e.g., "MNI" matching multiple spaces)
2. **Native space files always included** - Files without _space- entity are BIDS-compliant native space
3. **Metadata files always included** - Files without clear suffix are kept when suffix filtering
4. **Combined tasks** - All three tasks were tightly coupled and implemented together

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - implementation followed existing patterns from on_download() and discovery-spaces.R.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- on_download_derivatives() function ready for use
- Filter helpers available for reuse in other contexts
- Ready for 11-02 (cache visibility) and 11-03 (testing)
- No blockers

---
*Phase: 11-download-integration*
*Completed: 2026-01-23*
