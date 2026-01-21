---
phase: 02-download-engine
plan: 02
subsystem: api
tags: [on_download, cli-progress, regex-filter, httr2, dplyr]

# Dependency graph
requires:
  - phase: 02-download-engine/01
    provides: .download_single_file(), .list_all_files(), .construct_download_url()
provides:
  - on_download() user-facing function for full/file/pattern downloads
  - .download_with_progress() for batch download with cli progress bar
  - .format_bytes() for human-readable size formatting
  - .print_completion_summary() for completion messages
affects: [03-caching-layer, 04-pipeline-integration]

# Tech tracking
tech-stack:
  added: [dplyr]
  patterns: [regex-file-filtering, cli-progress-bar, quiet-mode]

key-files:
  created:
    - R/download.R
    - R/download-progress.R
    - R/openneuro-package.R
  modified:
    - DESCRIPTION
    - NAMESPACE

key-decisions:
  - "Regex detection via metacharacter presence (not explicit flag)"
  - "cli-based progress bar for interactive sessions only"
  - "dplyr added for bind_rows/arrange in file listing"

patterns-established:
  - "Regex vs exact match detection using metacharacters"
  - "interactive() check for progress bar suppression"
  - "Package-level imports via openneuro-package.R"

# Metrics
duration: ~15min
completed: 2026-01-21
---

# Phase 2 Plan 2: User-Facing Download API Summary

**Exported on_download() with full/file/regex modes, cli-based progress bar, skip/force logic, and completion summary**

## Performance

- **Duration:** ~15 min (including checkpoint pause)
- **Completed:** 2026-01-21
- **Tasks:** 3
- **Files created:** 3
- **Files modified:** 2

## Accomplishments
- User-facing `on_download()` function exported with complete documentation
- Three download modes: full dataset, specific file paths, regex pattern matching
- Cli-based progress bar for interactive sessions (auto-hidden in non-interactive)
- Completion summary showing downloaded/skipped/failed counts
- R CMD check passes: 0 errors, 0 warnings, 0 notes

## Task Commits

Each task was committed atomically:

1. **Task 1: Progress reporting utilities** - `cbde2c9` (feat)
2. **Task 2: User-facing on_download() function** - `a817fa9` (feat)
3. **Task 3: R CMD check fixes** - `9838c69` (fix), `c7e992a` (docs)

## Files Created/Modified
- `R/download.R` - Main exported on_download() function with validation, file filtering, mode detection
- `R/download-progress.R` - .download_with_progress(), .format_bytes(), .print_completion_summary()
- `R/openneuro-package.R` - Package-level imports (@importFrom rlang .data %||%)
- `DESCRIPTION` - Added dplyr to Imports, removed unused jsonlite
- `NAMESPACE` - Updated with exports and imports

## Decisions Made
- **Regex detection:** Detect regex patterns by presence of metacharacters (`[`, `*`, `+`, etc.) in single-element `files` argument rather than requiring explicit flag
- **Progress bar strategy:** Use `cli::cli_progress_bar` with interactive() check - shows progress in interactive R sessions, silent in scripts/batch
- **dplyr dependency:** Added dplyr to Imports for bind_rows() and arrange() used in file listing - acceptable dependency for R package

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added dplyr to DESCRIPTION Imports**
- **Found during:** Task 3 (R CMD check)
- **Issue:** dplyr::bind_rows() and dplyr::arrange() used in download-list.R but dplyr not declared in DESCRIPTION Imports
- **Fix:** Added `dplyr (>= 1.1.0)` to Imports in DESCRIPTION
- **Commit:** 9838c69

**2. [Rule 3 - Blocking] Removed unused jsonlite from Imports**
- **Found during:** Task 3 (R CMD check)
- **Issue:** jsonlite declared in Imports but never actually used (httr2 handles JSON internally)
- **Fix:** Removed jsonlite from DESCRIPTION Imports
- **Commit:** 9838c69

**3. [Rule 2 - Missing Critical] Added rlang .data import**
- **Found during:** Task 3 (R CMD check)
- **Issue:** `.data` pronoun used in dplyr::arrange(.data$full_path) but not imported, causing NOTE
- **Fix:** Created R/openneuro-package.R with `@importFrom rlang .data %||%`
- **Commit:** 9838c69

---

**Total deviations:** 3 auto-fixed (2 missing critical, 1 blocking)
**Impact on plan:** Standard R package dependency hygiene. No scope creep.

## Issues Encountered
None - checkpoint pause allowed user verification of download functionality.

## User Setup Required
None - no external service configuration required.

## Integration Test Results

User confirmed successful test:
```r
on_download("ds000001", files = "participants.tsv", dest_dir = tempdir())
# Result: Downloaded file, showed progress, printed summary
```

## Next Phase Readiness
- Phase 2 (Download Engine) complete
- `on_download()` ready for use in pipelines
- Ready for Phase 3 (Caching Layer) when scheduled
- Download infrastructure provides foundation for smart caching

---
*Phase: 02-download-engine*
*Completed: 2026-01-21*
