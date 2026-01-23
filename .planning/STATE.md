# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-22)

**Core value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.
**Current focus:** Planning next milestone

## Current Position

Phase: 8 of 8 complete
Plan: All plans complete
Status: Ready for next milestone
Last activity: 2026-01-22 — v1.1 milestone archived

Progress: [====================] 100% (16/16 plans across v1.0 + v1.1)

## Performance Metrics

**v1.0 Summary:**
- Total plans completed: 13
- Total phases: 5
- R CMD check: 0 errors, 0 warnings, 0 notes
- Tests: 375 passing
- Exports: 13 public functions

**v1.1 Summary:**
- Phases: 3 (phases 6-8)
- Plans completed: 3 (06-01, 07-01, 08-01)
- R CMD check: 0 errors, 0 warnings, 0 notes
- Tests: 495 passing (+120 new from v1.0)
- Exports: 17 public functions (+4: on_subjects, regex, on_bids)

## Accumulated Context

### Decisions

All decisions logged in PROJECT.md Key Decisions table.

### Pending Todos

None.

### Blockers/Concerns

- **Search API unavailable:** OpenNeuro search endpoint returns null for all queries. Modality filter works as alternative.

## Session Continuity

Last session: 2026-01-22
Stopped at: v1.1 milestone archived
Resume file: None

## Deliverables Index

See archived milestones:
- `.planning/milestones/v1.0-ROADMAP.md` for v1.0 deliverables
- `.planning/milestones/v1.1-ROADMAP.md` for v1.1 deliverables

**v1.0 Public API:**
- Discovery: `on_client()`, `on_search()`, `on_dataset()`, `on_snapshots()`, `on_files()`
- Download: `on_download()`
- Cache: `on_cache_list()`, `on_cache_info()`, `on_cache_clear()`
- Handle: `on_handle()`, `on_fetch()`, `on_path()`
- Utility: `on_doctor()`

**v1.1 Public API:**
- Subject Discovery: `on_subjects()`
- Download Filtering: `on_download(..., subjects=, include_derivatives=)`
- Pattern Matching: `regex()`
- BIDS Bridge: `on_bids()`

## Milestone History

- v1.0 MVP - Shipped 2026-01-22 (5 phases, 13 plans)
- v1.1 BIDS Integration - Shipped 2026-01-22 (3 phases, 3 plans)

## Next Steps

Both milestones complete and archived. Ready for:
- `/gsd:new-milestone` — start next milestone cycle
- CRAN submission preparation
- Documentation improvements
