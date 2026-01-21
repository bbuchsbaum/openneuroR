# Feature Landscape: R Data Access Packages

**Domain:** R data access package for OpenNeuro neuroimaging repository
**Researched:** 2026-01-20
**Reference packages:** pins, arrow, googledrive, bigrquery, ghql

## Table Stakes

Features users expect from any serious R data access package. Missing these = users will look elsewhere.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Automatic caching** | Users don't want to re-download unchanged data | Medium | pins pattern: "only re-download if changed" using HTTP caching headers |
| **Progress bars** | Large neuroimaging files need visual feedback | Low | Use `progress` package or curl's built-in; "good practice to call tick(0) immediately" |
| **Retry with backoff** | Networks fail; httr2 handles this automatically | Low | httr2 built-in: retries on 429/503, respects Retry-After header |
| **Informative errors** | Users need to know what went wrong and how to fix | Medium | Use cli/rlang: `cli_abort()` with bullet points, not cryptic messages |
| **Documentation** | roxygen2 + vignettes + pkgdown site | Medium | "Vignettes are short tutorials that explain what the package does as a whole" |
| **CRAN compliance** | XDG directories, no internet in tests, proper caching location | Medium | Use `tools::R_user_dir()` or rappdirs; tests with `skip_on_cran()` |
| **Offline graceful failure** | Don't crash when network unavailable | Low | "skip_if_offline() skips if run offline or on CRAN" |
| **Tibble/data.frame output** | Standard R data structures | Low | "prefer common existing data structures over custom" - tidyverse manifesto |
| **Clear API design** | Predictable, pipeable functions | Medium | "function families identified by common prefix" for autocomplete |

### Why These Are Non-Negotiable

From pins documentation: "Pins is designed to help you spend as little time as possible downloading data." This is the user expectation - the package handles the annoyances of remote data access invisibly.

From httr2 wrapping APIs guide: "Make sure examples, vignettes, and tests all work without error" on CRAN without API keys. Packages that break CRAN checks or require manual setup get abandoned.

## Differentiators

Features that would make openneuroR stand out. Not expected, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Lazy evaluation / deferred queries** | Query dataset metadata without downloading; filter before download | High | Arrow pattern: "operations recorded but not executed until collect()" |
| **Multi-file concurrent downloads** | Significantly faster for large datasets | Medium | curl `multi_download()`: "download multiple files concurrently with resumption support" |
| **Smart versioning** | Track dataset versions, compare changes, roll back | Medium | pins: "automatically versioned, making it straightforward to track changes" |
| **Typed metadata** | Structured BIDS metadata as proper R objects, not raw JSON | Medium | Domain expertise: parse participants.tsv, dataset_description.json properly |
| **dplyr-style filtering** | `datasets() |> filter(modality == "MRI") |> collect()` | High | dbplyr/arrow pattern for intuitive dataset discovery |
| **Download resumption** | Resume interrupted large downloads | Medium | curl supports this; critical for multi-GB neuroimaging files |
| **Multiple download backends** | AWS S3, DataLad, Git LFS, direct HTTP | High | Flexibility for different use cases; mentioned in OpenNeuro docs |
| **Parquet/Arrow caching** | Cache query results in efficient columnar format | Medium | pins 1.4.0+: "Writing with type = 'parquet' now uses nanoparquet" |
| **Pre-computed search index** | Instant local search over all datasets | High | Could periodically sync dataset metadata for offline browsing |
| **Connection pane integration** | RStudio IDE integration for browsing datasets | Medium | bigrquery 1.6.0: "datasets and tables appear in connection pane" |

### Recommended Differentiators for MVP

**Priority 1 - High impact, achievable:**
1. **Lazy evaluation for queries** - Query GraphQL, get tibble of metadata, only download what you `collect()`. This is the "arrow for neuroimaging data" value prop.
2. **Multi-file concurrent downloads** - Critical for datasets with 100s of subjects. curl makes this straightforward.
3. **Download resumption** - Essential for large files; partial downloads shouldn't restart from scratch.

**Priority 2 - Medium impact:**
4. **Typed BIDS metadata** - Parse dataset_description.json and participants.tsv into proper R structures. Domain expertise that generic download packages lack.
5. **Smart versioning** - OpenNeuro has snapshots; expose version history, allow pinning to specific versions.

## Anti-Features

Things to deliberately NOT build. Common mistakes in this domain.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Custom S4/R6 data structures** | "prefer common existing data structures over custom" | Return tibbles, lists, named vectors |
| **Mandatory authentication** | OpenNeuro is largely public; friction kills adoption | Use `drive_deauth()` pattern - work without auth, auth only when needed |
| **Blocking synchronous downloads** | Freezes R session for large files | Use async with progress callbacks, or at minimum show progress |
| **Writing to user's home directory** | CRAN policy violation; XDG non-compliant | Use `tools::R_user_dir()` for cache/config |
| **Overly clever caching** | Cache invalidation bugs frustrate users | Simple time-based or ETag-based invalidation; let users `cache_prune()` |
| **Kitchen-sink queries** | Downloading all metadata when user wants one field | Expose GraphQL flexibility; let users query exactly what they need |
| **Reinventing auth** | OAuth is hard and easy to get wrong | Use gargle for Google-style auth or httr2's built-in OAuth |
| **Console spam** | Printing every HTTP request | Quiet by default, verbose mode for debugging |
| **Assuming small data** | Pulling entire datasets into memory | Arrow pattern: "designed for larger-than-memory data" |
| **Ignoring rate limits** | Getting blocked by OpenNeuro | httr2 handles 429s automatically; add proactive throttling if needed |
| **Interactive-only auth** | Breaks CI/CD and automated workflows | Support non-interactive auth: service accounts, tokens, environment variables |

### Detailed Rationale

**Custom data structures:** From tidyverse manifesto: "Where possible, re-use existing data structures, rather than creating custom data structures for your own package." bigrquery returns tibbles. arrow returns tibbles (or Arrow Tables with easy tibble conversion). Users don't want to learn your special object types.

**Mandatory authentication:** googledrive's `drive_deauth()` pattern is crucial: "Instead of sending a token, googledrive will send an API key. This can be used to access public resources." Most OpenNeuro data is public. Don't make users authenticate just to browse.

**Assuming small data:** Arrow explicitly warns: "For queries on Dataset objects - which can be larger than memory - arrow raises an error if unsupported." Neuroimaging data is large. Design for it from day one.

## Feature Dependencies

```
                    +-----------------+
                    | GraphQL Client  |
                    | (ghql/httr2)    |
                    +--------+--------+
                             |
              +--------------+--------------+
              |                             |
    +---------v---------+         +---------v---------+
    | Dataset Discovery |         | Download Manager  |
    | (query, filter)   |         | (curl multi)      |
    +---------+---------+         +---------+---------+
              |                             |
              |         +-------------------+
              |         |
    +---------v---------v---------+
    |      Caching Layer          |
    |  (pins-style, R_user_dir)   |
    +---------+---------+---------+
              |         |
    +---------v---+  +--v-----------+
    | Lazy Eval   |  | BIDS Parser  |
    | Interface   |  | (metadata)   |
    +-------------+  +--------------+
```

### Dependency Chain

1. **GraphQL Client** - Foundation. Must work before anything else.
   - Depends on: httr2 or ghql
   - Blocks: Dataset discovery, metadata queries

2. **Caching Layer** - Second priority. Every feature uses it.
   - Depends on: rappdirs or tools::R_user_dir()
   - Blocks: Smart downloads, offline metadata browsing

3. **Download Manager** - Core download functionality.
   - Depends on: curl, caching layer
   - Blocks: Multi-file downloads, resumption

4. **Dataset Discovery** - Query and filter datasets.
   - Depends on: GraphQL client, caching layer
   - Blocks: Lazy evaluation interface

5. **Lazy Evaluation Interface** - Advanced querying (nice-to-have).
   - Depends on: Dataset discovery, dbplyr patterns
   - Blocks: dplyr-style interface

6. **BIDS Parser** - Domain-specific value add.
   - Depends on: Download manager (to get files)
   - Independent of: Lazy evaluation

## Complexity Estimates

### Low Complexity (Days)

| Feature | Estimate | Rationale |
|---------|----------|-----------|
| Progress bars | 1-2 days | progress package is mature; curl has built-in support |
| Retry logic | 1 day | httr2 handles this; just configure `req_retry()` |
| Basic caching | 2-3 days | pins pattern well-documented; use R_user_dir() |
| Informative errors | 2 days | cli::cli_abort() with bullet points |
| Tibble output | 1 day | Just use tibble::as_tibble() on results |

### Medium Complexity (Weeks)

| Feature | Estimate | Rationale |
|---------|----------|-----------|
| GraphQL client wrapper | 1-2 weeks | ghql works but needs OpenNeuro-specific queries |
| Multi-file downloads | 1 week | curl::multi_download() exists; need progress integration |
| Download resumption | 1 week | curl supports; need state management |
| BIDS metadata parsing | 1-2 weeks | JSON/TSV parsing + domain knowledge |
| Version tracking | 1 week | OpenNeuro has snapshots; expose via API |
| CRAN compliance | 1 week | Testing, examples, vignettes all need care |

### High Complexity (Months)

| Feature | Estimate | Rationale |
|---------|----------|-----------|
| Lazy evaluation interface | 3-4 weeks | Needs dbplyr-style translation layer |
| dplyr backend | 4-6 weeks | Significant engineering; study arrow/dbplyr |
| Multiple download backends | 4+ weeks | Each backend (S3, DataLad, git) is different |
| Connection pane integration | 2-3 weeks | RStudio-specific; less critical |
| Pre-computed search index | 3-4 weeks | Needs periodic sync, local storage, search |

## MVP Feature Set Recommendation

Based on research, the MVP should include:

### Must Have (Table Stakes)
- [ ] GraphQL queries via httr2 (not ghql - fewer dependencies)
- [ ] Basic download with progress bars
- [ ] Automatic caching with cache_prune()
- [ ] Retry with exponential backoff (httr2 default)
- [ ] Informative error messages (cli/rlang)
- [ ] CRAN-compliant file storage
- [ ] Core documentation (README, one vignette)

### Should Have (Early Differentiators)
- [ ] Concurrent downloads for multi-file datasets
- [ ] Download resumption for large files
- [ ] Basic BIDS metadata parsing (dataset_description.json)
- [ ] Dataset version/snapshot support

### Nice to Have (Post-MVP)
- [ ] Lazy evaluation / deferred queries
- [ ] dplyr-style filtering
- [ ] Multiple download backends
- [ ] Connection pane integration
- [ ] Full BIDS validation

## Sources

### HIGH Confidence (Official Documentation)
- [pins package - CRAN](https://cran.r-project.org/web/packages/pins/pins.pdf)
- [httr2 Wrapping APIs vignette](https://httr2.r-lib.org/articles/wrapping-apis.html)
- [Arrow R Package - Lazy Evaluation](https://arrow.apache.org/docs/r/articles/dataset.html)
- [googledrive Authentication](https://googledrive.tidyverse.org/reference/drive_auth.html)
- [bigrquery Package](https://bigrquery.r-dbi.org/)
- [Tidy Design Principles](https://design.tidyverse.org/)
- [OpenNeuro API Documentation](https://docs.openneuro.org/api.html)
- [curl Package - multi_download](https://cran.r-project.org/web/packages/curl/curl.pdf)
- [rappdirs Package](https://cran.r-project.org/web/packages/rappdirs/rappdirs.pdf)

### MEDIUM Confidence (Verified Web Sources)
- [HTTP Testing in R - Graceful Packages](https://books.ropensci.org/http-testing/graceful.html)
- [R-hub Blog - Retries in API packages](https://blog.r-hub.io/2020/04/07/retry-wheel/)
- [BIDS Specification](https://bids-specification.readthedocs.io/)
- [ghql Package Documentation](https://docs.ropensci.org/ghql/)

### LOW Confidence (Single Source / Blog)
- [Faster Downloads - R Blog](https://blog.r-project.org/2024/12/02/faster-downloads/)
