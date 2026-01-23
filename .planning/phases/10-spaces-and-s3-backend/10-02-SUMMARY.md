---
phase: 10-spaces-and-s3-backend
plan: 02
subsystem: backend
tags: [s3, aws-cli, derivatives, bucket, fallback]

# Dependency graph
requires:
  - phase: 09-discovery-foundation
    provides: Session caching infrastructure (.discovery_cache)
provides:
  - Parameterized S3 backend with bucket argument
  - .probe_s3_bucket() for lazy accessibility checking
  - Verbose fallback logging in dispatch
affects: [11-download-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Parameterized bucket selection for multi-bucket S3 access
    - Lazy bucket probing with session caching
    - Verbose fallback logging with error context

key-files:
  created: []
  modified:
    - R/backend-s3.R
    - R/backend-dispatch.R
    - man/dot-download_s3.Rd
    - man/dot-download_with_backend.Rd
    - man/dot-probe_s3_bucket.Rd

key-decisions:
  - "Default bucket remains 'openneuro.org' for backward compatibility"
  - "Probe caching uses .discovery_cache from Phase 9"
  - "Error messages truncated to 80 chars for readability in fallback logging"

patterns-established:
  - "Bucket parameter: Add bucket='openneuro.org' default to S3-related functions"
  - "Verbose fallback: Log 'X failed: {error}, trying Y...' on backend failures"

# Metrics
duration: 4min
completed: 2026-01-23
---

# Phase 10 Plan 02: S3 Backend Multi-Bucket Support Summary

**Parameterized S3 backend for openneuro-derivatives bucket with lazy probing and verbose fallback logging**

## Performance

- **Duration:** 4 min
- **Started:** 2026-01-23T22:06:40Z
- **Completed:** 2026-01-23T22:10:41Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- .download_s3() accepts bucket parameter for multi-bucket support
- .probe_s3_bucket() provides lazy accessibility checking with session caching
- Verbose fallback logging shows "S3 failed: {error}, trying DataLad..." during failures
- Backward compatibility maintained with default bucket="openneuro.org"

## Task Commits

Each task was committed atomically:

1. **Task 1: Parameterize .download_s3() and add bucket probing** - `be31c0d` (feat)
2. **Task 2: Update dispatch with bucket-aware fallback and verbose logging** - `c703274` (feat)

## Files Created/Modified
- `R/backend-s3.R` - Added bucket parameter to .download_s3(), new .probe_s3_bucket() helper (212 lines)
- `R/backend-dispatch.R` - Updated .download_with_backend() with bucket passthrough and verbose logging (173 lines)
- `man/dot-download_s3.Rd` - Updated documentation for bucket parameter
- `man/dot-download_with_backend.Rd` - Updated documentation for bucket parameter
- `man/dot-probe_s3_bucket.Rd` - New documentation for bucket probing function

## Decisions Made
- Default bucket remains "openneuro.org" for backward compatibility
- Bucket probe results cached with key format `s3_bucket_probe_<bucket>` or `s3_bucket_probe_<bucket>_<test_path>`
- Error messages truncated to 80 characters for readable verbose output
- OpenNeuroDerivatives DataLad fallback URL handling noted as caller responsibility (Phase 11)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Roxygen documentation had unescaped braces in cache key format description - fixed by using angle brackets
- Missing opening brace in @examples block - quick syntax fix

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- S3 backend ready to download from openneuro-derivatives bucket
- .probe_s3_bucket() available for Phase 11 to check bucket accessibility before download
- Verbose logging helps debug fallback chain during derivative downloads
- Phase 11 can use bucket="openneuro-derivatives" with dataset_id="fmriprep/ds000001-fmriprep"

---
*Phase: 10-spaces-and-s3-backend*
*Completed: 2026-01-23*
