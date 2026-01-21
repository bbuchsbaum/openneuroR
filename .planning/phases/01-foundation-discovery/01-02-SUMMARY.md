---
phase: 01-foundation-discovery
plan: 02
subsystem: api
tags: [graphql, discovery, tibble, openneuro, pagination]

dependency_graph:
  requires:
    - phase: 01-01
      provides: [on_client, on_request, graphql-queries]
  provides:
    - on_search function for dataset discovery
    - on_dataset function for single dataset metadata
    - on_snapshots function for version history
    - on_files function for file listing
    - response parsing utilities
  affects:
    - 02-download (will use on_files for download targets)
    - future phases needing dataset discovery

tech_stack:
  added: []
  patterns:
    - tibble return format for all user-facing functions
    - snake_case column naming convention
    - POSIXct timestamp parsing
    - list-columns for nested data (modalities, tasks)
    - error class hierarchy (validation_error, not_found_error)

key_files:
  created:
    - R/api-search.R
    - R/api-dataset.R
    - R/api-snapshots.R
    - R/api-files.R
    - man/on_search.Rd
    - man/on_dataset.Rd
    - man/on_snapshots.Rd
    - man/on_files.Rd
  modified:
    - R/utils-response.R
    - NAMESPACE

key_decisions:
  - "Search API returns null - document limitation and provide modality filter alternative"
  - "Use n_subjects instead of subjects (API returns list of IDs, we count length)"
  - "Re-throw API errors as not_found_error class for better error handling"

patterns_established:
  - "All discovery functions return tibbles with consistent column structure"
  - "Empty results return zero-row tibble (not NULL or error)"
  - "Functions accept client parameter with default on_client() for testability"

duration: 7m 8s
completed: 2026-01-21
---

# Phase 01 Plan 02: Discovery API Functions Summary

**Four discovery functions (on_search, on_dataset, on_snapshots, on_files) returning tidy tibbles with consistent structure and snake_case columns.**

## Performance

- **Duration:** 7m 8s
- **Started:** 2026-01-21T11:48:43Z
- **Completed:** 2026-01-21T11:55:51Z
- **Tasks:** 3
- **Files modified:** 6 R files, 13 man files

## Accomplishments

- `on_search()` lists datasets with modality filter and pagination support
- `on_dataset()` retrieves single dataset metadata as one-row tibble
- `on_snapshots()` lists all version tags for a dataset
- `on_files()` lists files with subdirectory navigation via tree parameter
- All functions return tibbles with POSIXct timestamps and snake_case columns
- R CMD check passes with 0 errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement on_search and on_dataset** - `55dbfd8` (feat)
2. **Task 2: Implement on_snapshots and on_files** - `e5e130b` (feat)
3. **Task 3: Add roxygen documentation and verify exports** - `1eb8a75` (docs)

## Files Created/Modified

**Created:**
- `R/api-search.R` - Dataset search with modality filter and pagination
- `R/api-dataset.R` - Single dataset metadata retrieval
- `R/api-snapshots.R` - Snapshot listing for version history
- `R/api-files.R` - File listing with subdirectory navigation
- `man/on_search.Rd` - Documentation for search function
- `man/on_dataset.Rd` - Documentation for dataset function
- `man/on_snapshots.Rd` - Documentation for snapshots function
- `man/on_files.Rd` - Documentation for files function

**Modified:**
- `R/utils-response.R` - Added parsing helpers for all response types
- `NAMESPACE` - Exports for all 5 main functions

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Search API documented as limited availability | OpenNeuro search endpoint returns null - provide modality filter as reliable alternative |
| Use n_subjects column (count) instead of subjects list | API returns list of subject IDs, count is more practical for tibble |
| Re-throw API not-found as openneuro_not_found_error class | Enables catch-by-class for better error handling |
| Support tree parameter in on_files | Enables subdirectory exploration without multiple API calls |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed subjects field parsing**
- **Found during:** Task 1 verification
- **Issue:** API returns subjects as list of IDs (["01", "02", ...]), not count
- **Fix:** Changed to n_subjects column that counts list length
- **Files modified:** R/utils-response.R
- **Committed in:** 55dbfd8

**2. [Rule 2 - Missing Critical] Added warning for search API unavailability**
- **Found during:** Task 1 verification
- **Issue:** OpenNeuro search endpoint returns null for all queries
- **Fix:** Added cli::cli_warn() when search returns empty with guidance to use modality filter
- **Files modified:** R/api-search.R
- **Committed in:** 55dbfd8

---

**Total deviations:** 2 auto-fixed (1 bug, 1 missing critical)
**Impact on plan:** Both fixes necessary for correct API behavior. Search limitation is upstream API issue, not package bug.

## Issues Encountered

- **Search endpoint returns null:** The OpenNeuro `search(q: $query)` endpoint returns null for all queries. Schema introspection confirms the endpoint exists but it appears non-functional. Workaround: documented limitation and recommend using `on_search(modality = "MRI")` for reliable filtering.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Phase 02 (Download):** Yes

**What Phase 02 needs:**
- `on_files()` returns file listing with `annexed` flag for download strategy
- `on_snapshots()` provides version tags for download targeting
- Response parsing patterns established for new endpoints

**Potential blockers:** None identified.

**API discoveries for next phase:**
- Files have `key` field for tree traversal
- `annexed` boolean indicates git-annex storage (larger files)
- Snapshot `size` field returns NA for older snapshots

---
*Phase: 01-foundation-discovery*
*Completed: 2026-01-21*
