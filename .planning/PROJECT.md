# openneuro

## What This Is

An R package for programmatic access to OpenNeuro — the largest open repository of neuroimaging data. Provides search, metadata queries, multi-backend downloading with smart caching, and BIDS-aware data access via bidser integration. Designed to be the best way to access OpenNeuro from any language, beating Python alternatives in API ergonomics, download reliability, and cache intelligence.

## Core Value

Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works — no manual CLI commands, no re-downloads, no backend headaches.

## Requirements

### Validated

- ✓ Search datasets by text query, returning tidy tibbles — v1.0
- ✓ Query dataset metadata (name, created, updated, public status) — v1.0
- ✓ List snapshots for a dataset with tags and timestamps — v1.0
- ✓ List files within a snapshot (filename, size, annexed status) — v1.0
- ✓ Create lazy handles to dataset snapshots — v1.0
- ✓ Fetch data with automatic backend selection (DataLad → S3 → HTTPS) — v1.0
- ✓ Cache downloads locally with manifest tracking — v1.0
- ✓ Support DataLad/git-annex backend for correctness + partial retrieval — v1.0
- ✓ Support S3 backend for bulk speed (anonymous, --no-sign-request) — v1.0
- ✓ Support HTTPS backend as universal fallback — v1.0
- ✓ Resolve URLs from GraphQL schema before probing (metadata-first) — v1.0
- ✓ Return local filesystem path for fetched datasets — v1.0
- ✓ Query subjects pre-download: `on_subjects(dataset_id)` from OpenNeuro API — v1.1
- ✓ Subject subsetting: `on_download(..., subjects=)` for partial downloads — v1.1
- ✓ Regex pattern matching for subject filtering via `regex()` helper — v1.1
- ✓ Bridge to bidser: `on_bids(handle)` returns `bids_project` object — v1.1
- ✓ bidser as optional Suggests dependency with graceful fallback — v1.1

### Active

(None — ready for next milestone planning)

### Out of Scope

- OAuth/social login — API key + bearer token sufficient for v1
- Upload/write operations — read-only access for v1
- BIDS validation — separate concern, can compose with other packages
- Real-time notifications — not needed for data access
- Mobile/GUI — CLI/programmatic access only
- Offline search index — high complexity, defer indefinitely

## Context

Shipped v1.1 with 3,781 LOC R.
Tech stack: httr2, tibble, dplyr, rlang, cli, fs, processx.
Backend CLIs: DataLad/OpenNeuro CLI optional; AWS CLI optional; HTTPS always available.

R CMD check: 0 errors, 0 warnings, 0 notes.
Test suite: 495 tests passing with httptest2 mocking.

**Optional integrations:**
- bidser package (github.com/bbuchsbaum/bidser) for BIDS-aware data access
- stringi for natural sorting of subject IDs

**Known issues:**
- Search API unavailable: OpenNeuro search endpoint returns null for all queries. Modality filter works as alternative.

## Constraints

- **Tech stack**: R package, CRAN-compatible, tidyverse-aligned (tibbles, pipes)
- **Dependencies**: httr2, tibble, dplyr, tidyr, rlang, cli, fs, processx
- **Suggests**: bidser, stringi (optional enhancements)
- **Backend CLIs**: DataLad/OpenNeuro CLI optional; AWS CLI optional; HTTPS always available
- **Target audience**: R neuroimaging community

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| `on_*` function prefix | Discoverability via autocomplete, brevity vs `openneuro_*` | ✓ Good |
| DataLad-first backend | OpenNeuro recommends DataLad for correctness + provenance | ✓ Good |
| GraphQL in `.gql` files | Schema changes only require updating query docs, not R code | ✓ Good |
| Metadata-first URL resolution | Introspect schema for URL fields before blind probing | ✓ Good |
| Manifest-tracked cache | Know what was downloaded, when, how — reproducibility | ✓ Good |
| httr2 direct (not ghql) | Simpler, fewer dependencies | ✓ Good |
| S3 class (not R6) for handles | Follows tidyverse patterns | ✓ Good |
| httptest2 for test mocking | Better httr2 integration than vcr/webmockr | ✓ Good |
| 10 MB resume threshold | Avoid overhead for small files | ✓ Good |
| tools::R_user_dir for cache | CRAN-compliant, platform-appropriate | ✓ Good |
| processx for CLI execution | Robust timeout, error handling, no shell | ✓ Good |
| DataLad > S3 > HTTPS priority | DataLad has integrity, S3 is fast, HTTPS fallback | ✓ Good |
| bidser as Suggests | Optional dependency for BIDS integration | ✓ Good |
| Subject IDs kept as-is from API | API returns ID portion without "sub-" prefix | ✓ Good |
| Natural sorting via stringi | With base R fallback for environments without stringi | ✓ Good |
| regex() returns S3 class | Explicit type detection vs metacharacter inference | ✓ Good |
| Auto-anchor regex patterns | Full match semantics for subject filtering | ✓ Good |
| Root files always included | dataset_description.json, README bypass subject filter | ✓ Good |
| on_bids() auto-fetches pending handles | Reduces friction for users | ✓ Good |

---
*Last updated: 2026-01-22 after v1.1 milestone complete*
