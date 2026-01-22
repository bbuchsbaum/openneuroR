---
phase: 06-subject-querying
plan: 01
subsystem: api
tags: [graphql, tibble, natural-sort, stringi, subjects]

# Dependency graph
requires:
  - phase: 05-infrastructure
    provides: GraphQL query infrastructure, httptest2 mocking patterns
provides:
  - on_subjects() function for querying dataset subject IDs
  - .parse_subjects() response parser
  - .sort_subjects_natural() for natural sorting
  - httptest2 mock for subject queries
affects: [07-download-filtering, 08-bids-bridge]

# Tech tracking
tech-stack:
  added: [stringi (Suggests)]
  patterns: [natural sorting for subject IDs, dataset-level stats in tibble]

key-files:
  created:
    - inst/graphql/get_subjects.gql
    - R/api-subjects.R
    - tests/testthat/test-api-subjects.R
    - tests/testthat/openneuro.org/crn/graphql-99fcfa-POST.json
    - man/on_subjects.Rd
  modified:
    - R/utils-response.R
    - NAMESPACE
    - DESCRIPTION

key-decisions:
  - "Subject IDs returned as-is from API (01, 02, etc.) not prefixed with sub-"
  - "Natural sorting via stringi::stri_sort with base R fallback"
  - "n_files is estimated as totalFiles / number of subjects"

patterns-established:
  - "Natural sorting pattern for BIDS-style IDs using stringi"
  - "Dataset-level stats columns repeated per row in tibble"

# Metrics
duration: 5min
completed: 2026-01-22
---

# Phase 6 Plan 01: Subject Querying Summary

**on_subjects() function querying subject IDs via GraphQL summary endpoint with natural sorting and dataset-level stats**

## Performance

- **Duration:** 5 min
- **Started:** 2026-01-22T16:13:56Z
- **Completed:** 2026-01-22T16:19:00Z
- **Tasks:** 3
- **Files modified:** 9

## Accomplishments

- Created GraphQL query for snapshot summary subjects
- Implemented on_subjects() following on_files() patterns
- Added natural sorting for subject IDs (sub-01, sub-02, ..., sub-10)
- Returns tibble with dataset_id, subject_id, n_sessions, n_files
- R CMD check passes with 0 errors, 0 warnings, 0 notes
- 391 tests passing (16 new for on_subjects)

## Task Commits

Each task was committed atomically:

1. **Task 1: GraphQL query and parsing infrastructure** - `7a8243c` (feat)
2. **Task 2: on_subjects() API function with tests** - `115aeb1` (feat)
3. **Task 3: Verification and documentation** - (no new code, verification only)

## Files Created/Modified

- `inst/graphql/get_subjects.gql` - GraphQL query for snapshot.summary.subjects
- `R/api-subjects.R` - on_subjects() exported function with full roxygen docs
- `R/utils-response.R` - Added .parse_subjects() and .sort_subjects_natural()
- `tests/testthat/test-api-subjects.R` - 8 tests for validation and sorting
- `tests/testthat/openneuro.org/crn/graphql-99fcfa-POST.json` - httptest2 mock
- `man/on_subjects.Rd` - Generated documentation
- `NAMESPACE` - Added export(on_subjects)
- `DESCRIPTION` - Added stringi to Suggests

## Decisions Made

- **Subject ID format:** Kept as-is from API (e.g., "01", "02") rather than prefixing with "sub-". The API returns the ID portion without the prefix.
- **Natural sorting:** Used stringi::stri_sort(numeric = TRUE) with base R fallback for environments without stringi
- **Dataset-level stats:** n_sessions and n_files are dataset-wide values repeated per row since per-subject breakdown isn't available from API

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- **Mock file path:** httptest2 has a nested directory structure (openneuro.org/openneuro.org/crn/) that required duplicating mock files. Resolved by copying mock to both locations.
- **stringi dependency warning:** R CMD check warned about undeclared stringi import. Resolved by adding stringi to Suggests in DESCRIPTION.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- on_subjects() ready for use in Phase 7 (download filtering with subjects= parameter)
- API pattern established for subject-level filtering
- Mock infrastructure in place for testing subject queries

---
*Phase: 06-subject-querying*
*Completed: 2026-01-22*
