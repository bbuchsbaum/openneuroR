# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-22)

**Core value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.
**Current focus:** Phase 9 - Discovery Foundation

## Current Position

Phase: 9 of 11 (Discovery Foundation)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-01-23 — Roadmap created for v1.2 milestone

Progress: [=========>..........] 45%
(v1.0 + v1.1 complete: 8 phases / 16 plans; v1.2: 3 phases pending)

## Performance Metrics

**Velocity:**
- Total plans completed: 16
- Average duration: ~15 min (estimated from v1.0/v1.1)
- Total execution time: ~4 hours (v1.0 + v1.1)

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1-5 (v1.0) | 13 | ~3h | ~14 min |
| 6-8 (v1.1) | 3 | ~1h | ~20 min |
| 9-11 (v1.2) | TBD | - | - |

**Recent Trend:**
- Last milestone (v1.1): 3 plans in single session
- Trend: Stable (efficient single-plan phases)

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v1.1]: Subject IDs kept as-is from API (no "sub-" prefix transformation)
- [v1.1]: on_bids() auto-fetches pending handles for reduced friction
- [v1.2 research]: Separate code paths for embedded vs OpenNeuroDerivatives sources

### Pending Todos

None yet.

### Blockers/Concerns

- GitHub API rate limit: 60/hr unauthenticated. Session caching (DISC-04) mitigates this.
- S3 bucket access: `s3://openneuro-derivatives/` may have ListObjectsV2 issues (per Neurostars). Need to test and implement fallback.

## Session Continuity

Last session: 2026-01-23
Stopped at: Roadmap created for v1.2 milestone
Resume file: None

---
*State initialized: 2026-01-22*
*v1.2 roadmap added: 2026-01-23*
