# Architecture Research

**Domain:** R data access packages for remote repositories
**Project:** openneuro R package
**Researched:** 2026-01-20
**Overall Confidence:** HIGH (patterns well-documented across ecosystem)

## Executive Summary

The proposed 3-layer architecture (GraphQL client, download backends, cache/handle) aligns well with established R data access package patterns. Research confirms this is the standard approach used by pins, googledrive, bigrquery, arrow, and similar packages. The key insight is that successful R data access packages share a common architectural DNA:

1. **Client layer** handles API communication (authentication, requests, response parsing)
2. **Backend layer** abstracts multiple retrieval mechanisms behind a common interface
3. **Cache/handle layer** provides lazy references and local persistence

The proposed design validates against all examined reference packages. Build order should follow dependency chains: client first (no dependencies), then cache infrastructure (needed by backends), then backends (need client + cache), then handle (orchestrates all).

---

## Common Patterns in R Data Access Packages

### 1. The Board/Client Pattern (pins, googledrive, bigrquery)

**Pattern:** A central "client" or "board" object encapsulates connection configuration.

| Package | Client Object | Purpose |
|---------|---------------|---------|
| [pins](https://pins.rstudio.com/) | `board_*()` functions | Encapsulates storage backend |
| [googledrive](https://googledrive.tidyverse.org/) | Implicit (via auth) | Manages Google credentials |
| [bigrquery](https://bigrquery.r-dbi.org/) | `bq_project()` | BigQuery project/dataset refs |
| [ghql](https://docs.ropensci.org/ghql/) | `GraphqlClient$new()` | GraphQL endpoint + headers |

**Validation:** The proposed `on_client()` function fits this pattern. Using a simple list with class rather than R6 is appropriate given the client's simplicity (just URL + token).

### 2. The Three-Level Abstraction (bigrquery, httr2)

**Pattern:** Packages expose multiple abstraction levels.

From [bigrquery documentation](https://bigrquery.r-dbi.org/):
1. **Low-level API** - Thin wrappers over REST API (`bq_*` functions)
2. **DBI interface** - Database-style queries
3. **dplyr interface** - Familiar tidyverse verbs

From [httr2 wrapping APIs guide](https://httr2.r-lib.org/articles/wrapping-apis.html):
1. **Base request function** - Handles auth, errors, rate limiting
2. **Intermediate wrapper** - Translates endpoints to functions
3. **User-facing functions** - Domain-specific interfaces

**Validation:** The proposed architecture follows this:
- Layer A (GraphQL) = Low-level + intermediate
- Layer B (Backends) = Implementation detail
- Layer C (Handle) = User-facing orchestration

### 3. The Dribble/Tibble-First Pattern (googledrive, tidyverse)

**Pattern:** Everything returns tibbles with list-columns for nested data.

googledrive's "dribble" (Drive tibble) is the canonical example:
- One row per file
- Nested metadata in list-columns
- Composes with dplyr/tidyr

**Validation:** The proposed design specifies tibble returns throughout (`on_search()`, `on_snapshots()`, `on_files()`). This is correct and aligns with ecosystem expectations.

### 4. The Lazy Handle Pattern (arrow, dbplyr, targets)

**Pattern:** Create references that defer computation until materialization.

| Package | Handle | Materialization |
|---------|--------|-----------------|
| [arrow](https://arrow.apache.org/docs/r/) | `Dataset` | `collect()` |
| [dbplyr](https://dbplyr.tidyverse.org/) | lazy query | `collect()` |
| [dtplyr](https://dtplyr.tidyverse.org/) | `lazy_dt()` | `as_tibble()` |
| [targets](https://books.ropensci.org/targets/) | target def | build execution |

**Validation:** The proposed `on_handle()` -> `on_fetch()` -> `on_path()` pattern exactly matches this. The handle is lazy (no download), `on_fetch()` materializes, `on_path()` returns the local path.

### 5. The Pluggable Backend Pattern (pins, arrow, bigrquery)

**Pattern:** S3 method dispatch enables swappable backends.

pins supports multiple boards (`board_s3()`, `board_azure()`, `board_gcs()`) through the same `pin_read()`/`pin_write()` interface. Internally, S3 dispatch routes to backend-specific methods.

bigrquery supports JSON or Arrow data formats via the `api` argument, with automatic selection based on available dependencies.

**Validation:** The proposed backend system (`datalad`, `s3`, `https` with `auto` selection) follows this pattern. Using a `backend` argument with switch dispatch is standard practice.

### 6. The Cache-Aside Pattern (pins, googledrive, R.cache)

**Pattern:** Check cache first, fetch on miss, cache result.

From [pins documentation](https://cran.r-project.org/web/packages/pins/pins.pdf):
- Every board requires a local cache
- Environment variables control cache location (`PINS_CACHE_DIR` or `R_USER_CACHE_DIR`)
- Cache avoids downloading files multiple times

From [R Packages book](https://r-pkgs.org/data.html):
- Use `tools::R_user_dir()` for user-specific data
- Keep sizes small by default
- Actively manage contents (remove outdated material)

**Validation:** The proposed cache design (deterministic paths via rappdirs, manifest tracking, lock files) is correct. The `OPENNEURO_CACHE` environment variable override matches ecosystem conventions.

---

## Proposed Architecture Validation

The proposed 3-layer architecture from DESIGN_NOTES_PART1.md is **validated** as following established patterns.

### Layer A: GraphQL Client - VALIDATED

**Proposed:**
- `on_client()` stores endpoint + auth
- `on_query()` executes raw GraphQL
- `on_search()`, `on_dataset()`, `on_snapshots()`, `on_files()` are typed helpers
- External `.gql` documents in `inst/graphql/`

**Validation against patterns:**
- Matches ghql's client pattern (connection object + query method)
- External query documents match httr2's recommendation to separate API details from code
- Typed helpers match bigrquery's approach (high-level wrappers over low-level API)
- Using httr2 with retry/backoff is current best practice

**One recommendation:** Consider caching schema introspection results (as proposed in V3 URL resolver) since this is an expensive operation.

### Layer B: Download Backends - VALIDATED

**Proposed:**
- Backend 1: DataLad/git-annex (correctness default)
- Backend 2: S3 sync (speed for bulk)
- Backend 3: HTTPS (universal fallback)
- Auto-selection based on CLI availability

**Validation against patterns:**
- Matches pins' board pattern (different backends, same interface)
- Matches bigrquery's API format selection (auto-select based on dependencies)
- Auto-detection via `Sys.which()` is standard (e.g., httr2's optional curl features)

**Important consideration:** Backend ordering (DataLad -> S3 -> HTTPS) is correct for the domain. DataLad provides correctness guarantees (checksums, git-annex integrity) that S3 sync does not. For neuroimaging data where reproducibility matters, correctness-first is the right default.

### Layer C: Cache + Handle - VALIDATED

**Proposed:**
- `on_handle()` creates lazy reference
- `on_fetch()` materializes download
- `on_path()` returns filesystem path
- Manifest tracks download state
- Lock files prevent concurrent corruption

**Validation against patterns:**
- Lazy handle exactly matches arrow/dbplyr/targets patterns
- Manifest-tracked cache exceeds most packages (pins doesn't track this deeply)
- Lock files for concurrency are appropriate for potentially long downloads

**Recommendation:** Consider exposing cache metadata more prominently. The manifest is valuable for reproducibility - users should be able to query "when was this downloaded, via which backend, is it complete?"

---

## Component Boundaries

### Layer A: GraphQL Client

**Should do:**
- HTTP communication with OpenNeuro API
- Authentication header injection
- Retry with exponential backoff
- GraphQL error extraction and surfacing
- Response parsing to tibbles
- Schema introspection (for URL resolution)

**Should NOT do:**
- File downloads (that's backends)
- Cache management (that's Layer C)
- Backend selection (that's Layer B's auto logic)
- BIDS parsing (out of scope, separate package concern)

**Key interfaces:**
```r
# IN: query string, variables list
# OUT: parsed data (tibble or list)
on_query(client, query, variables)

# IN: search terms
# OUT: tibble of datasets
on_search(text, ...)

# IN: dataset ID, tag
# OUT: tibble of files
on_files(id, tag, ...)
```

### Layer B: Download Backends

**Should do:**
- Execute platform-specific download commands
- Report progress (if backend supports it)
- Handle partial downloads gracefully
- Detect and use resolved URLs when available

**Should NOT do:**
- Decide which backend to use (that's `on_backend_auto()`)
- Manage cache paths (receive path from caller)
- Parse downloaded data (just get bytes to disk)
- Handle authentication (receive from client)

**Key interfaces:**
```r
# IN: handle (with path info), optional file patterns
# OUT: TRUE on success, error on failure
# SIDE EFFECT: files written to cache path
on_backend_datalad(handle, files = NULL)
on_backend_s3(handle)
on_backend_https(handle)
```

### Layer C: Cache + Handle

**Should do:**
- Compute deterministic cache paths
- Manage lock files for concurrency
- Track download state in manifests
- Orchestrate fetch -> backend -> manifest update cycle
- Provide lazy handle that delays download

**Should NOT do:**
- Execute downloads (delegates to backends)
- Know about specific backends (uses generic interface)
- Parse or interpret downloaded files
- Make network requests (uses client for metadata)

**Key interfaces:**
```r
# IN: dataset ID, tag
# OUT: lazy handle object
on_handle(id, tag)

# IN: handle, backend preference
# OUT: handle (invisibly), downloads as side effect
on_fetch(handle, backend = "auto")

# IN: handle
# OUT: filesystem path string
on_path(handle)
```

### Cross-Cutting: URL Resolution

The V3 URL resolver (`on_resolve_urls()`) crosses boundaries:
- Uses Layer A (GraphQL introspection)
- Informs Layer B (provides resolved URLs to backends)
- Called by Layer C during fetch orchestration

This is acceptable - it's a helper that bridges layers, not a layer itself.

---

## Data Flow

### Discovery Flow (Search -> Metadata)

```
User                          Layer A                    OpenNeuro
  |                              |                           |
  |-- on_search("fmri") -------->|                           |
  |                              |-- GraphQL POST ---------->|
  |                              |<-- JSON response ---------|
  |                              |-- parse to tibble         |
  |<-- tibble of datasets -------|                           |
```

### Download Flow (Handle -> Fetch -> Path)

```
User              Layer C              Layer B              Layer A         Filesystem
  |                  |                    |                    |                |
  |-- on_handle() -->|                    |                    |                |
  |<-- handle -------|                    |                    |                |
  |                  |                    |                    |                |
  |-- on_fetch() --->|                    |                    |                |
  |                  |-- check cache ---->|                    |                |
  |                  |<-- miss -----------|                    |                |
  |                  |-- acquire lock --->|                    |                |
  |                  |-- resolve URLs --->|-- introspect ----->|                |
  |                  |<-- urls -----------|<-- fields ---------|                |
  |                  |-- auto-select ---->|                    |                |
  |                  |<-- "datalad" ------|                    |                |
  |                  |-- backend_datalad->|                    |                |
  |                  |                    |-- openneuro CLI -->|-------------->|
  |                  |                    |-- datalad get ---->|-------------->|
  |                  |                    |<-- success --------|                |
  |                  |-- write manifest ->|                    |--------------->|
  |                  |-- release lock --->|                    |                |
  |<-- handle -------|                    |                    |                |
  |                  |                    |                    |                |
  |-- on_path() ---->|                    |                    |                |
  |<-- "/path/..." --|                    |                    |                |
```

### Cache Hit Flow (Fast Path)

```
User              Layer C              Filesystem
  |                  |                    |
  |-- on_fetch() --->|                    |
  |                  |-- check manifest ->|
  |                  |<-- complete = TRUE |
  |<-- handle -------|   (skip download)  |
```

---

## Build Order

Based on component dependencies, recommended build order:

### Phase 1: Foundation (No Internal Dependencies)

**1.1 Package Skeleton**
- DESCRIPTION, NAMESPACE
- Imports declared
- Basic documentation structure

**1.2 Core Client (`client.R`)**
- `on_client()` - creates client object
- No dependencies on other package code

**1.3 GraphQL Base (`graphql.R`)**
- `on_query()` - raw query execution
- `.on_read_gql()` - loads query documents
- Depends on: client.R

**1.4 Utility Functions**
- `utils-cli.R` - CLI detection (`.cli_exists()`)
- `utils-tidy.R` - tibble helpers
- No dependencies on other package code

**Rationale:** These are leaves in the dependency graph. Everything else builds on them.

### Phase 2: API Layer (Depends on Phase 1)

**2.1 Query Documents**
- `inst/graphql/*.gql` files
- Static files, no R code dependencies

**2.2 Typed API Helpers**
- `api_search.R` - `on_search()`
- `api_dataset.R` - `on_dataset()`, `on_snapshots()`, `on_files()`
- Depends on: graphql.R, utils-tidy.R

**2.3 Authentication**
- `auth.R` - `on_login()`, credential chain
- Depends on: client.R

**Rationale:** API layer needs GraphQL infrastructure. Can be tested against real OpenNeuro with mocked auth.

### Phase 3: Cache Infrastructure (Depends on Phase 1)

**3.1 Cache Utilities**
- `cache.R` - paths, locks, manifest read/write
- `on_cache_dir()`, `.on_cache_path()`, `.on_with_lock()`
- Depends on: fs, rappdirs (external only)

**Rationale:** Cache is needed by both backends and handles. Building it before backends allows backend tests to use real cache.

### Phase 4: Backend Layer (Depends on Phases 1, 2, 3)

**4.1 URL Resolver**
- `resolve_urls.R` - schema introspection, URL extraction
- Depends on: graphql.R (for introspection queries)

**4.2 HTTPS Backend**
- `backend_https.R` - download via HTTP, resolve first
- Depends on: cache.R (for manifest), resolve_urls.R

**4.3 S3 Backend**
- `backend_s3.R` - aws CLI sync
- Depends on: cache.R, resolve_urls.R, utils-cli.R

**4.4 DataLad Backend**
- `backend_datalad.R` - openneuro CLI + datalad/git-annex
- Depends on: cache.R, utils-cli.R

**4.5 Auto Selection**
- `backend_auto.R` - `on_backend_auto()`, `on_backend_fetch()`
- Depends on: all backends, utils-cli.R

**Rationale:** Backends need cache for manifest. URL resolver needs GraphQL. Auto-selection needs all backends. HTTPS is easiest to test (no CLI deps), so build first.

### Phase 5: Handle Layer (Depends on All Previous)

**5.1 Handle Implementation**
- `handle.R` - `on_handle()`, `on_fetch()`, `on_path()`
- Depends on: cache.R, backend_auto.R

**Rationale:** Handle orchestrates everything. Must be built last.

### Phase 6: Polish (Integration)

**6.1 Doctor Function**
- `on_doctor()` - dependency checker
- Depends on: utils-cli.R, client.R

**6.2 Vignettes**
- Getting started, targets integration
- Depends on: working package

**6.3 BIDS Helper (Optional)**
- `on_bids()` - lightweight BIDS descriptor
- Depends on: handle.R
- Consider: May defer to bidsr package

---

## Integration Points

### External CLI Tools

| Tool | Used By | Required? | Detection |
|------|---------|-----------|-----------|
| `openneuro` CLI | DataLad backend | For initial clone | `Sys.which("openneuro")` |
| `datalad` | DataLad backend | For `get` | `Sys.which("datalad")` |
| `git-annex` | DataLad backend | Fallback for `get` | `Sys.which("git-annex")` |
| `aws` | S3 backend | For `s3 sync` | `Sys.which("aws")` |

**Integration pattern:**
```r
.run <- function(cmd, args, ...) {
  system2(cmd, args, stdout = TRUE, stderr = TRUE)
}
```

### targets Pipeline Integration

The proposed `tar_openneuro()` helper should:
1. Return `targets::tar_target(..., format = "file")`
2. Track the cache path as the target output
3. Invalidate when snapshot tag changes

**Integration point:** targets uses file modification time for cache invalidation. The manifest's `fetched_at` timestamp can guide this, but the actual invalidation should be driven by dataset version changes (tag).

### BIDS Ecosystem

The proposed `on_bids()` function should:
- Return a lightweight descriptor (not full BIDS parsing)
- Integrate with bidsr package for detailed parsing
- Avoid duplicating BIDS validation (defer to bids-validator)

**Recommendation:** `on_bids()` should return a simple S3 object with paths to key BIDS files (dataset_description.json, participants.tsv), not attempt to parse the full BIDS structure. Let users compose with bidsr for detailed work.

### Credential Stores

Authentication priority (from DESIGN_NOTES_PART1.md):
1. Explicit: `on_login(api_key = ...)`
2. Environment: `OPENNEURO_API_KEY`, `OPENNEURO_TOKEN`
3. keyring: `keyring::key_get("openneuro", ...)`

This follows [httr2's secret management recommendations](https://httr2.r-lib.org/articles/wrapping-apis.html) - support multiple sources with clear priority.

---

## Key Architectural Decisions Validated

| Decision | Validation |
|----------|------------|
| S3 class (list + class) for client | Appropriate for simple objects; R6 overkill here |
| S3 dispatch for backends | Standard pattern (pins, bigrquery) |
| External .gql documents | Matches httr2 recommendation for API separation |
| Manifest-tracked cache | Exceeds typical R packages; appropriate for reproducibility domain |
| DataLad-first default | Correct for neuroimaging (integrity > speed) |
| Handle -> Fetch -> Path | Matches lazy evaluation patterns (arrow, dbplyr, targets) |
| Tibble returns throughout | Matches tidyverse ecosystem expectations |

---

## Risks and Mitigations

### Risk 1: External CLI Dependency Friction

**Risk:** Users without datalad/git-annex installed get degraded experience.

**Mitigation:**
- HTTPS backend works without any CLI
- `on_doctor()` function diagnoses and recommends
- Clear error messages when backend unavailable
- Vignette on HPC installation

### Risk 2: OpenNeuro Schema Changes

**Risk:** GraphQL API evolves, breaking queries.

**Mitigation:**
- V3 introspection-based URL resolver adapts automatically
- External .gql documents allow quick fixes without code changes
- Schema guard CI workflow detects drift early

### Risk 3: Large Dataset Performance

**Risk:** Neuroimaging datasets can be 100GB+; naive downloads fail.

**Mitigation:**
- DataLad backend supports selective `files = ...` retrieval
- S3 backend uses streaming sync
- Cache prevents re-downloads
- Manifest tracks partial completion

---

## Sources

### Authoritative (HIGH confidence)

- [httr2 Wrapping APIs Guide](https://httr2.r-lib.org/articles/wrapping-apis.html) - API client architecture patterns
- [pins Package Documentation](https://pins.rstudio.com/) - Board/cache architecture
- [bigrquery Documentation](https://bigrquery.r-dbi.org/) - Three-level abstraction pattern
- [arrow R Package](https://arrow.apache.org/docs/r/) - Lazy Dataset pattern
- [R Packages Book - Data](https://r-pkgs.org/data.html) - Cache location best practices
- [targets Design Specification](https://books.ropensci.org/targets-design/) - Pipeline integration patterns
- [ghql Documentation](https://docs.ropensci.org/ghql/) - R GraphQL client patterns

### Supporting (MEDIUM confidence)

- [googledrive Package](https://googledrive.tidyverse.org/) - Dribble pattern, auth design
- [Advanced R - S3](https://adv-r.hadley.nz/s3.html) - S3 dispatch patterns
- [dbplyr lazy evaluation](https://smithjd.github.io/sql-pet/chapter-lazy-evaluation-queries.html) - Lazy query patterns
- [GenomicDataCommons](https://rdrr.io/bioc/GenomicDataCommons/man/manifest.html) - Manifest file patterns

### Domain-Specific

- [BIDS Specification](https://bids-specification.readthedocs.io/en/stable/) - Neuroimaging data structure
- [bidsr Package](https://cran.r-project.org/web/packages/bidsr/index.html) - R BIDS parsing
