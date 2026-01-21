# Research Summary

**Project:** openneuro - R package for programmatic OpenNeuro access
**Domain:** R API wrapper for neuroimaging data repository
**Researched:** 2026-01-20
**Confidence:** HIGH

## Executive Summary

The openneuro R package is a data access wrapper for OpenNeuro's GraphQL API, targeting neuroimaging researchers who need programmatic access to BIDS-formatted datasets. The 2025 R ecosystem provides mature, well-documented patterns for building such packages. The core stack centers on httr2 for HTTP requests, ghql for GraphQL, and the r-lib ecosystem (cli, rlang, cachem) for infrastructure. Reference packages like pins, googledrive, and bigrquery demonstrate the expected architectural patterns: a client layer for API communication, a backend layer for flexible data retrieval, and a cache/handle layer for lazy references and local persistence.

The recommended approach follows a 3-layer architecture validated against established R package patterns. Layer A (GraphQL client) handles all API communication with retry/backoff and proper error extraction. Layer B (download backends) provides pluggable retrieval via DataLad (default for correctness), S3 sync (speed for bulk), or HTTPS (universal fallback). Layer C (cache + handle) implements the lazy reference pattern from arrow/dbplyr, where `on_handle()` creates references that defer downloads until `on_fetch()` is called. This mirrors how successful data access packages operate: minimize downloads, maximize metadata queries, graceful degradation when optional dependencies are unavailable.

Key risks center on CRAN compliance and large-file handling. CRAN mandates `tools::R_user_dir()` for cache paths (not rappdirs), graceful network failures, and mocked tests. Neuroimaging files can be 100GB+, requiring download resume support, checksum verification, and configurable timeouts far exceeding R's default 60 seconds. The external CLI dependencies (DataLad, AWS CLI) must be optional with clear fallback to HTTPS and helpful installation guidance when missing.

---

## Stack Decisions

The stack is well-defined with high confidence across all components.

**Core technologies:**
- **httr2** (>= 1.2.1): HTTP requests with built-in retry, rate limiting, and OAuth. Modern r-lib standard replacing httr.
- **ghql** (>= 0.1.2): Only CRAN-ready GraphQL client for R. Uses R6 for connection management. Essential for OpenNeuro's GraphQL API.
- **curl** (>= 7.0.0): Low-level downloads with progress bars and resume support. Better than httr2 for multi-GB neuroimaging files.
- **cachem** (>= 1.1.0): Two-tier caching (memory + disk) with automatic LRU eviction. Used by memoise internally.
- **processx** (>= 3.8.0): External CLI execution for DataLad/AWS. Avoids shell quoting issues of system2().
- **cli** (>= 3.6.0): Modern progress bars and user feedback. Integrates with httr2/curl downloads.

**Do not use:** httr (superseded), RCurl (legacy), system2() (unreliable quoting), rappdirs for cache paths (use tools::R_user_dir() for CRAN compliance).

---

## Feature Priorities

**Table Stakes (must have for v1):**
- Automatic caching with cache_prune() - users expect not to re-download
- Progress bars for large downloads - essential for neuroimaging files
- Retry with exponential backoff - httr2 handles this automatically
- Informative errors with cli/rlang - not cryptic HTTP codes
- CRAN-compliant cache location - tools::R_user_dir() only
- Tibble/data.frame output - standard R data structures
- Graceful offline failure - CRAN requires this

**Differentiators (should have):**
- Concurrent multi-file downloads - critical for 100s of subjects, use curl::multi_download()
- Download resumption - essential for large files on unreliable networks
- Basic BIDS metadata parsing - parse dataset_description.json, participants.tsv
- Dataset version/snapshot support - OpenNeuro has versions, expose via API

**Defer to v2+:**
- Lazy evaluation / dplyr-style filtering - high complexity (4-6 weeks)
- Multiple download backend support beyond current three
- RStudio connection pane integration
- Pre-computed search index for offline browsing

---

## Architecture Validation

The proposed 3-layer architecture is **validated** as following established R package patterns observed in pins, googledrive, bigrquery, and arrow.

**Major components:**

1. **Layer A: GraphQL Client** - Handles all API communication. Uses httr2 for HTTP with retry/throttle, ghql for GraphQL queries stored in `inst/graphql/*.gql` files. Returns tibbles. Caches schema introspection.

2. **Layer B: Download Backends** - Pluggable retrieval via S3 dispatch. DataLad backend (default, provides checksums/git-annex integrity), S3 backend (aws s3 sync for bulk), HTTPS backend (universal fallback, no dependencies). Auto-selection based on available CLI tools.

3. **Layer C: Cache + Handle** - Implements lazy reference pattern. `on_handle()` creates reference (no download), `on_fetch()` materializes, `on_path()` returns filesystem path. Manifest-tracked downloads with lock files for concurrency.

**Key patterns validated:**
- Board/client pattern (pins) for connection encapsulation
- Lazy handle pattern (arrow/dbplyr) for deferred execution
- Pluggable backend pattern (pins boards) for flexible retrieval
- Cache-aside pattern with manifest tracking exceeds most R packages

---

## Critical Pitfalls

Top pitfalls to avoid, ordered by severity:

1. **Wrong cache directory (Critical)** - Using rappdirs instead of `tools::R_user_dir("openneuro", "cache")` causes CRAN rejection. Must be correct from day one.

2. **Tests/examples hit real API (Critical)** - CRAN tests run offline. Use vcr/webmockr for HTTP mocking, `\dontrun{}` for examples, skip_on_cran() for integration tests.

3. **No download resume (Critical)** - A 50GB download failing at 45GB and restarting from zero is unacceptable. Use `curl::multi_download(resume = TRUE)`.

4. **Timeout too short (Critical)** - R's default 60-second timeout fails large downloads. Configure proportional to file size, minimum 1 hour for big datasets.

5. **CLI tools assumed installed (Critical)** - DataLad/AWS CLI must be optional with graceful fallback to HTTPS. Check with `Sys.which()`, provide helpful install URLs on missing.

6. **Inadequate error handling (Moderate)** - GraphQL returns HTTP 200 with error payloads. Parse `errors` array, create custom error classes, include request context.

7. **Blocking operations without feedback (Moderate)** - Long downloads need progress bars. Parse DataLad/AWS CLI output for progress, integrate with cli package.

---

## Build Order

Based on dependency analysis, the recommended phase sequence:

### Phase 1: Foundation
**Rationale:** No internal dependencies - leaves in the dependency graph. Everything else builds on these.
**Delivers:** Package skeleton, core client, GraphQL base, utility functions.
**Key files:** DESCRIPTION, client.R, graphql.R, utils-cli.R
**Must avoid:** Wrong cache directory, missing user agent, DESCRIPTION errors.

### Phase 2: API Layer
**Rationale:** API layer needs GraphQL infrastructure from Phase 1.
**Delivers:** Query documents, typed API helpers (on_search, on_dataset, on_files), authentication.
**Uses:** ghql, httr2, tibble
**Must avoid:** GraphQL pagination ignored, API key exposure in function arguments.

### Phase 3: Cache Infrastructure
**Rationale:** Cache is needed by both backends and handles. Build before backends allows backend tests to use real cache.
**Delivers:** Cache paths, locks, manifest read/write, on_cache_dir().
**Uses:** tools::R_user_dir(), fs, jsonlite for manifest
**Must avoid:** Cache size unbounded (add management functions).

### Phase 4: Backend Layer
**Rationale:** Backends need cache for manifest. URL resolver needs GraphQL. Build HTTPS first (no CLI deps), then S3, then DataLad.
**Delivers:** URL resolver, HTTPS/S3/DataLad backends, auto-selection.
**Uses:** curl, processx, AWS CLI, DataLad
**Must avoid:** system2() usage, no timeout for external commands, AWS region issues.

### Phase 5: Handle Layer
**Rationale:** Handle orchestrates everything - must be built last.
**Delivers:** on_handle(), on_fetch(), on_path() - the complete lazy reference interface.
**Implements:** Full fetch flow: check cache -> acquire lock -> select backend -> download -> update manifest.

### Phase 6: Polish
**Rationale:** Integration and documentation after core functionality complete.
**Delivers:** on_doctor() diagnostic function, vignettes, BIDS helper, pkgdown site.
**Must avoid:** Examples/vignettes making API calls, check time too long.

### Phase Ordering Rationale

- **Foundation first** because client and GraphQL are dependencies of everything
- **API before cache** because API queries inform cache design (what metadata to cache)
- **Cache before backends** because backends write to cache
- **HTTPS backend first** because it has no CLI dependencies, easiest to test
- **Handle last** because it orchestrates all other layers
- **Polish last** because vignettes need working package to demonstrate

---

## Key Insights

1. **CRAN compliance is non-negotiable** - Use tools::R_user_dir(), mock all tests, graceful network failures. Get this right from day one or face rejection.

2. **Neuroimaging files are big** - Design for 100GB+ from the start. Resume support, checksums, long timeouts. Test with real-sized files, not toy examples.

3. **External CLI dependencies must be optional** - DataLad-first is correct for reproducibility, but HTTPS must always work. Graceful degradation is essential.

4. **GraphQL errors hide in HTTP 200** - Always parse the `errors` array in GraphQL responses. A successful HTTP status does not mean a successful query.

5. **The lazy handle pattern is the right abstraction** - Match arrow/dbplyr: create references cheap, materialize expensive. Users query metadata without downloading.

6. **Tibbles everywhere** - The neuroimaging R community expects tidyverse-style returns. on_search() returns tibble, not data.frame.

7. **Cache manifest is a differentiator** - Most R packages don't track downloads this deeply. For reproducibility-focused neuroimaging, knowing "when downloaded, via which backend, is it complete" is valuable.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies are CRAN-standard, official r-lib recommendations, verified versions |
| Features | HIGH | Reference packages (pins, googledrive, arrow) document expected patterns clearly |
| Architecture | HIGH | 3-layer design validated against multiple production R packages |
| Pitfalls | HIGH | CRAN policy is explicit; download issues well-documented in R Blog and rOpenSci |

**Overall confidence:** HIGH

### Gaps to Address

- **OpenNeuro rate limits** - Not documented publicly. May need empirical testing during Phase 2 API work.
- **DataLad performance on HPC** - HPC environments vary. May need user testing during Phase 4.
- **Schema evolution** - OpenNeuro GraphQL schema may change. V3 introspection-based resolver helps, but needs monitoring.

---

## Research Flags

**Phases likely needing deeper research during planning:**
- **Phase 4 (Backends):** DataLad integration patterns not well-documented in R ecosystem. May need experimentation.
- **Phase 2 (API):** GraphQL pagination specifics for OpenNeuro need empirical verification.

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Foundation):** Package skeleton and httr2/ghql patterns are well-documented.
- **Phase 3 (Cache):** cachem/fs patterns are standard r-lib.
- **Phase 6 (Polish):** Vignettes/pkgdown are routine.

---

## Sources

### Primary (HIGH confidence)
- [httr2 CRAN](https://cran.r-project.org/web/packages/httr2/) - HTTP patterns, version 1.2.1
- [httr2 Wrapping APIs](https://httr2.r-lib.org/articles/wrapping-apis.html) - API client architecture
- [ghql CRAN](https://cran.r-project.org/web/packages/ghql/) - GraphQL client, version 0.1.2
- [pins Package](https://pins.rstudio.com/) - Board/cache patterns
- [arrow R Package](https://arrow.apache.org/docs/r/) - Lazy Dataset pattern
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html) - Compliance requirements
- [HTTP Testing in R](https://books.ropensci.org/http-testing/) - vcr/webmockr patterns
- [R Packages (2e)](https://r-pkgs.org/) - Package development best practices

### Secondary (MEDIUM confidence)
- [bigrquery Documentation](https://bigrquery.r-dbi.org/) - Three-level abstraction
- [googledrive Package](https://googledrive.tidyverse.org/) - Dribble pattern, auth design
- [curl Package](https://cran.r-project.org/web/packages/curl/) - Download patterns
- [processx Documentation](https://processx.r-lib.org/) - CLI execution

### Domain-Specific
- [OpenNeuro Documentation](https://docs.openneuro.org/) - API architecture
- [BIDS Specification](https://bids-specification.readthedocs.io/) - Data format

---
*Research completed: 2026-01-20*
*Ready for roadmap: yes*
