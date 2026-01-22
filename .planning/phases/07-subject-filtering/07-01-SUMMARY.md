---
phase: 07-subject-filtering
plan: 01
subsystem: api
tags: [download, subjects, regex, filtering, BIDS]

# Dependency graph
requires:
  - phase: 06-subject-querying
    provides: on_subjects() for listing available subjects
provides:
  - subjects= parameter for on_download()
  - include_derivatives= parameter for on_download()
  - regex() helper for pattern-based subject matching
  - Subject validation with helpful error messages
affects: [08-bids-bridge, future download enhancements]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - S3 class for regex marker (on_regex)
    - Auto-anchoring for regex patterns
    - Subject ID normalization (sub- prefix)

key-files:
  created:
    - R/subject-filter.R
    - tests/testthat/test-subject-filter.R
  modified:
    - R/download.R
    - tests/testthat/test-download.R
    - NAMESPACE
    - man/on_download.Rd
    - man/regex.Rd

key-decisions:
  - "regex() returns S3 class for explicit type detection"
  - "Auto-anchor regex patterns for full subject ID matching"
  - "Always include root files (dataset_description.json, README, etc.) regardless of filter"
  - "Subject IDs normalized to sub- prefix internally"

patterns-established:
  - "S3 class marker pattern for type discrimination (on_regex)"
  - "Root file inclusion pattern for filtered downloads"

# Metrics
duration: 20min
completed: 2026-01-22
---

# Phase 7 Plan 01: Subject Filtering Summary

**subjects= parameter for on_download() with regex() helper enabling selective subject downloads with automatic root file inclusion**

## Performance

- **Duration:** 20 min
- **Started:** 2026-01-22T17:05:16Z
- **Completed:** 2026-01-22T17:25:00Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments
- Subject filtering infrastructure with regex() helper and internal normalization
- on_download() extended with subjects= and include_derivatives= parameters
- Invalid/empty subject matches produce helpful errors with available subjects
- 63 new tests for subject filtering functionality

## Task Commits

Each task was committed atomically:

1. **Task 1: Subject filtering infrastructure** - `bfa69f7` (feat)
2. **Task 2: Integrate subjects= into on_download()** - `6d7002f` (feat)
3. **Task 3: Final verification** - No commit (verification only)

## Files Created/Modified
- `R/subject-filter.R` - regex() helper, is_regex(), normalization, validation, file filtering
- `tests/testthat/test-subject-filter.R` - 55 tests for filtering infrastructure
- `R/download.R` - Added subjects= and include_derivatives= parameters
- `tests/testthat/test-download.R` - 8 new tests for subjects= parameter
- `NAMESPACE` - Export regex()
- `man/regex.Rd` - Documentation for regex() helper
- `man/on_download.Rd` - Updated with new parameters

## Decisions Made
- **regex() returns S3 class:** Using `c("on_regex", "character")` for explicit type detection rather than inferring from metacharacters
- **Auto-anchor patterns:** Patterns are anchored with ^ and $ for full match - `regex("sub-01")` matches "sub-01" but not "sub-010"
- **Root files always included:** dataset_description.json, README, CHANGES, participants.tsv, .bidsignore always downloaded regardless of subject filter
- **Subject IDs normalized internally:** Users can specify "01" or "sub-01" - both work identically

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed backend file passing when subjects= specified**
- **Found during:** Task 2 (Integration testing)
- **Issue:** Backend dispatch was passing files conditionally based only on files= parameter, not subjects=
- **Fix:** Changed conditional to check both files and subjects: `if (is.null(files) && is.null(subjects)) NULL else filtered_files$full_path`
- **Files modified:** R/download.R
- **Verification:** All 8 new tests pass
- **Committed in:** 6d7002f (Task 2 commit)

**2. [Rule 3 - Blocking] Added utils::head() prefix**
- **Found during:** Task 1 (R CMD check)
- **Issue:** `head()` without namespace prefix caused NOTE in R CMD check
- **Fix:** Changed to `utils::head()` for explicit namespace
- **Files modified:** R/subject-filter.R
- **Verification:** R CMD check passes with 0 notes (except CRAN incoming)
- **Committed in:** bfa69f7 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both auto-fixes necessary for correctness. No scope creep.

## Issues Encountered
None - execution proceeded smoothly after auto-fixes.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Subject filtering complete and tested
- Ready for Phase 8: BIDS Bridge (on_bids() function)
- on_download() can now selectively download subjects for BIDS processing

---
*Phase: 07-subject-filtering*
*Completed: 2026-01-22*
