# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-22)

**Core value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.
**Current focus:** v1.1 BIDS Integration - COMPLETE

## Current Position

Phase: 8 of 8 (BIDS Bridge) - COMPLETE
Plan: 1/1 complete
Status: v1.1 COMPLETE
Last activity: 2026-01-22 - Completed 08-01-PLAN.md

Progress: [====================] 100% (16/16 plans)

## Performance Metrics

**v1.0 Summary:**
- Total plans completed: 13
- Total phases: 5
- R CMD check: 0 errors, 0 warnings, 0 notes
- Tests: 375 passing
- Exports: 13 public functions
- Test coverage: 75.76%

**v1.1 Summary:**
- Phases: 3 (phases 6-8)
- Plans completed: 3 (06-01, 07-01, 08-01)
- R CMD check: 0 errors, 0 warnings, 0 notes
- Tests: 495 passing (+120 new from v1.0)
- Exports: 17 public functions (+4: on_subjects, regex, on_bids, include_derivatives param)

## Accumulated Context

### Decisions

All decisions logged in PROJECT.md Key Decisions table.

Recent for v1.1:
- bidser as Suggests (not Imports) - Optional dependency for BIDS integration
- on_subjects() returns tibble - Consistent with existing API patterns
- subjects= parameter in on_download() - Filter at download time, not handle creation
- Subject IDs kept as-is from API (e.g., "01") - API returns ID portion without "sub-" prefix
- Natural sorting via stringi::stri_sort - With base R fallback for environments without stringi
- regex() returns S3 class (on_regex) - Explicit type detection vs metacharacter inference
- Auto-anchor regex patterns - Full match semantics for subject filtering
- Root files always included - dataset_description.json, README, etc. bypass subject filter
- on_bids() returns bids_project directly - Let bidser's API shine through
- Auto-fetch pending handles - Reduces friction for users

### Pending Todos

None.

### Blockers/Concerns

- **Search API unavailable:** OpenNeuro search endpoint returns null for all queries. Modality filter works as alternative.

## Session Continuity

Last session: 2026-01-22
Stopped at: Completed 08-01-PLAN.md
Resume file: None

## Deliverables Index

See `.planning/milestones/v1.0-ROADMAP.md` for v1.0 deliverables.

**v1.0 Public API:**
- Discovery: `on_client()`, `on_search()`, `on_dataset()`, `on_snapshots()`, `on_files()`
- Download: `on_download()`
- Cache: `on_cache_list()`, `on_cache_info()`, `on_cache_clear()`
- Handle: `on_handle()`, `on_fetch()`, `on_path()`
- Utility: `on_doctor()`

**v1.1 Public API (NEW):**
- Subject Discovery: `on_subjects()` - SHIPPED in 06-01
- Download Filtering: `on_download(..., subjects=, include_derivatives=)` - SHIPPED in 07-01
- Pattern Matching: `regex()` - SHIPPED in 07-01
- BIDS Bridge: `on_bids()` - SHIPPED in 08-01

## Milestone History

- v1.0 MVP - Shipped 2026-01-22 (5 phases, 13 plans)
- v1.1 BIDS Integration - Shipped 2026-01-22 (3 phases, 3 plans)

## Next Steps

v1.1 BIDS Integration milestone is complete. Consider:
- CRAN submission preparation
- Documentation improvements
- Additional convenience functions
- Performance optimizations
