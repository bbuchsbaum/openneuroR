# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-20)

**Core value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.
**Current focus:** Phase 3 - Caching Layer

## Current Position

Phase: 3 of 5 (Caching Layer)
Plan: 2 of 2 in current phase
Status: Phase complete
Last activity: 2026-01-21 - Completed 03-02-PLAN.md

Progress: [######----] 60%

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: ~6m
- Total execution time: ~39 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 2/2 | 11m 23s | 5m 42s |
| 2 | 2/2 | ~23m | ~12m |
| 3 | 2/2 | 6m | 3m |

**Recent Trend:**
- Last 5 plans: 02-01 (8m), 02-02 (~15m), 03-01 (2m), 03-02 (4m)
- Trend: Fast execution for infrastructure setup tasks

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
| tools::R_user_dir for cache | 03-01 | CRAN-compliant, platform-appropriate |
| Atomic manifest writes | 03-01 | Prevent partial/corrupt manifests |
| Pretty JSON manifests | 03-01 | Human-readable for debugging |
| Dual validation for cache skip | 03-02 | Manifest entry AND file existence check |
| use_cache=TRUE default | 03-02 | Cache is opt-out, most users want caching |
| Interactive confirm for clear | 03-02 | Safety for destructive operations |

### Pending Todos

None yet.

### Blockers/Concerns

- **Search API unavailable:** OpenNeuro search endpoint returns null for all queries. Modality filter works as alternative.

## Session Continuity

Last session: 2026-01-21
Stopped at: Completed 03-02-PLAN.md (Phase 3 complete)
Resume file: None

## Deliverables Index

| Plan | Summary | Key Exports |
|------|---------|-------------|
| 01-01 | .planning/phases/01-foundation-discovery/01-01-SUMMARY.md | on_client(), on_request() |
| 01-02 | .planning/phases/01-foundation-discovery/01-02-SUMMARY.md | on_search(), on_dataset(), on_snapshots(), on_files() |
| 02-01 | .planning/phases/02-download-engine/02-01-SUMMARY.md | .construct_download_url(), .download_single_file(), .list_all_files() |
| 02-02 | .planning/phases/02-download-engine/02-02-SUMMARY.md | on_download() |
| 03-01 | .planning/phases/03-caching-layer/03-01-SUMMARY.md | .on_cache_root(), .on_dataset_cache_path(), .on_file_cache_path(), .read_manifest(), .write_manifest() |
| 03-02 | .planning/phases/03-caching-layer/03-02-SUMMARY.md | on_cache_list(), on_cache_info(), on_cache_clear() |

## Phase Completion Status

- [x] Phase 1: Foundation + Discovery (2 plans)
- [x] Phase 2: Download Engine (2 plans)
- [x] Phase 3: Caching Layer (2 plans)
- [ ] Phase 4: Backends + Handle (TBD plans)
- [ ] Phase 5: Infrastructure (TBD plans)
