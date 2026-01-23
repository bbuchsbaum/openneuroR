# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-22)

**Core value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.
**Current focus:** Phase 9 - Discovery Foundation

## Current Position

Phase: 9 of 11 (Discovery Foundation)
Plan: 2 of 2 in current phase - PHASE COMPLETE
Status: Phase 9 complete
Last activity: 2026-01-23 — Completed 09-02-PLAN.md (on_derivatives function)

Progress: [============>.......] 50%
(v1.0 + v1.1 complete: 8 phases / 16 plans; v1.2: 2/6 plans complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 18
- Average duration: ~14 min
- Total execution time: ~4.2 hours (v1.0 + v1.1 + v1.2 phase 9)

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1-5 (v1.0) | 13 | ~3h | ~14 min |
| 6-8 (v1.1) | 3 | ~1h | ~20 min |
| 9 (v1.2) | 2/2 | 8min | 4 min |

**Recent Trend:**
- Last plan (09-02): 4 min (clean execution, clear spec)
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

### Pending Todos

None yet.

### Blockers/Concerns

- GitHub API rate limit: 60/hr unauthenticated. **MITIGATED** - Session caching implemented in 09-01.
- S3 bucket access: `s3://openneuro-derivatives/` may have ListObjectsV2 issues (per Neurostars). Need to test and implement fallback.

## Session Continuity

Last session: 2026-01-23
Stopped at: Completed 09-02-PLAN.md (Phase 9 complete)
Resume file: None

---
*State initialized: 2026-01-22*
*v1.2 roadmap added: 2026-01-23*
*09-01 completed: 2026-01-23*
*09-02 completed: 2026-01-23*
