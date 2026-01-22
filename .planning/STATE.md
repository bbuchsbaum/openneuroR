# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-22)

**Core value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.
**Current focus:** v1.1 BIDS Integration - Phase 6: Subject Querying

## Current Position

Phase: 6 of 8 (Subject Querying)
Plan: Ready to plan
Status: Ready to plan
Last activity: 2026-01-22 - Created v1.1 roadmap (phases 6-8)

Progress: [=============.......] 81% (13/16 plans, v1.0 complete)

## Performance Metrics

**v1.0 Summary:**
- Total plans completed: 13
- Total phases: 5
- R CMD check: 0 errors, 0 warnings, 0 notes
- Tests: 375 passing
- Exports: 13 public functions
- Test coverage: 75.76%

**v1.1 Scope:**
- Phases: 3 (phases 6-8)
- Requirements: 12
- Estimated plans: 3

## Accumulated Context

### Decisions

All decisions logged in PROJECT.md Key Decisions table.

Recent for v1.1:
- bidser as Suggests (not Imports) - Optional dependency for BIDS integration
- on_subjects() returns tibble - Consistent with existing API patterns
- subjects= parameter in on_download() - Filter at download time, not handle creation

### Pending Todos

None.

### Blockers/Concerns

- **Search API unavailable:** OpenNeuro search endpoint returns null for all queries. Modality filter works as alternative.

## Session Continuity

Last session: 2026-01-22
Stopped at: Created v1.1 roadmap
Resume file: None

## Deliverables Index

See `.planning/milestones/v1.0-ROADMAP.md` for v1.0 deliverables.

**v1.0 Public API:**
- Discovery: `on_client()`, `on_search()`, `on_dataset()`, `on_snapshots()`, `on_files()`
- Download: `on_download()`
- Cache: `on_cache_list()`, `on_cache_info()`, `on_cache_clear()`
- Handle: `on_handle()`, `on_fetch()`, `on_path()`
- Utility: `on_doctor()`

**v1.1 Planned API:**
- Subject Discovery: `on_subjects()`
- Download Filtering: `on_download(..., subjects=)`
- BIDS Bridge: `on_bids()`

## Milestone History

- v1.0 MVP - Shipped 2026-01-22 (5 phases, 13 plans)
- v1.1 BIDS Integration - In progress (phases 6-8)

## Next Steps

Plan phase 6: `/gsd:plan-phase 6`
