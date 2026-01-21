---
phase: 01-foundation-discovery
plan: 01
subsystem: core
tags: [package-skeleton, graphql, httr2, client]

dependency_graph:
  requires: []
  provides:
    - package-skeleton
    - on_client
    - on_request
    - graphql-queries
  affects:
    - 01-02 (discovery functions will use on_request)
    - all future plans (depend on package structure)

tech_stack:
  added:
    - httr2: HTTP requests with retry/throttle
    - rlang: Error handling, %||% operator
    - cli: User-friendly output
    - tibble: Return format (not yet used)
    - jsonlite: JSON parsing (via httr2)
    - fs: File operations (not yet used)
  patterns:
    - S3 class for client object
    - External .gql files for GraphQL queries
    - httr2 request pipeline with retry/throttle

files:
  created:
    - DESCRIPTION
    - NAMESPACE
    - LICENSE
    - .Rbuildignore
    - R/zzz.R
    - R/client.R
    - R/graphql.R
    - R/utils-response.R
    - inst/graphql/search_datasets.gql
    - inst/graphql/list_datasets.gql
    - inst/graphql/get_dataset.gql
    - inst/graphql/get_snapshots.gql
    - inst/graphql/get_files.gql
    - man/*.Rd (7 files)
  modified: []

decisions:
  - decision: Use httr2 directly instead of ghql
    why: Simpler, fewer dependencies, sufficient for GraphQL POST requests
  - decision: External .gql files in inst/graphql/
    why: Maintainability, easier to update queries without code changes
  - decision: Simple S3 class for client (not R6)
    why: Sufficient for configuration storage, follows tidyverse patterns
  - decision: Use search() query instead of datasets(filterBy)
    why: API introspection revealed filterBy.all expects Boolean, not String

metrics:
  duration: 4m 15s
  completed: 2026-01-21
---

# Phase 01 Plan 01: Package Skeleton and GraphQL Infrastructure Summary

**One-liner:** R package skeleton with httr2-based GraphQL client for OpenNeuro API (on_client, on_request, 5 query files).

## What Was Built

Created the foundational R package structure for the openneuro package:

1. **Package skeleton** - Valid R package with DESCRIPTION, NAMESPACE, LICENSE
2. **Client configuration** - `on_client()` creates client objects with URL and auth token
3. **Request infrastructure** - `on_request()` executes GraphQL queries with retry, throttle, error handling
4. **Query files** - 5 GraphQL queries in inst/graphql/ for search, list, dataset, snapshots, files
5. **Response utilities** - Helper functions for parsing API responses

## Key Implementation Details

### Client Object (R/client.R)
```r
on_client(url = "https://openneuro.org/crn/graphql", token = NULL)
# Returns openneuro_client S3 class with $url and $token
# Token defaults from OPENNEURO_API_KEY env var
```

### Request Function (R/graphql.R)
```r
on_request(query, variables = NULL, client = NULL)
# Builds httr2 request with:
# - Content-Type: application/json
# - User-Agent: openneuro-r/{version}
# - Retry on 429/500/502/503 (3 tries)
# - Throttle: 10 requests/minute
# - Bearer auth if token present
# - GraphQL error detection in response body
```

### GraphQL Queries
| File | Purpose |
|------|---------|
| search_datasets.gql | Search via `search(q: $q)` endpoint |
| list_datasets.gql | List datasets with pagination/modality filter |
| get_dataset.gql | Single dataset by ID |
| get_snapshots.gql | Snapshots for a dataset |
| get_files.gql | Files in a snapshot (with tree param) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed search query schema mismatch**
- **Found during:** Task 2 verification
- **Issue:** RESEARCH.md showed `filterBy: { all: $query }` but API introspection revealed `all` is Boolean, not String
- **Fix:** Created separate `list_datasets.gql` for basic listing, updated `search_datasets.gql` to use `search(q: $q)` endpoint
- **Files modified:** inst/graphql/search_datasets.gql, created inst/graphql/list_datasets.gql
- **Commit:** 4b74228

**2. [Rule 1 - Bug] Fixed stray rlang reference**
- **Found during:** R CMD check
- **Issue:** Line 110 had orphan `rlang` statement causing "undefined global variable" note
- **Fix:** Removed the stray line
- **Files modified:** R/graphql.R
- **Commit:** e28ca95

**3. [Rule 2 - Missing Critical] Added R version dependency**
- **Found during:** R CMD check
- **Issue:** Package uses `|>` pipe syntax requiring R >= 4.1.0, but no dependency declared
- **Fix:** Added `Depends: R (>= 4.1.0)` to DESCRIPTION
- **Files modified:** DESCRIPTION
- **Commit:** e28ca95

**4. [Rule 2 - Missing Critical] Added explicit Author/Maintainer fields**
- **Found during:** R CMD check
- **Issue:** R CMD check requires explicit Author/Maintainer fields
- **Fix:** Added fields derived from Authors@R
- **Files modified:** DESCRIPTION
- **Commit:** e28ca95

## Verification Results

| Check | Result |
|-------|--------|
| Package loads (`devtools::load_all`) | PASS |
| Client works (`on_client()`) | PASS |
| Queries exist (all 5 .gql files) | PASS |
| Request works (hits OpenNeuro API) | PASS |
| R CMD check | 0 errors, 1 warning (Rcheck dir), 3 notes (expected) |

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 99535c7 | chore | Create package skeleton with DESCRIPTION and dependencies |
| 4b74228 | feat | Implement client configuration and GraphQL request infrastructure |
| e28ca95 | fix | Add R version dependency and fix stray reference |

## Next Phase Readiness

**Ready for 01-02:** Yes

**What 01-02 needs from this plan:**
- `on_client()` - Client configuration (done)
- `on_request()` - Query execution (done)
- `.on_read_gql()` - Query file loading (done)
- Response parsing utilities (done)

**Potential blockers:** None identified.

**API discovery notes for next plan:**
- The `datasets()` query accepts `modality: String` filter directly (not via filterBy)
- The `search()` query returns `SearchResult` union type, use `... on Dataset` fragment
- File tree queries use `key` field for subdirectory navigation
