# Phase 5: Infrastructure - Research

**Researched:** 2026-01-21
**Domain:** R package testing, CRAN compliance, diagnostic functions
**Confidence:** HIGH

## Summary

This phase focuses on making the openneuroR package CRAN-ready with comprehensive mocked tests and a diagnostic function. The research investigates HTTP mocking frameworks compatible with httr2, CRAN testing policies, CLI tool mocking strategies, and patterns for diagnostic "doctor" functions.

The primary recommendation is to use **httptest2** for HTTP mocking (designed specifically for httr2), combined with **testthat 3's `local_mocked_bindings()`** for mocking CLI backend calls (processx). For the diagnostic function, follow the **usethis/devtools sitrep pattern** with cli-formatted output and invisible list return.

**Primary recommendation:** Use httptest2 with `with_mock_dir()` for HTTP tests; mock backend wrappers with `local_mocked_bindings()` for CLI tests; implement `on_doctor()` following devtools/usethis diagnostic function patterns.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| testthat | >= 3.0.0 | Test framework | Industry standard, CRAN-approved, already in package |
| httptest2 | >= 1.1.0 | Mock httr2 requests | Purpose-built for httr2, recommended by rOpenSci |
| withr | >= 2.5.0 | Temporary state changes | Used by testthat for fixtures, already in package |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| webmockr | latest | Low-level HTTP stubbing | Alternative to httptest2, more manual control |
| vcr | >= 2.0.0 | Record/replay HTTP | Alternative, also supports httr2 |
| mockery | latest | Enhanced mock verification | When `expect_called()` semantics needed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| httptest2 | vcr | vcr uses YAML cassettes vs JSON; httptest2 file structure mirrors URLs |
| httptest2 | webmockr | webmockr requires manual stub setup; httptest2 has auto-recording |
| testthat mocking | mockery | mockery adds `expect_called()` but extra dependency |

**Installation:**
```bash
# Already in Suggests, ensure versions
# In DESCRIPTION:
# Suggests: testthat (>= 3.0.0), httptest2, withr
```

## Architecture Patterns

### Recommended Test Directory Structure
```
tests/
├── testthat.R                    # Standard testthat loader
├── testthat/
│   ├── helper-httptest2.R        # Load httptest2 for all tests
│   ├── helper-mocks.R            # Common mock functions for CLI backends
│   ├── fixtures/                 # Static test data (optional)
│   │   └── sample-manifest.json
│   ├── api.openneuro.org/        # httptest2 mock files (auto-created)
│   │   └── crn/
│   │       └── graphql/
│   │           ├── POST.json     # Mocked GraphQL responses
│   │           └── POST-abc123.json
│   ├── test-client.R             # Tests for on_client(), on_request()
│   ├── test-search.R             # Tests for on_search()
│   ├── test-download.R           # Tests for on_download()
│   ├── test-cache.R              # Tests for cache functions
│   ├── test-backends.R           # Tests for backend dispatch
│   ├── test-handle.R             # Tests for on_handle(), on_fetch(), on_path()
│   └── test-doctor.R             # Tests for on_doctor()
```

### Pattern 1: HTTP Request Mocking with httptest2
**What:** Record real API responses, replay in tests without network
**When to use:** All tests that call `on_request()` or any GraphQL endpoint
**Example:**
```r
# Source: https://enpiar.com/httptest2/articles/httptest2.html

# First run: records responses to tests/testthat/api.openneuro.org/
# Subsequent runs: replays from files
test_that("on_dataset returns metadata", {
  httptest2::with_mock_dir("api.openneuro.org", {
    result <- on_dataset("ds000001")
    expect_s3_class(result, "tbl_df")
    expect_equal(result$id, "ds000001")
  })
})
```

### Pattern 2: CLI Backend Mocking with local_mocked_bindings()
**What:** Replace processx::run() calls with controlled return values
**When to use:** Tests for .download_s3(), .download_datalad(), .backend_available()
**Example:**
```r
# Source: https://testthat.r-lib.org/articles/mocking.html

test_that(".download_s3 returns success on valid command", {
  local_mocked_bindings(
    run = function(...) list(status = 0, stdout = "", stderr = ""),
    .package = "processx"
  )

  result <- .download_s3("ds000001", tempdir())
  expect_true(result$success)
  expect_equal(result$backend, "s3")
})

test_that(".download_s3 aborts when AWS CLI fails", {
  local_mocked_bindings(
    run = function(...) list(status = 1, stdout = "", stderr = "Access denied"),
    .package = "processx"
  )

  expect_error(
    .download_s3("ds000001", tempdir()),
    class = "openneuro_backend_error"
  )
})
```

### Pattern 3: Backend Detection Mocking
**What:** Mock Sys.which() to simulate CLI tool presence/absence
**When to use:** Tests for .backend_available(), .find_aws_cli()
**Example:**
```r
# Create wrapper in package for Sys.which to make it mockable
# In R/backend-detect.R:
.sys_which <- function(names) Sys.which(names)

# In tests:
test_that(".backend_available returns FALSE when AWS CLI missing", {
  local_mocked_bindings(
    .sys_which = function(names) setNames("", names)
  )

  expect_false(.backend_available("s3"))
})
```

### Pattern 4: Diagnostic Function Pattern (sitrep style)
**What:** Return structured data invisibly, print formatted output
**When to use:** on_doctor() implementation
**Example:**
```r
# Source: devtools::dev_sitrep pattern

on_doctor <- function(verbose = FALSE) {
  # Gather status (refresh cache)
  status <- list(
    https = list(
      available = TRUE,  # Always available
      required = TRUE,
      version = NA_character_
    ),
    s3 = list(
      available = .backend_status("s3", refresh = TRUE),
      required = FALSE,
      version = .get_aws_version()
    ),
    datalad = list(
      available = .backend_status("datalad", refresh = TRUE),
      required = FALSE,
      version = .get_datalad_version()
    )
  )

  # Return invisibly, print method handles display
  structure(status, class = "openneuro_doctor")
}

print.openneuro_doctor <- function(x, ...) {
  cli::cli_h1("OpenNeuro Backend Status")
  # ... formatted output with cli
  invisible(x)
}
```

### Anti-Patterns to Avoid
- **Testing real network calls on CRAN:** Never make actual HTTP requests in tests that run on CRAN
- **Skipping all tests on CRAN:** Some mocked tests should run on CRAN to catch integration issues
- **Hardcoding mock responses:** Use httptest2 recording to match real API structure
- **Mocking too deeply:** Mock at the boundary (processx::run, httr2 requests), not internal logic

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP response recording | Manual JSON fixtures | httptest2::with_mock_dir() | Automatic recording, URL-based file naming |
| Function mocking | Reassigning in .GlobalEnv | local_mocked_bindings() | Proper scoping, cleanup, namespace handling |
| Test isolation | Manual setup/teardown | withr::defer() | Automatic cleanup even on test failure |
| Skipping tests | Manual conditionals | skip_on_cran(), skip_if_offline() | Standard, understood by CRAN |
| CLI output testing | Output capture | testthat::expect_output() | Handles encoding, ANSI codes |

**Key insight:** The R testing ecosystem has mature solutions for all common mocking scenarios. httptest2 specifically addresses httr2's patterns.

## Common Pitfalls

### Pitfall 1: Real API Calls Escaping to CRAN
**What goes wrong:** Tests make network requests, fail on CRAN due to network isolation
**Why it happens:** Forgot to wrap test in httptest2 context, or mock directory missing
**How to avoid:**
1. Use httptest2::with_mock_dir() for ALL tests that could trigger HTTP
2. Run `R CMD check --as-cran` locally to catch escaping calls
3. Consider `httptest2::without_internet()` as a defensive wrapper
**Warning signs:** Tests pass locally but fail on CRAN with network errors

### Pitfall 2: Mocking processx::run Incorrectly
**What goes wrong:** Mocks don't apply because of namespace resolution with `::`
**Why it happens:** `local_mocked_bindings()` works on namespace bindings, not `::` calls
**How to avoid:**
1. Create wrapper functions in your package: `.run_process()` that calls `processx::run()`
2. Mock the wrapper, not the external function
3. Or import processx::run into your namespace
**Warning signs:** Tests fail saying "mock not applied"

### Pitfall 3: Cassette/Mock Files Not Committed
**What goes wrong:** Tests fail in CI because mock files not in git
**Why it happens:** Auto-generated mock directories ignored by .gitignore
**How to avoid:**
1. Explicitly add tests/testthat/api.openneuro.org/ to git
2. Never add *.json to .gitignore in tests directory
3. Review generated mocks before committing
**Warning signs:** Tests pass locally, fail in CI with "no mock found"

### Pitfall 4: Fragile Mocks Tied to Response Content
**What goes wrong:** Tests break when API response format changes slightly
**Why it happens:** Testing exact response structure instead of semantic content
**How to avoid:**
1. Test what matters: `expect_true(nrow(result) > 0)` not exact row count
2. Use `expect_s3_class()` for type checking
3. Pin to specific dataset IDs that are stable (ds000001)
**Warning signs:** Tests break after API updates even when behavior is correct

### Pitfall 5: Test Timing on CRAN
**What goes wrong:** CRAN check times out or complains about slow tests
**Why it happens:** Tests take too long, CRAN has strict time limits
**How to avoid:**
1. Target < 60 seconds total test runtime
2. Use `skip_on_cran()` for slow integration tests
3. Keep each test focused and fast
**Warning signs:** NOTE about test timing, or check timeout

### Pitfall 6: Examples That Hit Network
**What goes wrong:** Examples in man pages make network calls, fail on CRAN
**Why it happens:** `@examples` run during R CMD check
**How to avoid:**
1. Use `\dontrun{}` for examples that need network
2. Or use `if (interactive())` guards
3. Consider mockable examples only for documentation
**Warning signs:** Examples fail during check

## Code Examples

Verified patterns from official sources:

### Setup helper-httptest2.R
```r
# Source: https://enpiar.com/httptest2/articles/httptest2.html
# tests/testthat/helper-httptest2.R

library(httptest2)
```

### Basic HTTP Test with Mocking
```r
# Source: https://enpiar.com/httptest2/articles/httptest2.html

test_that("on_search returns tibble of datasets", {
  with_mock_dir("api.openneuro.org", {
    result <- on_search(limit = 5)
    expect_s3_class(result, "tbl_df")
    expect_named(result, c("id", "name", "created", "public", "modalities", "n_subjects", "tasks"))
  })
})
```

### Testing Error Conditions
```r
# Test network error handling
test_that("on_request handles network errors gracefully", {
  httptest2::without_internet({
    expect_error(
      on_request("query { datasets { id } }"),
      class = "openneuro_network_error"
    )
  })
})
```

### Mocking CLI Backend Calls
```r
# tests/testthat/test-backends.R

test_that(".backend_available detects missing AWS CLI", {
  # Mock the internal wrapper to return empty string
  local_mocked_bindings(
    .find_aws_cli = function() ""
  )

  expect_false(.backend_available("s3"))
})

test_that(".backend_available detects present DataLad", {
  local_mocked_bindings(
    Sys.which = function(names) {
      result <- setNames(rep("", length(names)), names)
      if ("datalad" %in% names) result["datalad"] <- "/usr/bin/datalad"
      if ("git-annex" %in% names) result["git-annex"] <- "/usr/bin/git-annex"
      result
    }
  )

  expect_true(.backend_available("datalad"))
})
```

### Testing on_doctor() Output
```r
test_that("on_doctor returns structured list invisibly", {
  # Mock all backend checks
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) {
      backend == "https"  # Only HTTPS available in test
    }
  )

  result <- on_doctor()

  expect_s3_class(result, "openneuro_doctor")
  expect_named(result, c("https", "s3", "datalad"))
  expect_true(result$https$available)
  expect_false(result$s3$available)
})

test_that("on_doctor prints styled output", {
  local_mocked_bindings(
    .backend_status = function(...) TRUE
  )

  expect_output(print(on_doctor()), "OpenNeuro")
})
```

### Fixture for Predictable Cache Tests
```r
# tests/testthat/helper-mocks.R

# Create temporary cache directory for tests
local_temp_cache <- function(env = parent.frame()) {
  tmp <- withr::local_tempdir(.local_envir = env)
  withr::local_options(openneuro.cache_root = tmp, .local_envir = env)
  tmp
}

# Usage in test:
test_that("on_cache_list returns empty tibble for fresh cache", {
  cache_dir <- local_temp_cache()
  result <- on_cache_list()
  expect_equal(nrow(result), 0)
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| with_mock() | local_mocked_bindings() | testthat 3.0 (2020) | Required for R >= 4.5.0 |
| httptest | httptest2 | 2022 | Native httr2 support |
| vcr YAML | vcr JSON (optional) | vcr 2.0 | Either works, JSON more readable |
| Manual cassettes | Auto-recording | httptest2 1.0 | Less manual fixture creation |

**Deprecated/outdated:**
- `with_mock()` / `local_mock()`: Removed in testthat 3.3.0, doesn't work in R 4.5.0+
- httptest (v1): Use httptest2 for httr2 packages
- mockery::stub(): Still works but `local_mocked_bindings()` is preferred

## CRAN Policy Compliance

### Key CRAN Requirements (Source: cran.r-project.org/web/packages/policies.html)

| Requirement | How to Comply |
|-------------|---------------|
| Graceful network failure | Use tryCatch with informative error messages |
| No network calls in tests | Use httptest2 mocking for all HTTP tests |
| Fast check time | Keep total test time < 60 seconds |
| Examples run without error | Use `\dontrun{}` or `if(interactive())` for network examples |
| Cross-platform | Test on Windows, macOS, Linux via GitHub Actions |

### Environment Variables for Testing

| Variable | Purpose | How Used |
|----------|---------|----------|
| `NOT_CRAN` | Indicates non-CRAN environment | Set by devtools::check(), enables `skip_on_cran()` |
| `OPENNEURO_LIVE_TESTS` | Enable real API tests | Optional for maintainer-only live testing |

### Test Classification Strategy

| Test Type | Where to Run | How to Control |
|-----------|--------------|----------------|
| Mocked HTTP tests | CRAN + CI | Always run (httptest2) |
| Mocked CLI tests | CRAN + CI | Always run (local_mocked_bindings) |
| Live API tests | CI only | `skip_on_cran()` + env var check |
| Slow integration tests | CI only | `skip_on_cran()` |

## Open Questions

Things that couldn't be fully resolved:

1. **Mock file size for GraphQL responses**
   - What we know: httptest2 stores full responses; GraphQL can have large payloads
   - What's unclear: Whether to trim/redact large responses manually
   - Recommendation: Start with auto-recording, manually trim if package size becomes issue

2. **Testing backend fallback chain**
   - What we know: Need to test DataLad -> S3 -> HTTPS fallback
   - What's unclear: Best way to simulate "backend fails mid-download"
   - Recommendation: Mock at .download_backend level, test dispatch logic separately

3. **Version detection for CLI tools**
   - What we know: CONTEXT.md says "no minimum version enforcement"
   - What's unclear: Whether to run version commands or just presence check
   - Recommendation: Run version command when available, fall back to "unknown" if fails

## Sources

### Primary (HIGH confidence)
- [httptest2 documentation](https://enpiar.com/httptest2/) - Setup, usage, mock file organization
- [testthat mocking vignette](https://testthat.r-lib.org/articles/mocking.html) - local_mocked_bindings() usage
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html) - Network and test requirements
- [R Packages book - R CMD check](https://r-pkgs.org/R-CMD-check.html) - Check categories and requirements

### Secondary (MEDIUM confidence)
- [rOpenSci HTTP Testing book](https://books.ropensci.org/http-testing/) - Comprehensive HTTP testing guide
- [testthat test fixtures](https://testthat.r-lib.org/articles/test-fixtures.html) - Fixture patterns
- [cli package reference](https://cli.r-lib.org/reference/) - Styled output functions
- [devtools::dev_sitrep](https://devtools.r-lib.org/reference/dev_sitrep.html) - Diagnostic function pattern

### Tertiary (LOW confidence)
- WebSearch results for general patterns - Verified with primary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - httptest2 and testthat 3 are well-documented, official solutions
- Architecture: HIGH - Patterns from official documentation
- Pitfalls: HIGH - Documented in rOpenSci book and CRAN policies
- CRAN compliance: HIGH - Direct from CRAN policy document

**Research date:** 2026-01-21
**Valid until:** 60 days (stable ecosystem, testthat 3 is mature)
