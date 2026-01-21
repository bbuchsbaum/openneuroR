# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-20)

**Core value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.
**Current focus:** Phase 5 - Infrastructure

## Current Position

Phase: 5 of 5 (Infrastructure)
Plan: 1 of 3 in current phase
Status: In progress
Last activity: 2026-01-21 - Completed 05-01-PLAN.md

Progress: [###########-] 92% (11/12 plans complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 11
- Average duration: ~5m
- Total execution time: ~56 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 2/2 | 11m 23s | 5m 42s |
| 2 | 2/2 | ~23m | ~12m |
| 3 | 2/2 | 6m | 3m |
| 4 | 4/4 | ~10m | ~2m 30s |
| 5 | 1/3 | 7m | 7m |

**Recent Trend:**
- Last 5 plans: 04-03 (~3m), 04-04 (~3m), 05-01 (7m)
- Trend: Testing setup takes longer due to recording mocks

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
| Clone timeout 300s | 04-02 | 5 min sufficient for metadata clone |
| Get timeout 1800s default | 04-02 | 30 min default, configurable for large datasets |
| openneuro_backend_error class | 04-02 | Enables fallback chain in dispatcher |
| processx for CLI execution | 04-01 | Robust timeout, error handling, no shell |
| Session-cached detection | 04-01 | Avoid repeated Sys.which() calls |
| AWS CLI path fallback | 04-01 | Check common paths if not in PATH |
| DataLad > S3 > HTTPS priority | 04-03 | DataLad has integrity, S3 is fast |
| NULL signal for HTTPS fallback | 04-03 | Clean separation of dispatch vs HTTPS |
| Recursive fallback chain | 04-03 | Simple, handles any fallback depth |
| S3 class for handles | 04-04 | Follows tidyverse conventions |
| Copy semantics documented | 04-04 | Prevents common pitfall |
| httptest2 over vcr/webmockr | 05-01 | Better httr2 integration |
| with_mock_dir pattern | 05-01 | Auto-record if missing, replay if present |

### Pending Todos

None yet.

### Blockers/Concerns

- **Search API unavailable:** OpenNeuro search endpoint returns null for all queries. Modality filter works as alternative.

## Session Continuity

Last session: 2026-01-21
Stopped at: Completed 05-01-PLAN.md
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
| 04-01 | .planning/phases/04-backends-handle/04-01-SUMMARY.md | .backend_available(), .backend_status(), .find_aws_cli(), .download_s3() |
| 04-02 | .planning/phases/04-backends-handle/04-02-SUMMARY.md | .datalad_action(), .download_datalad() |
| 04-03 | .planning/phases/04-backends-handle/04-03-SUMMARY.md | .select_backend(), .download_with_backend(), on_download(backend=) |
| 04-04 | .planning/phases/04-backends-handle/04-04-SUMMARY.md | on_handle(), on_fetch(), on_path() |
| 05-01 | .planning/phases/05-infrastructure/05-01-SUMMARY.md | test infrastructure, httptest2 mocks |

## Phase Completion Status

- [x] Phase 1: Foundation + Discovery (2 plans)
- [x] Phase 2: Download Engine (2 plans)
- [x] Phase 3: Caching Layer (2 plans)
- [x] Phase 4: Backends + Handle (4/4 plans)
- [ ] Phase 5: Infrastructure (1/3 plans)
