# Pitfalls Research: openneuro R Package

**Domain:** R API wrapper for neuroimaging data repository (OpenNeuro)
**Researched:** 2026-01-22
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

## Optional Dependency (Suggests) Pitfalls

**Context:** Adding bidser as Suggests dependency for BIDS integration
**Updated:** 2026-01-22

### Critical: Unconditional Use in Examples

**What goes wrong:** Examples call bidser functions without checking availability. R CMD check fails on systems without bidser installed.

**Why it happens:** CRAN policy requires Suggests packages be "used conditionally." During CRAN checks, `_R_CHECK_FORCE_SUGGESTS_` may be FALSE.

**Warning signs:**
- `R CMD check` errors mentioning "package 'bidser' required"
- Examples work locally but fail on CRAN

**Prevention:**
```r
\dontrun{
  # For examples that truly need bidser
}
# OR wrap with requireNamespace check:
if (requireNamespace("bidser", quietly = TRUE)) {
  # example code
}
```

**Source:** [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)

**Phase:** Any phase adding bidser-dependent examples

---

### Critical: Missing requireNamespace Guard in Functions

**What goes wrong:** Functions using bidser fail cryptically when bidser is not installed instead of giving a helpful error.

**Why it happens:** Users don't install Suggests packages automatically. Functions must handle their absence gracefully.

**Warning signs:**
- User reports "object not found" or namespace errors
- Functions fail with internal errors instead of clear messages

**Prevention:**
```r
my_bidser_function <- function(...) {
  if (!requireNamespace("bidser", quietly = TRUE)) {
    stop("Package 'bidser' required. Install with: install.packages('bidser')",
         call. = FALSE)
  }
  # proceed with bidser::function()
}
```

**Source:** [R Packages (2e) - Dependencies in Practice](https://r-pkgs.org/dependencies-in-practice.html)

**Phase:** All phases adding bidser-dependent functions

---

### Critical: Tests Fail Without bidser Installed

**What goes wrong:** Tests assume bidser is available. Fails during `R CMD check --as-cran` when `_R_CHECK_FORCE_SUGGESTS_=FALSE`.

**Why it happens:** Tests work locally where bidser is installed. CRAN may run checks without Suggests installed.

**Warning signs:**
- CI failures when bidser not in test environment
- Local tests pass but CRAN checks fail

**Prevention:**
```r
test_that("bidser integration works", {
  skip_if_not_installed("bidser")
  # test code using bidser
})
```

**Source:** [testthat - Skipping Tests](https://testthat.r-lib.org/articles/skipping.html)

**Phase:** All phases adding bidser-related tests

---

### Moderate: Using require() Instead of requireNamespace()

**What goes wrong:** `require()` attaches the package to the search path, polluting the namespace. CRAN check issues NOTE about library/require in package code.

**Why it happens:** `require()` seems simpler, but it's meant for interactive use, not package code.

**Prevention:**
- Always use `requireNamespace("bidser", quietly = TRUE)`
- Call functions via `bidser::fun()`, never unqualified after require()
- Exception: examples may use `require()` per Writing R Extensions

**Source:** [R Packages (2e)](https://r-pkgs.org/dependencies-in-practice.html)

**Phase:** Code review checkpoint

---

### Moderate: Forgetting to Add bidser to DESCRIPTION Suggests

**What goes wrong:** `R CMD check` NOTE: "Namespace in Imports field not imported" or similar inconsistency warnings.

**Why it happens:** Code uses bidser but DESCRIPTION doesn't list it.

**Prevention:**
```r
usethis::use_package("bidser", type = "Suggests")
```

Run this first before writing any bidser-dependent code.

**Phase:** First task in bidser integration milestone

---

### Minor: Inconsistent User Messaging

**What goes wrong:** Different functions give different error messages about missing bidser, confusing users.

**Prevention:** Create internal helper used by all bidser-dependent functions:
```r
.check_bidser <- function() {
  if (!requireNamespace("bidser", quietly = TRUE)) {
    stop("Package 'bidser' required for this function. ",
         "Install with: install.packages('bidser')", call. = FALSE)
  }
}
```

**Phase:** Create once in first bidser integration phase, reuse

---

### Minor: Vignettes That Require bidser

**What goes wrong:** Vignette fails to build on CRAN check infrastructure where bidser may not be installed.

**Why it happens:** Vignettes are rebuilt during R CMD check. If they call bidser unconditionally, they fail.

**Prevention:**
- Use `eval = requireNamespace("bidser", quietly = TRUE)` in code chunks
- Or document bidser as optional with example output pre-rendered
- Consider pkgdown articles instead of CRAN vignettes for heavy bidser examples

**Phase:** If adding vignettes that use bidser

---

### Suggests Dependency Checklist

| Phase | Pitfall Check |
|-------|---------------|
| Setup | bidser added to Suggests field in DESCRIPTION |
| Functions | All bidser-using functions have requireNamespace guard |
| Tests | All bidser tests use skip_if_not_installed("bidser") |
| Examples | All bidser examples conditional or in \dontrun{} |
| Final | R CMD check --as-cran passes with bidser uninstalled |

**Validation command:**
```bash
# Uninstall bidser, then run check
R CMD INSTALL --no-test-load .
_R_CHECK_FORCE_SUGGESTS_=FALSE R CMD check --as-cran openneuro_*.tar.gz
```

---

## fMRIPrep Derivative Discovery Pitfalls

**Context:** Adding fMRIPrep derivative discovery to existing openneuroR package (v1.2 milestone)
**Researched:** 2026-01-22

### Critical: Assuming Derivatives Use Same API/Bucket as Raw Data

**What goes wrong:** Code assumes derivatives are in the main OpenNeuro S3 bucket (`s3://openneuro.org/`) using the same GraphQL API paths. In reality, derivatives may be in separate buckets (`s3://openneuro-derivatives/`, `s3://fmriprep-openneuro/`) with different access patterns.

**Why it happens:** Developers test with raw data, assume derivatives follow identical patterns. The OpenNeuro derivatives infrastructure has evolved separately from the main platform.

**Consequences:**
- Download functions fail with "bucket not found" or "access denied" errors
- Users cannot access derivatives that exist on OpenNeuro
- Code works for some datasets but mysteriously fails for others

**Warning signs:**
- Hardcoded S3 bucket paths that work for raw data
- No explicit derivatives-aware bucket configuration
- Testing only with datasets that have derivatives embedded in raw data

**Prevention:**
1. Research and document actual derivative storage locations:
   - Main bucket with derivatives path: `s3://openneuro/ds######/ds######_R#.#.#/uncompressed/derivatives/`
   - Separate derivatives bucket: `s3://openneuro-derivatives/`
   - OpenNeuroDerivatives GitHub: `https://github.com/OpenNeuroDerivatives/`
2. Implement bucket discovery logic that checks multiple locations
3. Handle access denied gracefully with informative messages about where derivatives actually exist
4. Test with datasets from different eras of OpenNeuro derivatives storage

**Source:** [Neurostars: OpenNeuro derivatives bucket](https://neurostars.org/t/openneuro-derivatives-bucket/26531)

**Phase to address:** Phase 1 - Initial derivative discovery research and API design

---

### Critical: Ignoring OpenNeuroDerivatives GitHub Organization

**What goes wrong:** Package only queries OpenNeuro API/S3 for derivatives, missing the majority of fMRIPrep derivatives stored in the OpenNeuroDerivatives GitHub organization.

**Why it happens:** Developers expect all data to be accessible via the main OpenNeuro API. The OpenNeuroDerivatives organization (544+ repos) is a separate ecosystem that requires different access patterns.

**Consequences:**
- Users cannot find derivatives that exist for their datasets
- Package reports "no derivatives available" when they actually exist
- Incomplete derivative discovery leads to user confusion

**Warning signs:**
- No GitHub API calls in derivative discovery code
- Documentation doesn't mention OpenNeuroDerivatives
- Derivative discovery only checks OpenNeuro API endpoints

**Prevention:**
1. Implement dual discovery: OpenNeuro API + GitHub API for OpenNeuroDerivatives
2. Use GitHub API to check for `ds######-fmriprep` repos in OpenNeuroDerivatives org
3. Document the relationship: derivatives may be on OpenNeuro, GitHub, or both
4. Provide `source` attribute in results indicating where derivatives were found

**Source:** [OpenNeuroDerivatives GitHub](https://github.com/OpenNeuroDerivatives)

**Phase to address:** Phase 1 - Derivative discovery architecture

---

### Critical: fMRIPrep Version Incompatibility Between Outputs

**What goes wrong:** Code assumes consistent file naming/structure across all fMRIPrep versions. Users get file-not-found errors or parse failures when derivatives were processed with different fMRIPrep versions.

**Why it happens:** fMRIPrep has evolved significantly. Key breaking changes include:
- Confounds file naming: `confounds.tsv` -> `confounds_regressors.tsv` -> `timeseries.tsv`
- Tissue probability naming: `probtissue` -> `probseg`
- Per-session processing introduced in 25.2.x
- Output layout options: "bids" vs "legacy"

**Consequences:**
- File parsing fails on older derivatives
- Users cannot mix derivatives from different processing runs
- Error messages are confusing (file exists but with different name)

**Warning signs:**
- Hardcoded filenames without version awareness
- No parsing of `dataset_description.json` to detect fMRIPrep version
- Testing only with derivatives from one fMRIPrep version

**Prevention:**
1. Parse `dataset_description.json` → `GeneratedBy.Name` and `GeneratedBy.Version`
2. Implement version-aware filename patterns that handle known variations:
   ```r
   confounds_patterns <- c(
     "desc-confounds_timeseries.tsv",  # >= 21.0
     "desc-confounds_regressors.tsv",  # ~20.x
     "confounds.tsv"                    # < 20.0
   )
   ```
3. Document version requirements in function help
4. Test with derivatives from multiple fMRIPrep versions (20.x, 21.x, 23.x, 25.x)

**Source:** [fMRIPrep Changelog](https://fmriprep.org/en/stable/changes.html), [fMRIPrep Versioning](https://reproducibility.stanford.edu/fmriprep-lts/)

**Phase to address:** Phase 2 - Derivative file parsing

---

### Critical: Treating Derivatives Folder in Raw Data as Equivalent to OpenNeuroDerivatives

**What goes wrong:** Code conflates two different types of "derivatives":
1. `derivatives/` folder within raw BIDS dataset (uploaded by data contributor)
2. OpenNeuroDerivatives processed datasets (standardized fMRIPrep outputs)

**Why it happens:** Both are called "derivatives" but have different origins, guarantees, and structures. Developers assume if derivatives exist in one place, they're equivalent to the other.

**Consequences:**
- Heterogeneous derivative structures break parsing logic
- Non-BIDS-compliant derivatives crash the parser
- Users get inconsistent results depending on derivative source

**Warning signs:**
- No distinction between "contributor derivatives" and "OpenNeuroDerivatives"
- Same parsing logic applied to both types
- No validation of derivative BIDS compliance

**Prevention:**
1. Separate API/code paths for:
   - `on_derivatives()` - list available derivatives (from any source)
   - `on_download_derivatives()` - download with source specification
2. Add `source` parameter: "openneuro" | "github" | "embedded"
3. Validate `dataset_description.json` presence and `DatasetType: "derivative"`
4. Handle non-compliant embedded derivatives gracefully with warnings

**Source:** [Neurostars: derivatives tab vs derivatives folder](https://neurostars.org/t/derivatives-tab-on-openneuro-vs-derivatives-folder-in-files-tab/26112)

**Phase to address:** Phase 1 - API design

---

### Moderate: Missing Subject-Derivative Mapping

**What goes wrong:** Subject filtering works for raw data but fails silently for derivatives. Users download derivatives expecting subject filtering to work.

**Why it happens:** Derivative file paths have different subject directory structures than raw data. The existing subject filter logic doesn't account for derivative path patterns.

**Consequences:**
- `subjects = c("sub-01", "sub-02")` downloads all subjects' derivatives
- Users waste bandwidth downloading unwanted subjects
- Filtering appears to work (no errors) but doesn't actually filter

**Warning signs:**
- Subject filtering tested only with raw data
- No derivative-specific path matching patterns
- Derivative directory structure not analyzed

**Prevention:**
1. Verify derivative paths follow pattern: `derivatives/fmriprep/sub-XX/`
2. Update `._filter_files_by_subjects()` to handle derivative paths:
   ```r
   # Raw: sub-XX/...
   # Derivatives: derivatives/fmriprep/sub-XX/...
   # Derivatives: derivatives/fmriprep/sub-XX/ses-XX/...
   ```
3. Add integration test: download derivatives for specific subjects
4. Document derivative subject filtering behavior

**Phase to address:** Phase 2 - Subject filtering integration

---

### Moderate: Derivatives File Sizes Not Handled

**What goes wrong:** Derivative files are typically 10-100x larger than raw data. Timeout, memory, and disk space handling tuned for raw data fails for derivatives.

**Why it happens:** Raw BIDS data has small JSON/TSV metadata and larger but manageable NIfTI files. Preprocessed derivatives include upsampled, multi-space outputs that dwarf raw data.

**Consequences:**
- Downloads timeout on large derivative files
- Memory exhaustion when loading file lists
- Disk space warnings come too late

**Warning signs:**
- Testing with small datasets only
- No file size estimation before download
- Same timeout values for raw and derivative downloads

**Prevention:**
1. Warn users about derivative sizes before download:
   ```r
   cli::cli_alert_warning(
     "Derivatives for {.val {dataset_id}} are {.val {formatted_size}}. Continue?"
   )
   ```
2. Increase default timeouts for derivative downloads (2-4x raw data timeouts)
3. Implement disk space check before derivative downloads
4. Consider streaming/chunked downloads for very large files

**Phase to address:** Phase 3 - Download implementation

---

### Moderate: Failed Processing Subjects Not Handled

**What goes wrong:** Code assumes all subjects have complete derivatives. Some subjects fail fMRIPrep processing (e.g., "Sub-20 processing failed" in ds002422-fmriprep).

**Why it happens:** fMRIPrep can fail for individual subjects due to data quality issues. Failed subjects may have partial outputs or only error reports.

**Consequences:**
- File listing includes incomplete subjects
- Downstream analysis crashes on missing expected files
- Users don't know which subjects are usable

**Warning signs:**
- No parsing of HTML reports or logs for failure indicators
- Assuming file existence = successful processing
- No quality/completeness metadata exposed

**Prevention:**
1. Parse `logs/CITATION.md` or subject HTML reports for processing status
2. Add `status` column to derivative file listings: "complete" | "partial" | "failed"
3. Warn users about failed subjects:
   ```r
   cli::cli_alert_warning(
     "Processing failed for: {.val {failed_subjects}}"
   )
   ```
4. Provide option to exclude failed subjects from download

**Source:** [OpenNeuroDerivatives/ds002422-fmriprep README](https://github.com/OpenNeuroDerivatives/ds002422-fmriprep)

**Phase to address:** Phase 2 - File listing and metadata

---

### Moderate: Breaking Existing API When Adding Derivatives

**What goes wrong:** New derivative functions change the behavior or return format of existing functions. Users' scripts break after updating the package.

**Why it happens:** Existing functions like `on_files()`, `on_download()` may need modification to support derivatives. Without careful design, changes affect non-derivative users.

**Consequences:**
- User scripts break after package update
- Semver violation (breaking change in minor version)
- User trust eroded

**Warning signs:**
- Modifying existing function signatures
- Changing return tibble column structure
- Adding required parameters to existing functions

**Prevention:**
1. Add NEW functions for derivatives: `on_derivatives()`, `on_download_derivatives()`
2. Keep existing functions unchanged (behavior freeze)
3. If existing functions need derivative awareness, use OPT-IN parameters:
   ```r
   on_files(..., include_derivatives = FALSE)  # Default preserves old behavior
   ```
4. Document migration path clearly
5. Run full existing test suite after every change

**Phase to address:** All phases - API design principle

---

### Moderate: BIDS Derivatives Filename Parsing Errors

**What goes wrong:** Code fails to parse BIDS derivative filenames correctly. Entity extraction breaks on complex filenames with multiple descriptors.

**Why it happens:** BIDS Derivatives adds entities like `_desc-<label>`, `_space-<space>`, `_res-<resolution>` that don't exist in raw BIDS. Filename patterns are more complex.

**Example complex filename:**
```
sub-01_task-rest_run-01_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz
```

**Consequences:**
- File metadata extraction fails
- Filtering by space/resolution doesn't work
- Users cannot find files by expected criteria

**Warning signs:**
- Regex patterns that assume simple filenames
- No handling of `_space-`, `_desc-`, `_res-` entities
- Filename parsing tested only on raw BIDS patterns

**Prevention:**
1. Use established BIDS parsing patterns:
   ```r
   entities <- c(
     "sub", "ses", "task", "acq", "ce", "rec", "dir",
     "run", "echo", "part", "space", "res", "desc"
   )
   ```
2. Build entity-extraction function that handles all BIDS derivative entities
3. Test with representative fMRIPrep output filenames
4. Consider using/wrapping bidser for BIDS parsing if available

**Source:** [fMRIPrep Outputs](https://fmriprep.org/en/stable/outputs.html), [BIDS Derivatives Specification](https://bids-specification.readthedocs.io/en/stable/derivatives/introduction.html)

**Phase to address:** Phase 2 - File listing and filtering

---

### Minor: No Pipeline Filtering for Derivatives

**What goes wrong:** Users want fMRIPrep derivatives but get mixed results including FreeSurfer, MRIQC, or other pipeline outputs.

**Why it happens:** Derivatives directory may contain outputs from multiple pipelines. Code returns all derivatives without filtering.

**Consequences:**
- Users download unwanted pipeline outputs
- Confusion about what derivatives are available
- Wasted bandwidth and disk space

**Warning signs:**
- No `pipeline` parameter in derivative functions
- Listing includes mixed pipeline outputs
- No parsing of `GeneratedBy` metadata

**Prevention:**
1. Add `pipeline` parameter: `on_derivatives(dataset_id, pipeline = "fmriprep")`
2. Parse `dataset_description.json` → `GeneratedBy.Name` to identify pipeline
3. Support common pipeline values: "fmriprep", "mriqc", "freesurfer", "ciftify"
4. Default to listing all pipelines, filter on request

**Phase to address:** Phase 2 - Filtering implementation

---

### Minor: Confusing Derivative Versions

**What goes wrong:** Multiple derivative versions exist for a dataset (e.g., processed with fMRIPrep 20.0, 21.0, 23.0). Users accidentally download wrong version.

**Why it happens:** OpenNeuroDerivatives may have multiple repos for same dataset with different fMRIPrep versions. Code doesn't expose or handle this.

**Consequences:**
- Users get unexpected fMRIPrep version
- Results vary based on which version is returned first
- No way to request specific processing version

**Warning signs:**
- No version info in derivative listings
- First-found derivatives returned without version consideration
- No mechanism to request specific version

**Prevention:**
1. Include processing version in derivative discovery results
2. Provide `version` parameter for version-specific downloads
3. Default to latest version when multiple exist
4. Show available versions:
   ```r
   on_derivatives("ds000001")
   # Returns tibble with: pipeline, version, source, file_count, size
   ```

**Phase to address:** Phase 3 - Version management

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode bucket URL | Quick implementation | Breaks when infrastructure changes | Never for production |
| Skip version parsing | Simpler code | Fails on version variations | Only for MVP prototype |
| Ignore embedded vs GitHub derivatives | Less complexity | Incorrect results for many datasets | Never |
| Same timeout for derivatives | Code reuse | Failed large downloads | Only if derivatives are optional feature |
| No disk space check | Simpler UX | Frustrated users with full disks | Only for small datasets |

## Integration Gotchas

Common mistakes when connecting to external services for derivative discovery.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| OpenNeuro GraphQL | Assuming derivatives field exists | Check schema introspection first |
| S3 openneuro-derivatives bucket | Using same auth as main bucket | May have different access policies |
| OpenNeuroDerivatives GitHub | Not handling rate limits | Use GitHub API with pagination and backoff |
| DataLad for derivatives | Assuming same repo structure | Derivatives repos may have different annex configuration |
| fMRIPrep outputs | Hardcoding filename patterns | Version-aware pattern matching |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Listing all derivative files at once | Memory exhaustion, timeout | Paginate file listings | >10,000 files |
| Downloading derivatives without size warning | Full disk, angry users | Pre-download size estimate | >10GB derivatives |
| No caching of derivative discovery | Repeated slow API calls | Cache derivative listings | Interactive use |
| Single-threaded derivative download | Hours for large datasets | Parallel download with batching | >100 files or >5GB |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Derivative discovery:** Often missing OpenNeuroDerivatives GitHub source - verify all sources checked
- [ ] **Subject filtering:** Often missing derivative path patterns - verify derivatives filter correctly
- [ ] **fMRIPrep version handling:** Often missing old version patterns - verify with 20.x derivatives
- [ ] **Download function:** Often missing size warnings - verify user is warned for large downloads
- [ ] **Error messages:** Often cryptic for derivative issues - verify clear guidance when derivatives not found
- [ ] **Documentation:** Often missing derivative-specific examples - verify all functions have derivative examples

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong bucket hardcoded | LOW | Update bucket URL, release patch |
| Existing API broken | HIGH | Deprecate changed behavior, add compat shim, semver major |
| fMRIPrep version crashes | MEDIUM | Add version detection, pattern fallback, test suite expansion |
| Derivatives not found (missed GitHub) | MEDIUM | Add GitHub discovery, update docs, user notification |
| Subject filter not working | MEDIUM | Fix patterns, add regression tests, changelog note |

---

## Prevention Strategies Summary

### Phase 1: Derivative Discovery Foundation

| Pitfall | Prevention |
|---------|------------|
| Wrong bucket assumption | Research and document all derivative storage locations |
| Missing GitHub derivatives | Implement dual discovery (API + GitHub) |
| Breaking existing API | Add new functions, don't modify existing |
| Embedded vs GitHub confusion | Separate code paths, clear source attribution |

### Phase 2: File Listing and Filtering

| Pitfall | Prevention |
|---------|------------|
| fMRIPrep version incompatibility | Parse dataset_description.json, version-aware patterns |
| Subject filter failure | Update patterns for derivative paths |
| Filename parsing errors | Handle all BIDS derivative entities |
| Failed subjects not handled | Parse logs, expose status metadata |

### Phase 3: Download Implementation

| Pitfall | Prevention |
|---------|------------|
| Derivative sizes not handled | Warn before download, check disk space |
| Multiple versions confusion | Expose version info, provide version parameter |
| Pipeline filtering missing | Parse GeneratedBy, add pipeline parameter |

---

## Phase Mapping

| Phase | Key Pitfalls to Address |
|-------|------------------------|
| **Phase 1: Setup** | Cache directory, DESCRIPTION, SystemRequirements, user agent |
| **Phase 2: API Core** | Error handling, authentication, CLI integration, test mocking |
| **Phase 3: Downloads** | Timeout, resume, checksums, file limits, rate limiting |
| **Phase 4: Polish** | Examples, vignettes, progress, cache management |
| **bidser Integration** | requireNamespace guards, skip_if_not_installed, conditional examples |
| **Derivatives Phase 1** | Bucket discovery, GitHub integration, API design |
| **Derivatives Phase 2** | Version handling, subject filtering, filename parsing |
| **Derivatives Phase 3** | Size handling, version management, pipeline filtering |

---

## Sources

### Official Documentation
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
- [httr2 Wrapping APIs](https://httr2.r-lib.org/articles/wrapping-apis.html)
- [R Packages (2e) - CRAN Chapter](https://r-pkgs.org/release.html)
- [R Packages (2e) - Dependencies in Practice](https://r-pkgs.org/dependencies-in-practice.html)
- [processx documentation](https://processx.r-lib.org/)
- [testthat skipping](https://testthat.r-lib.org/articles/skipping.html)
- [fMRIPrep Outputs](https://fmriprep.org/en/stable/outputs.html)
- [fMRIPrep Changelog](https://fmriprep.org/en/stable/changes.html)
- [BIDS Derivatives Specification](https://bids-specification.readthedocs.io/en/stable/derivatives/introduction.html)

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

### OpenNeuro/fMRIPrep References
- [OpenNeuro API Documentation](https://docs.openneuro.org/api.html)
- [OpenNeuroDerivatives GitHub](https://github.com/OpenNeuroDerivatives)
- [Neurostars: OpenNeuro derivatives bucket](https://neurostars.org/t/openneuro-derivatives-bucket/26531)
- [Neurostars: derivatives tab vs folder](https://neurostars.org/t/derivatives-tab-on-openneuro-vs-derivatives-folder-in-files-tab/26112)
- [fMRIPrep LTS and Versioning](https://reproducibility.stanford.edu/fmriprep-lts/)
- [GitHub issue: Sharing derivatives-only datasets](https://github.com/OpenNeuroOrg/openneuro/issues/2436)
