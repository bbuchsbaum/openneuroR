# Pitfalls Research: openneuro R Package

**Domain:** R API wrapper for neuroimaging data repository (OpenNeuro)
**Researched:** 2026-01-20
**Confidence:** HIGH (verified with official documentation and multiple authoritative sources)

---

## API Wrapper Pitfalls

### Critical: Inadequate Error Handling

**What goes wrong:** Package returns cryptic HTTP errors or fails silently when API requests fail. Users cannot diagnose whether the issue is authentication, rate limiting, network, or API changes.

**Why it happens:** Developers use raw `httr2::req_perform()` without custom error handling, assuming HTTP errors are self-explanatory. GraphQL APIs often return HTTP 200 with error payloads, masking failures.

**Consequences:**
- Users cannot debug authentication issues
- Rate limiting appears as random failures
- API deprecations cause mysterious breakage

**Warning signs:**
- Tests only cover happy paths
- No custom error classes defined
- GraphQL responses not parsed for `errors` field

**Prevention:**
1. Use `httr2::req_error()` with custom body parser to extract meaningful error messages
2. Parse GraphQL response for `errors` array even on HTTP 200
3. Create custom error classes: `openneuro_auth_error`, `openneuro_rate_limit_error`, `openneuro_api_error`
4. Include request context in error messages (endpoint, dataset ID)

**Source:** [httr2 Wrapping APIs guide](https://httr2.r-lib.org/articles/wrapping-apis.html)

**Phase:** Core API layer (Phase 1-2)

---

### Critical: Missing User Agent

**What goes wrong:** API maintainers cannot identify your package when it misbehaves. If your package accidentally hammers the API or has a bug, OpenNeuro cannot contact you.

**Why it happens:** Developers forget this "politeness" detail, focusing on functionality.

**Consequences:**
- Package gets IP-banned with no explanation
- Cannot establish relationship with API maintainers
- Harder to get support when issues arise

**Warning signs:**
- No `req_user_agent()` call in request builder
- User agent is generic R default

**Prevention:**
```r
req_user_agent("openneuro-r/0.1.0 (https://github.com/user/openneuro-r)")
```

**Source:** [httr2 documentation](https://httr2.r-lib.org/articles/wrapping-apis.html)

**Phase:** Core API layer (Phase 1)

---

### Moderate: Hardcoded API Keys in Function Arguments

**What goes wrong:** Users accidentally commit API keys to version control, expose them in shared scripts, or have them visible in R console history.

**Why it happens:** Providing `api_key` parameter seems user-friendly but encourages insecure patterns.

**Consequences:**
- Security vulnerabilities
- Leaked credentials
- CRAN reviewers may flag as poor practice

**Warning signs:**
- Functions have `api_key` as required parameter
- Examples show inline API key usage
- No environment variable documentation

**Prevention:**
1. Store keys in environment variables only: `OPENNEURO_API_KEY`
2. Use `Sys.getenv("OPENNEURO_API_KEY")` with helpful error if missing
3. Document `.Renviron` setup in vignette
4. Consider `askpass::askpass()` for interactive key entry

**Source:** [rOpenSci package reviews](https://github.com/ropensci/software-review/issues/285)

**Phase:** Authentication layer (Phase 1-2)

---

### Moderate: GraphQL Pagination Ignored

**What goes wrong:** Queries return only first 100-1000 items. Users think they have all data but are missing most of it.

**Why it happens:** GraphQL pagination requires cursor-based iteration. First implementation "works" on small queries, fails silently on large ones.

**Consequences:**
- Incomplete dataset listings
- Missing subjects/sessions in large datasets
- Results vary mysteriously between runs

**Warning signs:**
- No `pageInfo` or `cursor` handling in queries
- Functions don't accept `limit` or pagination parameters
- Large datasets return suspiciously small results

**Prevention:**
1. Implement cursor-based pagination from the start
2. Add `limit` parameter with sensible default
3. Document maximum items per page
4. Warn when results may be truncated

**Source:** [GraphQL R integration guide](https://gabrielcp.medium.com/interacting-with-a-graphql-api-with-r-b53f0f76d3f4)

**Phase:** Core API layer (Phase 1-2)

---

### Minor: Rate Limiting Not Handled

**What goes wrong:** Bulk operations fail partway through when rate limits hit. No automatic retry, no helpful wait messages.

**Why it happens:** Rate limiting seems like an edge case during development with small test queries.

**Consequences:**
- Failed batch operations with partial results
- Users must manually retry
- Potential API bans

**Warning signs:**
- No `req_throttle()` or `req_retry()` usage
- HTTP 429 responses not handled specially
- No progress indicators for bulk operations

**Prevention:**
1. Use `httr2::req_throttle()` for proactive rate limiting
2. Implement `req_retry()` with `Retry-After` header parsing
3. Add informative messages when waiting

**Source:** [httr2 Wrapping APIs](https://httr2.r-lib.org/articles/wrapping-apis.html)

**Phase:** Core API layer (Phase 2)

---

## Download/Cache Pitfalls

### Critical: Using Wrong Cache Directory

**What goes wrong:** Package writes to user home directory, which violates CRAN policy. Package gets rejected or removed from CRAN.

**Why it happens:** Developers use `rappdirs::user_cache_dir()` or hardcode paths like `~/.openneuro/`. CRAN policy requires `tools::R_user_dir()`.

**Consequences:**
- CRAN rejection
- Package removal after acceptance
- User confusion about cache location

**Warning signs:**
- Using `rappdirs` package for cache paths
- Hardcoded `~/` paths
- No `R_USER_CACHE_DIR` environment variable support

**Prevention:**
1. Use `tools::R_user_dir("openneuro", which = "cache")` exclusively
2. Support `R_USER_CACHE_DIR` override for testing
3. Document cache location in package documentation
4. Set `R_USER_CACHE_DIR` to temp directory during tests

**Source:** [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html), [rappdirs issue #27](https://github.com/r-lib/rappdirs/issues/27)

**Phase:** Caching layer (Phase 2-3)

---

### Critical: Default Timeout Too Short for Large Files

**What goes wrong:** Downloads of large neuroimaging files (10-100+ GB) fail with "Timeout of 60 seconds was reached" error.

**Why it happens:** R's default `download.file()` timeout is 60 seconds, which applies to the entire transfer, not just connection establishment.

**Consequences:**
- Large file downloads always fail
- Users get cryptic timeout errors
- Package appears broken for real use cases

**Warning signs:**
- Using `download.file()` without timeout override
- No file size checks before download
- Testing only with small files

**Prevention:**
1. Use `curl::multi_download()` with configurable timeout
2. Set timeout proportional to expected file size
3. Implement resume capability for interrupted downloads
4. Document timeout configuration for users

```r
# Example: 1 hour timeout for large files
options(timeout = 3600)
```

**Source:** [R Blog - Faster Downloads](https://blog.r-project.org/2024/12/02/faster-downloads/), [download.file documentation](https://stat.ethz.ch/R-manual/R-devel/library/utils/html/download.file.html)

**Phase:** Download layer (Phase 2-3)

---

### Critical: No Download Resume Support

**What goes wrong:** A 50GB download fails at 45GB. User must restart from zero. Repeated for every network hiccup.

**Why it happens:** Basic `download.file()` doesn't support resume. Developers test with small files that always complete.

**Consequences:**
- Wasted bandwidth and time
- Frustrated users
- Unusable for large datasets on unreliable networks

**Warning signs:**
- Using `download.file()` instead of `curl::multi_download()`
- No partial file detection
- No HTTP Range request support

**Prevention:**
1. Use `curl::multi_download(resume = TRUE)` for all downloads
2. Handle HTTP 206 (Partial Content) and HTTP 416 (Range Not Satisfiable)
3. Store download progress metadata
4. Verify completed downloads with checksums

**Source:** [curl package documentation](https://cran.r-project.org/web/packages/curl/curl.pdf)

**Phase:** Download layer (Phase 2-3)

---

### Moderate: No Checksum Verification

**What goes wrong:** Corrupted downloads go undetected. Users run analyses on incomplete or corrupted data.

**Why it happens:** Checksum verification adds complexity and slows downloads. Seems like overkill for "simple" downloads.

**Consequences:**
- Silent data corruption
- Unreproducible analyses
- Wasted compute on bad data

**Warning signs:**
- No MD5/SHA256 verification after download
- No file integrity metadata stored
- No re-download option for corrupted files

**Prevention:**
1. Fetch checksums from OpenNeuro API
2. Verify after download completion
3. Re-download automatically on mismatch
4. Cache verified status to skip re-verification

**Source:** [pkgfilecache documentation](https://cran.r-project.org/web/packages/pkgfilecache/vignettes/pkgfilecache.html)

**Phase:** Download layer (Phase 3)

---

### Moderate: Open File Handle Limits

**What goes wrong:** Downloading many files simultaneously hits OS limit on open files (often 256-1024). Download fails with cryptic error.

**Why it happens:** Parallel download implementation opens all files upfront without considering OS limits.

**Consequences:**
- Mysterious failures on datasets with many files
- Errors vary by OS and user configuration
- Difficult to debug

**Warning signs:**
- Using `curl::multi_download()` with large file lists without batching
- No file handle limit checking
- Testing only on single-file downloads

**Prevention:**
1. Batch parallel downloads (e.g., 50-100 files at a time)
2. Close file handles promptly after each file
3. Make batch size configurable
4. Document system limits in troubleshooting guide

**Source:** [R Blog - Faster Downloads](https://blog.r-project.org/2024/12/02/faster-downloads/)

**Phase:** Download layer (Phase 3)

---

### Minor: Cache Size Unbounded

**What goes wrong:** User downloads many datasets over months. Cache grows to consume all disk space.

**Why it happens:** "Download and forget" is the easy implementation. Cache management is deferred.

**Consequences:**
- Disk space exhaustion
- User frustration
- Manual cache cleanup required

**Warning signs:**
- No cache size tracking
- No cache eviction policy
- No cache status functions

**Prevention:**
1. Track cache contents and sizes
2. Implement LRU eviction (optional, user-controlled)
3. Provide `openneuro_cache_info()` and `openneuro_cache_clear()` functions
4. Warn when cache exceeds configurable threshold

**Phase:** Caching layer (Phase 3-4)

---

## External CLI Pitfalls

### Critical: Assuming CLI Tools Are Installed

**What goes wrong:** Package fails with unhelpful error when DataLad or AWS CLI not found. Users don't know what to install or how.

**Why it happens:** Developer's machine has all tools installed. Testing doesn't cover fresh environments.

**Consequences:**
- Package appears broken
- Users can't diagnose missing dependencies
- Bad first impressions

**Warning signs:**
- No `Sys.which()` checks for required tools
- Generic error messages on subprocess failure
- No installation guidance in documentation

**Prevention:**
1. Check tool availability at package load or first use
2. Provide clear error: "DataLad not found. Install from https://..."
3. Make CLI tools optional where possible (graceful degradation)
4. Document all external dependencies in DESCRIPTION SystemRequirements

```r
check_datalad <- function() {
  if (Sys.which("datalad") == "") {
    stop("DataLad is required but not installed.\n",
         "Install from: https://www.datalad.org/get_datalad.html",
         call. = FALSE)
  }
}
```

**Phase:** CLI integration (Phase 2)

---

### Critical: Using system2() for Complex Operations

**What goes wrong:** `system2()` has unreliable argument quoting, especially with spaces in paths. Commands fail mysteriously on some systems.

**Why it happens:** `system2()` is base R and seems simpler than adding dependencies. Its limitations aren't obvious until edge cases hit.

**Consequences:**
- Failures on paths with spaces (common on Windows)
- Non-ASCII characters cause issues
- Platform-specific bugs

**Warning signs:**
- Using `system2()` instead of `processx::run()`
- No path quoting with `shQuote()`
- Testing only on developer's machine

**Prevention:**
1. Use `processx::run()` for all subprocess execution
2. Pass arguments as character vector, not concatenated string
3. Test with paths containing spaces and special characters
4. Handle timeout with `processx::run(timeout = ...)`

**Source:** [system2 considered inadequate](https://ro-che.info/articles/2020-12-11-r-system2), [rOpenSci system calls guide](https://ropensci.org/blog/2021/09/13/system-calls-r-package/)

**Phase:** CLI integration (Phase 2)

---

### Moderate: No Timeout for External Commands

**What goes wrong:** DataLad operation hangs indefinitely. R session frozen. User must kill R.

**Why it happens:** External commands assumed to complete. Network issues or large operations can hang forever.

**Consequences:**
- Frozen R sessions
- Lost work
- No way to cancel gracefully

**Warning signs:**
- `processx::run()` called without `timeout` parameter
- No progress indicators for long operations
- Testing only with fast operations

**Prevention:**
1. Set reasonable timeouts for all external commands
2. Use `processx::run(timeout = 3600)` (1 hour for large downloads)
3. Provide progress feedback for long operations
4. Document expected durations

**Source:** [processx documentation](https://processx.r-lib.org/reference/run.html)

**Phase:** CLI integration (Phase 2-3)

---

### Moderate: Blocking Operations Without Feedback

**What goes wrong:** Large dataset download via DataLad takes 30 minutes. No progress, no feedback. User thinks it's frozen.

**Why it happens:** Default subprocess execution blocks R. Adding progress indicators requires more complex async handling.

**Consequences:**
- User cancels working operations
- Poor user experience
- Support requests

**Warning signs:**
- No `message()` calls during long operations
- No progress bar integration
- `processx::run()` without callback functions

**Prevention:**
1. Use `processx::run()` with stdout callback for progress
2. Parse DataLad/AWS CLI progress output
3. Integrate with `cli` package for progress bars
4. Provide estimated time remaining when possible

**Phase:** CLI integration (Phase 3)

---

### Minor: AWS Region Configuration Issues

**What goes wrong:** S3 downloads fail with cryptic errors because wrong region used. OpenNeuro uses us-east-1 but users have different AWS defaults.

**Why it happens:** AWS SDK respects environment variables and config files. Package doesn't explicitly set region.

**Consequences:**
- Downloads fail for users with AWS CLI configured for other regions
- Confusing "access denied" or "bucket not found" errors

**Warning signs:**
- No explicit region configuration
- Relying on user's AWS config
- Testing only in us-east-1

**Prevention:**
1. Explicitly set region for OpenNeuro S3 operations
2. Document required AWS configuration
3. Provide helpful error messages for region issues
4. Override user's AWS config when accessing OpenNeuro specifically

**Source:** [aws.s3 documentation](https://cran.r-project.org/web/packages/aws.s3/readme/README.html)

**Phase:** CLI integration (Phase 2-3)

---

## CRAN Submission Pitfalls

### Critical: Tests Make Real API Calls

**What goes wrong:** Tests fail on CRAN because OpenNeuro API is unavailable, rate-limited, or slow. Package fails R CMD check.

**Why it happens:** Developer tests with real API calls. Works locally but fails on CRAN infrastructure.

**Consequences:**
- CRAN rejection
- Intermittent test failures
- Long check times

**Warning signs:**
- No `vcr` or `httptest` for mocking
- Tests require internet connection
- No `skip_on_cran()` for API tests

**Prevention:**
1. Use `vcr::use_cassette()` to record/replay HTTP interactions
2. Mock all API responses for CRAN tests
3. Use `skip_on_cran()` for integration tests requiring real API
4. Keep mocked tests that exercise all code paths

**Source:** [HTTP Testing in R](https://books.ropensci.org/http-testing/vcr.html), [rOpenSci best practices](https://cran.r-project.org/web/packages/crul/vignettes/best-practices-api-packages.html)

**Phase:** Testing (Phase 1-2)

---

### Critical: Examples/Vignettes Make API Calls

**What goes wrong:** R CMD check runs examples and rebuilds vignettes. These make API calls, causing timeouts or failures on CRAN.

**Why it happens:** Examples naturally demonstrate real functionality. Developers don't think about check-time execution.

**Consequences:**
- CRAN rejection for slow checks
- Failures when API unavailable
- Check time exceeds CRAN limits

**Warning signs:**
- Examples without `\dontrun{}` or `\donttest{}`
- Vignettes with live API calls
- Check time > 10 minutes

**Prevention:**
1. Wrap API-calling examples in `\dontrun{}` or `if (interactive())`
2. Pre-compute vignette results, store as static data
3. Use `knitr` caching for vignettes
4. Consider `pkgdown` articles instead of vignettes for heavy examples

```r
#' @examples
#' \dontrun{
#' # Requires API access
#' datasets <- openneuro_datasets()
#' }
#'
#' # Example with cached data (always runs)
#' data(example_dataset_info)
#' print(example_dataset_info)
```

**Source:** [R Packages - Vignettes](https://r-pkgs.org/vignettes.html), [rOpenSci exoplanets review](https://github.com/ropensci/software-review/issues/309)

**Phase:** Documentation (Phase 2-3)

---

### Critical: Internet Failures Not Graceful

**What goes wrong:** Package errors with stack trace when network unavailable instead of informative message.

**Why it happens:** Error handling focuses on API errors, not network-level failures.

**Consequences:**
- CRAN rejection: "Packages which use Internet resources should fail gracefully"
- Poor user experience offline
- Confusing error messages

**Warning signs:**
- No `tryCatch` around HTTP requests
- No `curl::has_internet()` checks
- Error messages expose internal details

**Prevention:**
1. Wrap all network operations in `tryCatch`
2. Check `curl::has_internet()` before operations
3. Return informative error: "Cannot connect to OpenNeuro. Check internet connection."
4. Never expose raw HTTP errors to users

**Source:** [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)

**Phase:** Core API layer (Phase 1-2)

---

### Moderate: DESCRIPTION Field Errors

**What goes wrong:** CRAN human review rejects package for minor DESCRIPTION issues: title formatting, missing quotes, grammar.

**Why it happens:** DESCRIPTION formatting rules are strict and not always obvious.

**Consequences:**
- Delays in CRAN acceptance
- Multiple resubmissions needed

**Warning signs:**
- Title starts with "A package..." or includes package name
- Missing single quotes around external software names
- No DOI/URL reference for API being wrapped
- Missing Authors@R with 'cph' role

**Prevention:**
1. Title: Don't start with article, don't include package name
2. Quote external names: 'OpenNeuro', 'BIDS', 'DataLad'
3. Include API reference: `https://openneuro.org/`
4. Ensure copyright holder role: `role = c("aut", "cre", "cph")`
5. Use `usethis::use_description()` and `devtools::check()` early

**Source:** [Checklist for CRAN submissions](https://cran.r-project.org/web/packages/submission_checklist.html)

**Phase:** Package setup (Phase 1)

---

### Moderate: External Tools in SystemRequirements

**What goes wrong:** Package requires DataLad/AWS CLI but doesn't declare in DESCRIPTION. CRAN check passes but users can't use package.

**Why it happens:** R dependencies are obvious, system dependencies forgotten.

**Consequences:**
- User confusion about requirements
- Undocumented dependencies
- Poor installation experience

**Warning signs:**
- `Sys.which()` checks but no SystemRequirements field
- README mentions requirements but DESCRIPTION doesn't
- Shelling out to tools not listed anywhere

**Prevention:**
```
SystemRequirements: DataLad (optional, https://www.datalad.org/),
    AWS CLI (optional, https://aws.amazon.com/cli/)
```

**Source:** [CRAN External Libraries](https://cran.r-project.org/web/packages/external_libs.html)

**Phase:** Package setup (Phase 1)

---

### Minor: Check Time Too Long

**What goes wrong:** R CMD check takes > 10 minutes. CRAN rejects for resource abuse.

**Why it happens:** Large test suites, slow vignettes, examples that do real work.

**Consequences:**
- CRAN rejection
- Slows down development iteration

**Warning signs:**
- Check time > 5 minutes locally
- Vignettes take minutes to build
- Many API-calling tests without mocking

**Prevention:**
1. Mock all API calls in tests
2. Pre-compute vignette outputs
3. Use `\donttest{}` for slow examples
4. Profile check time: `devtools::check(args = "--timings")`

**Source:** [R Packages - R CMD check](https://r-pkgs.org/R-CMD-check.html)

**Phase:** Testing/Documentation (Phase 2-3)

---

## Prevention Strategies Summary

### Phase 1: Foundation Setup

| Pitfall | Prevention |
|---------|------------|
| Wrong cache directory | Use `tools::R_user_dir()` from day one |
| Missing user agent | Add to base request builder immediately |
| DESCRIPTION errors | Follow CRAN checklist from start |
| SystemRequirements missing | Document external deps in DESCRIPTION |
| API key exposure | Environment variable pattern only |

### Phase 2: Core API Layer

| Pitfall | Prevention |
|---------|------------|
| Inadequate error handling | Custom error classes, GraphQL error parsing |
| Tests hit real API | Set up vcr/webmockr from first test |
| CLI tool not installed | Check + helpful error on first use |
| system2() issues | Use processx::run() exclusively |
| Network failures not graceful | tryCatch + informative messages |

### Phase 3: Download/Cache Layer

| Pitfall | Prevention |
|---------|------------|
| Timeout too short | Configurable timeout, document limits |
| No resume support | curl::multi_download(resume = TRUE) |
| No checksum verification | Verify all downloads against API checksums |
| Open file limits | Batch parallel downloads |
| Rate limiting | req_throttle() + req_retry() |
| Pagination ignored | Implement cursor pagination |

### Phase 4: Documentation/Polish

| Pitfall | Prevention |
|---------|------------|
| Examples hit API | \dontrun{} or cached examples |
| Vignettes slow | Pre-computed results, consider articles |
| Check time too long | Profile and optimize |
| Cache unbounded | Provide cache management functions |
| No progress feedback | cli package integration |

---

## Phase Mapping

| Phase | Key Pitfalls to Address |
|-------|------------------------|
| **Phase 1: Setup** | Cache directory, DESCRIPTION, SystemRequirements, user agent |
| **Phase 2: API Core** | Error handling, authentication, CLI integration, test mocking |
| **Phase 3: Downloads** | Timeout, resume, checksums, file limits, rate limiting |
| **Phase 4: Polish** | Examples, vignettes, progress, cache management |

---

## Sources

### Official Documentation
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
- [httr2 Wrapping APIs](https://httr2.r-lib.org/articles/wrapping-apis.html)
- [R Packages (2e) - CRAN Chapter](https://r-pkgs.org/release.html)
- [processx documentation](https://processx.r-lib.org/)
- [testthat skipping](https://testthat.r-lib.org/articles/skipping.html)

### rOpenSci Resources
- [API package best practices](https://cran.r-project.org/web/packages/crul/vignettes/best-practices-api-packages.html)
- [HTTP Testing in R](https://books.ropensci.org/http-testing/)
- [System calls in R packages](https://ropensci.org/blog/2021/09/13/system-calls-r-package/)
- [rOpenSci Dev Guide](https://devguide.ropensci.org/)

### Technical References
- [system2 considered inadequate](https://ro-che.info/articles/2020-12-11-r-system2)
- [rappdirs CRAN issue](https://github.com/r-lib/rappdirs/issues/27)
- [R Blog - Faster Downloads](https://blog.r-project.org/2024/12/02/faster-downloads/)
- [curl package](https://cran.r-project.org/web/packages/curl/curl.pdf)
