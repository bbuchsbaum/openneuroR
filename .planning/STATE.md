# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-22)

**Core value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.
**Current focus:** Phase 10 - Spaces and S3 Backend

## Current Position

Phase: 10 of 11 (Spaces and S3 Backend)
Plan: 2 of 2 in current phase - PHASE COMPLETE
Status: Phase 10 complete
Last activity: 2026-01-23 - Completed 10-01-PLAN.md (on_spaces function)

Progress: [==============>....] 57%
(v1.0 + v1.1 complete: 8 phases / 16 plans; v1.2: 4/6 plans complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 20
- Average duration: ~13 min
- Total execution time: ~4.4 hours (v1.0 + v1.1 + v1.2 partial)

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1-5 (v1.0) | 13 | ~3h | ~14 min |
| 6-8 (v1.1) | 3 | ~1h | ~20 min |
| 9 (v1.2) | 2/2 | 8min | 4 min |
| 10 (v1.2) | 2/2 | 11min | 5.5 min |

**Recent Trend:**
- Last plan (10-01): 7 min (clean execution, on_spaces function)
- Trend: Stable (efficient execution)

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

### Pending Todos

None yet.

### Blockers/Concerns

- GitHub API rate limit: 60/hr unauthenticated. **MITIGATED** - Session caching implemented in 09-01.
- S3 bucket access: `s3://openneuro-derivatives/` may have ListObjectsV2 issues (per Neurostars). **ADDRESSED** - .probe_s3_bucket() with test_path parameter implemented in 10-02.

## Session Continuity

Last session: 2026-01-23
Stopped at: Completed 10-01-PLAN.md (Phase 10 complete)
Resume file: None

---
*State initialized: 2026-01-22*
*v1.2 roadmap added: 2026-01-23*
*09-01 completed: 2026-01-23*
*09-02 completed: 2026-01-23*
*10-02 completed: 2026-01-23*
*10-01 completed: 2026-01-23*
