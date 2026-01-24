# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-22)

**Core value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.
**Current focus:** Phase 11 - Download Integration

## Current Position

Phase: 11 of 11 (Download Integration)
Plan: 1 of 3 in current phase
Status: In progress
Last activity: 2026-01-23 - Completed 11-01-PLAN.md (on_download_derivatives function)

Progress: [================>..] 62%
(v1.0 + v1.1 complete: 8 phases / 16 plans; v1.2: 5/6 plans complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 21
- Average duration: ~12 min
- Total execution time: ~4.5 hours (v1.0 + v1.1 + v1.2 partial)

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1-5 (v1.0) | 13 | ~3h | ~14 min |
| 6-8 (v1.1) | 3 | ~1h | ~20 min |
| 9 (v1.2) | 2/2 | 8min | 4 min |
| 10 (v1.2) | 2/2 | 11min | 5.5 min |
| 11 (v1.2) | 1/3 | 3min | 3 min |

**Recent Trend:**
- Last plan (11-01): 3 min (clean execution, download_derivatives function)
- Trend: Efficient (streamlined execution pattern)

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v1.1]: Subject IDs kept as-is from API (no "sub-" prefix transformation)
- [v1.1]: on_bids() auto-fetches pending handles for reduced friction
- [v1.2 research]: Separate code paths for embedded vs OpenNeuroDerivatives sources
- [09-01]: Closure pattern for session cache (avoids namespace lock issues)
- [09-01]: 30 req/min GitHub throttle (50% margin under 60/hr limit)
- [09-01]: Parse only ds######-{fmriprep|mriqc|fitlins} repos
- [09-02]: Embedded derivatives take precedence over GitHub when same pipeline in both
- [09-02]: Cache key includes sources parameter for granular caching
- [10-02]: Default bucket "openneuro.org" for backward compatibility
- [10-02]: Bucket probe caching via .discovery_cache
- [10-02]: Error messages truncated to 80 chars in verbose fallback
- [10-01]: Space regex pattern `_space-([A-Za-z0-9]+)` for BIDS extraction
- [10-01]: No T1w inference from files without space entity (BIDS convention)
- [10-01]: Sample first 2-3 subjects for efficient space discovery
- [11-01]: Space matching is exact (not prefix) to avoid unexpected results
- [11-01]: Native space files (no _space- entity) always included in space filtering
- [11-01]: Metadata files (no clear suffix) always included in suffix filtering
- [11-01]: Derivative cache path: {cache}/{dataset}/derivatives/{pipeline}/

### Pending Todos

None yet.

### Blockers/Concerns

- GitHub API rate limit: 60/hr unauthenticated. **MITIGATED** - Session caching implemented in 09-01.
- S3 bucket access: `s3://openneuro-derivatives/` may have ListObjectsV2 issues (per Neurostars). **ADDRESSED** - .probe_s3_bucket() with test_path parameter implemented in 10-02.

## Session Continuity

Last session: 2026-01-23
Stopped at: Completed 11-01-PLAN.md
Resume file: None

---
*State initialized: 2026-01-22*
*v1.2 roadmap added: 2026-01-23*
*09-01 completed: 2026-01-23*
*09-02 completed: 2026-01-23*
*10-02 completed: 2026-01-23*
*10-01 completed: 2026-01-23*
*11-01 completed: 2026-01-23*
