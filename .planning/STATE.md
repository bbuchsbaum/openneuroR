# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-20)

**Core value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.
**Current focus:** Phase 2 Complete - Ready for Phase 3

## Current Position

Phase: 2 of 5 (Download Engine) - COMPLETE
Plan: 2 of 2 in current phase
Status: Phase complete
Last activity: 2026-01-21 - Completed 02-02-PLAN.md

Progress: [####------] 40%

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: ~8m
- Total execution time: ~0.5 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 2/2 | 11m 23s | 5m 42s |
| 2 | 2/2 | ~23m | ~12m |

**Recent Trend:**
- Last 5 plans: 01-01 (4m 15s), 01-02 (7m 8s), 02-01 (8m), 02-02 (~15m)
- Trend: Consistent execution times

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

| Decision | Plan | Rationale |
|----------|------|-----------|
| httr2 direct (not ghql) | 01-01 | Simpler, fewer dependencies |
| External .gql files | 01-01 | Maintainability |
| S3 client class (not R6) | 01-01 | Follows tidyverse patterns |
| search() query for text search | 01-01 | API filterBy.all is Boolean |
| Search API documented as limited | 01-02 | OpenNeuro search endpoint returns null |
| n_subjects column (count) | 01-02 | API returns list of IDs, count more practical |
| not_found_error class | 01-02 | Enables catch-by-class error handling |
| S3 direct URLs over GraphQL urls | 02-01 | Simpler, fewer API calls |
| 10 MB resume threshold | 02-01 | Avoid overhead for small files |
| Atomic download pattern | 02-01 | Prevent partial/corrupt files |
| Regex detection via metacharacters | 02-02 | Simple UX, no explicit flag needed |
| cli-based progress bar | 02-02 | Interactive sessions only |
| dplyr added to Imports | 02-02 | Needed for bind_rows/arrange |

### Pending Todos

None yet.

### Blockers/Concerns

- **Search API unavailable:** OpenNeuro search endpoint returns null for all queries. Modality filter works as alternative.

## Session Continuity

Last session: 2026-01-21
Stopped at: Completed 02-02-PLAN.md (Phase 2 complete)
Resume file: None

## Deliverables Index

| Plan | Summary | Key Exports |
|------|---------|-------------|
| 01-01 | .planning/phases/01-foundation-discovery/01-01-SUMMARY.md | on_client(), on_request() |
| 01-02 | .planning/phases/01-foundation-discovery/01-02-SUMMARY.md | on_search(), on_dataset(), on_snapshots(), on_files() |
| 02-01 | .planning/phases/02-download-engine/02-01-SUMMARY.md | .construct_download_url(), .download_single_file(), .list_all_files() |
| 02-02 | .planning/phases/02-download-engine/02-02-SUMMARY.md | on_download() |

## Phase Completion Status

- [x] Phase 1: Foundation + Discovery (2 plans)
- [x] Phase 2: Download Engine (2 plans)
- [ ] Phase 3: Caching Layer (TBD plans)
- [ ] Phase 4: Backends + Handle (TBD plans)
- [ ] Phase 5: Infrastructure (TBD plans)
