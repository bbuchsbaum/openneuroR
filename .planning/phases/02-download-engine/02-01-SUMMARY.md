---
phase: 02-download-engine
plan: 01
subsystem: api
tags: [httr2, fs, download, s3, http-range]

# Dependency graph
requires:
  - phase: 01-foundation-discovery
    provides: on_files() for file listing, on_client() for API access
provides:
  - .construct_download_url() for S3 URL construction
  - .download_single_file() with progress/retry/resume
  - .download_atomic() for temp-file + atomic move pattern
  - .list_all_files() for recursive file listing with full paths
affects: [02-02, 03-caching-layer]

# Tech tracking
tech-stack:
  added: []
  patterns: [atomic-download, http-range-resume, recursive-tree-traversal]

key-files:
  created:
    - R/download-utils.R
    - R/download-file.R
    - R/download-list.R
  modified: []

key-decisions:
  - "S3 direct URLs over GraphQL urls field for simplicity"
  - "10 MB threshold for HTTP Range resume support"
  - "URL-encode path segments individually to preserve forward slashes"

patterns-established:
  - "Atomic download: temp file + move on success"
  - "Recursive tree traversal via on_files() with key parameter"
  - "Progress bar suppression via interactive() check"

# Metrics
duration: 8min
completed: 2026-01-21
---

# Phase 2 Plan 1: Download Infrastructure Summary

**S3 URL construction, httr2-based single-file download with progress/retry/resume, and recursive file listing via tree traversal**

## Performance

- **Duration:** 8 min
- **Started:** 2026-01-21T15:30:00Z
- **Completed:** 2026-01-21T15:38:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Download URL construction for OpenNeuro S3 with proper path encoding
- Single-file download with httr2 progress bar, 3 retries with exponential backoff, and HTTP Range resume for files >= 10 MB
- Recursive file listing that traverses entire dataset directory structure and returns full paths

## Task Commits

Each task was committed atomically:

1. **Task 1: Download utilities (URL, temp files, atomic move)** - `6cc9f68` (feat)
2. **Task 2: Single-file download with progress, retry, resume** - `f37d005` (feat)
3. **Task 3: Recursive file listing with full paths** - `d950df8` (feat)

## Files Created/Modified
- `R/download-utils.R` - URL construction, atomic download wrapper, file validation, dest dir setup
- `R/download-file.R` - Main download function with httr2 progress/retry, resume support via Range headers
- `R/download-list.R` - Recursive tree traversal returning tibble with full_path column

## Decisions Made
- **S3 direct URLs:** Used direct S3 URL pattern (`https://s3.amazonaws.com/openneuro.org/{dataset}/{path}`) instead of GraphQL `urls` field - simpler, well-documented, fewer API calls
- **10 MB resume threshold:** Only attempt HTTP Range resume for files >= 10 MB to avoid overhead for small files
- **Path segment encoding:** URL-encode each path segment separately to preserve forward slashes in paths
- **Atomic download pattern:** Always download to temp file, move to final destination only on success to prevent partial/corrupt files

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed URL encoding preserving forward slashes**
- **Found during:** Task 1 (URL construction verification)
- **Issue:** `URLencode(path, reserved = TRUE)` was encoding forward slashes as `%2F`, breaking the URL path structure
- **Fix:** Split path on `/`, encode each segment individually, rejoin with `/`
- **Files modified:** R/download-utils.R
- **Verification:** URL for "sub-01/anat/T1w.nii.gz" correctly produces `sub-01/anat/T1w.nii.gz` in URL
- **Committed in:** 6cc9f68 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Essential fix for correct URL construction. No scope creep.

## Issues Encountered
None - all tasks completed as planned.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Download primitives ready for user-facing `on_download()` function
- `.list_all_files()` provides file listing for pattern matching
- `.download_single_file()` provides download mechanics with progress/retry/resume
- `.construct_download_url()` builds proper S3 URLs
- Ready for 02-02-PLAN.md (user-facing download API)

---
*Phase: 02-download-engine*
*Completed: 2026-01-21*
