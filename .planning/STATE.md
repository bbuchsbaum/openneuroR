# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-22)

**Core value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.
**Current focus:** v1.1 BIDS Integration - Phase 7: Download Filtering

## Current Position

Phase: 6 of 8 (Subject Querying) - COMPLETE
Plan: 1/1 complete
Status: Phase complete
Last activity: 2026-01-22 - Completed 06-01-PLAN.md

Progress: [==============......] 88% (14/16 plans)

## Performance Metrics

**v1.0 Summary:**
- Total plans completed: 13
- Total phases: 5
- R CMD check: 0 errors, 0 warnings, 0 notes
- Tests: 375 passing
- Exports: 13 public functions
- Test coverage: 75.76%

**v1.1 Progress:**
- Phases: 3 (phases 6-8)
- Plans completed: 1 (06-01)
- R CMD check: 0 errors, 0 warnings, 0 notes
- Tests: 391 passing (+16 new)
- Exports: 14 public functions (+1 on_subjects)

## Accumulated Context

### Decisions

All decisions logged in PROJECT.md Key Decisions table.

Recent for v1.1:
- bidser as Suggests (not Imports) - Optional dependency for BIDS integration
- on_subjects() returns tibble - Consistent with existing API patterns
- subjects= parameter in on_download() - Filter at download time, not handle creation
- Subject IDs kept as-is from API (e.g., "01") - API returns ID portion without "sub-" prefix
- Natural sorting via stringi::stri_sort - With base R fallback for environments without stringi

### Pending Todos

None.

### Blockers/Concerns

- **Search API unavailable:** OpenNeuro search endpoint returns null for all queries. Modality filter works as alternative.

## Session Continuity

Last session: 2026-01-22
Stopped at: Completed 06-01-PLAN.md
Resume file: None

## Deliverables Index

See `.planning/milestones/v1.0-ROADMAP.md` for v1.0 deliverables.

**v1.0 Public API:**
- Discovery: `on_client()`, `on_search()`, `on_dataset()`, `on_snapshots()`, `on_files()`
- Download: `on_download()`
- Cache: `on_cache_list()`, `on_cache_info()`, `on_cache_clear()`
- Handle: `on_handle()`, `on_fetch()`, `on_path()`
- Utility: `on_doctor()`

**v1.1 Delivered API:**
- Subject Discovery: `on_subjects()` - SHIPPED in 06-01

**v1.1 Remaining:**
- Download Filtering: `on_download(..., subjects=)`
- BIDS Bridge: `on_bids()`

## Milestone History

- v1.0 MVP - Shipped 2026-01-22 (5 phases, 13 plans)
- v1.1 BIDS Integration - In progress (phases 6-8)

## Next Steps

Plan phase 7: Download filtering with subjects= parameter
