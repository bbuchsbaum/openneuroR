# Phase 9: Discovery Foundation - Research

**Researched:** 2026-01-23
**Domain:** Derivative dataset discovery via GitHub API and OpenNeuro API
**Confidence:** HIGH

## Summary

This phase implements derivative dataset discovery for OpenNeuro datasets. Users can discover available pre-processed derivatives (fMRIPrep, MRIQC, etc.) from two sources: (1) embedded derivatives within OpenNeuro datasets (in a `derivatives/` folder), and (2) the OpenNeuroDerivatives GitHub organization which hosts 784+ pre-computed fMRIPrep and MRIQC datasets.

The primary challenge is managing GitHub API rate limits (60 requests/hour unauthenticated) while providing a good user experience. The solution involves session-based in-memory caching using a closure pattern (avoiding locked package namespace issues) and httr2's rate limit handling for graceful error handling with retry-after information.

**Primary recommendation:** Use httr2 directly for GitHub API calls (simpler than adding `gh` dependency), implement a closure-based session cache for the GitHub organization repository list, and use the existing `on_files()` function to detect embedded derivatives by checking for `derivatives/` directories.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | >= 1.2.1 | GitHub REST API calls | Already in package, handles rate limiting well |
| tibble | >= 3.2.0 | Output format | Already in package, consistent with existing API |
| rlang | >= 1.1.0 | Error handling | Already in package, custom error classes |
| cli | >= 3.6.0 | User messaging | Already in package, rate limit warnings |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jsonlite | >= 1.8.0 | Parse GitHub API responses | Already in package |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| httr2 for GitHub | gh package | gh is purpose-built for GitHub but adds dependency; httr2 already available |
| Closure cache | memoise package | memoise adds dependency; closure pattern is 10 lines of base R |
| Manual caching | cachem package | cachem is more sophisticated but overkill for session cache |

**Installation:**
```bash
# No new packages needed - all dependencies already in DESCRIPTION
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── discovery.R           # Main on_derivatives() function
├── discovery-github.R    # GitHub API interactions for OpenNeuroDerivatives
├── discovery-embedded.R  # Embedded derivatives detection via OpenNeuro API
├── discovery-cache.R     # Session cache management (closure pattern)
```

### Pattern 1: Closure-Based Session Cache
**What:** Store mutable state across function calls without adding dependencies or hitting locked namespace issues
**When to use:** Session-scoped caching of GitHub API results
**Example:**
```r
# Source: R-hub blog (https://blog.r-hub.io/2021/07/30/cache/)
# and hydroecology.net pattern

# In R/discovery-cache.R
.discovery_cache_store <- function() {
  .cache <- list()

  list(
    get = function(key) .cache[[key]],
    set = function(key, value) {
      .cache[[key]] <<- value
      invisible(value)
    },
    has = function(key) key %in% names(.cache),
    clear = function() {
      .cache <<- list()
      invisible(TRUE)
    }
  )
}

# Initialize at package load (in zzz.R or discovery-cache.R)
.discovery_cache <- .discovery_cache_store()
```

### Pattern 2: GitHub API Rate Limit Handling with httr2
**What:** Detect 403 rate limit errors and extract retry-after time
**When to use:** All GitHub API calls
**Example:**
```r
# Source: httr2 vignette (https://httr2.r-lib.org/articles/wrapping-apis.html)

.github_is_transient <- function(resp) {
  httr2::resp_status(resp) == 403 &&
    identical(httr2::resp_header(resp, "X-RateLimit-Remaining"), "0")
}

.github_after <- function(resp) {

  reset_time <- as.numeric(httr2::resp_header(resp, "X-RateLimit-Reset"))
  max(0, reset_time - as.numeric(Sys.time()))
}

.github_request <- function(endpoint) {
  httr2::request("https://api.github.com") |>
    httr2::req_url_path_append(endpoint) |>
    httr2::req_headers(
      "Accept" = "application/vnd.github+json",
      "User-Agent" = paste0("openneuro-r/", packageVersion("openneuro"))
    ) |>
    httr2::req_retry(
      max_tries = 3,
      is_transient = .github_is_transient,
      after = .github_after
    ) |>
    httr2::req_throttle(rate = 30 / 60, realm = "api.github.com")  # Stay well under 60/hr
}
```

### Pattern 3: Embedded Derivatives Detection
**What:** Use existing `on_files()` to check for derivatives/ directory
**When to use:** Checking OpenNeuro dataset for embedded derivatives
**Example:**
```r
# Use existing on_files() function to check root directory
.detect_embedded_derivatives <- function(dataset_id, tag = NULL, client = NULL) {
  files <- on_files(dataset_id, tag = tag, client = client)

  # Look for derivatives/ directory
  deriv_dirs <- files[files$directory & files$filename == "derivatives", ]

  if (nrow(deriv_dirs) == 0) {
    return(tibble::tibble())  # No embedded derivatives
  }

  # List contents of derivatives/ to get pipeline names
  deriv_key <- deriv_dirs$key[1]
  deriv_contents <- on_files(dataset_id, tag = tag, tree = deriv_key, client = client)

  # Each directory is a pipeline
  pipelines <- deriv_contents[deriv_contents$directory, ]
  # ... build tibble with pipeline info
}
```

### Anti-Patterns to Avoid
- **Direct environment modification:** Don't use `assign()` to package environment - namespace is locked after load
- **Caching entire file trees:** Don't cache all metadata for 784 repos - cache only the repo list
- **Blocking on rate limits silently:** User requested error on rate limit, not silent failure
- **Hardcoded repo count:** Don't assume 784 repos - paginate to get all

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Human-readable sizes | Format bytes manually | `.format_bytes()` | Already implemented in download-progress.R |
| File listing | Custom S3/HTTP calls | `on_files()` | Already handles pagination, auth, errors |
| HTTP retries | try/catch loops | `httr2::req_retry()` | Handles backoff, rate limits properly |
| GitHub pagination | Manual page tracking | httr2 with Link header parsing | Standard pattern, fewer bugs |
| Timestamp formatting | strptime/format | `.parse_timestamp()` | Already in utils-response.R |

**Key insight:** The package already has utilities for sizes, timestamps, HTTP requests, and file operations. Discovery should leverage these rather than duplicating.

## Common Pitfalls

### Pitfall 1: GitHub API Rate Limit Exhaustion
**What goes wrong:** 60 requests/hour for unauthenticated users; paginating 784 repos at 100/page = 8 requests minimum
**Why it happens:** Multiple calls to `on_derivatives()` for different datasets exhaust limit quickly
**How to avoid:**
- Cache the full repo list at session level (one-time cost of ~8 requests)
- Filter cached list in-memory for specific datasets
- Throttle to 30/hour to leave headroom
**Warning signs:** 403 responses with `X-RateLimit-Remaining: 0`

### Pitfall 2: Assuming Repo Name Format
**What goes wrong:** Parsing dataset ID from repo names like "ds000102-fmriprep" may break on edge cases
**Why it happens:** Assuming format is always `{dataset_id}-{pipeline}` without verification
**How to avoid:**
- Use regex with validation: `^(ds\\d{6})-(fmriprep|mriqc|fitlins)$`
- Log/skip unparseable repo names gracefully
- Don't error on unexpected repos (org may have non-derivative repos)
**Warning signs:** Repos named differently (e.g., "OpenNeuroDerivatives" superdataset repo)

### Pitfall 3: Stale Cache with No Refresh
**What goes wrong:** New derivatives added to OpenNeuroDerivatives not discovered
**Why it happens:** Session cache never expires, no way to force refresh
**How to avoid:**
- Implement `refresh = TRUE` parameter (user decision)
- Cache is cleared on package unload or R session end (session-scoped)
- Consider timestamp-based staleness check (optional)
**Warning signs:** User reports missing known derivatives

### Pitfall 4: Blocking on Rate Limit Without Info
**What goes wrong:** Function hangs or errors without telling user when to retry
**Why it happens:** httr2 retry waits silently; error messages don't include reset time
**How to avoid:**
- On rate limit error, compute and report retry-after time in human-readable form
- Use `cli::cli_abort()` with informative message including wait time
**Warning signs:** User doesn't know how long to wait

### Pitfall 5: Empty Tibble Column Mismatches
**What goes wrong:** Returning empty tibble with different columns than non-empty case
**Why it happens:** Forgetting to create properly-typed empty tibble for "no results" case
**How to avoid:**
- Define `.empty_derivatives_tibble()` helper (like existing `.empty_datasets_tibble()`)
- Use it for all early returns
**Warning signs:** Column errors when binding results

## Code Examples

Verified patterns from official sources and existing codebase:

### GitHub API Pagination
```r
# Source: GitHub REST API docs (https://docs.github.com/en/rest/repos/repos)
.list_github_org_repos <- function(org, per_page = 100) {
  all_repos <- list()
  page <- 1

  repeat {
    resp <- .github_request(paste0("orgs/", org, "/repos")) |>
      httr2::req_url_query(per_page = per_page, page = page) |>
      httr2::req_perform()

    repos <- httr2::resp_body_json(resp)

    if (length(repos) == 0) break

    all_repos <- c(all_repos, repos)

    # Check for more pages via Link header
    link_header <- httr2::resp_header(resp, "Link")
    if (is.null(link_header) || !grepl('rel="next"', link_header)) break

    page <- page + 1
  }

  all_repos
}
```

### Rate Limit Error with Retry Time
```r
# Source: GitHub docs + httr2 patterns
.handle_rate_limit_error <- function(resp) {
  remaining <- httr2::resp_header(resp, "X-RateLimit-Remaining")
  reset_epoch <- as.numeric(httr2::resp_header(resp, "X-RateLimit-Reset"))
  reset_time <- as.POSIXct(reset_epoch, origin = "1970-01-01", tz = "UTC")
  wait_seconds <- max(0, reset_epoch - as.numeric(Sys.time()))
  wait_human <- if (wait_seconds > 60) {
    paste0(round(wait_seconds / 60, 1), " minutes")
  } else {
    paste0(round(wait_seconds), " seconds")
  }

  rlang::abort(
    c("GitHub API rate limit exceeded",
      "x" = "No remaining requests (60/hour for unauthenticated)",
      "i" = paste0("Rate limit resets at: ", format(reset_time, "%H:%M:%S %Z")),
      "i" = paste0("Wait approximately: ", wait_human),
      "i" = "Set GITHUB_PAT environment variable for higher limits (5000/hr)"),
    class = "openneuro_rate_limit_error"
  )
}
```

### Main Discovery Function Signature
```r
# Follows existing package patterns from api-dataset.R, api-files.R
#' Discover Available Derivative Datasets
#'
#' Lists available derivative pipelines (fMRIPrep, MRIQC, etc.) for an OpenNeuro dataset.
#' Checks both embedded derivatives within the dataset and the OpenNeuroDerivatives
#' GitHub organization.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#' @param sources Character vector specifying sources to check. Options:
#'   "embedded" (derivatives folder in dataset), "openneuro-derivatives"
#'   (OpenNeuroDerivatives GitHub org), or both (default).
#' @param refresh If TRUE, bypass cache and fetch fresh data. Default FALSE.
#' @param client An `openneuro_client` object for embedded source. If NULL,
#'   creates default client.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{dataset_id}{Original dataset identifier}
#'     \item{pipeline}{Pipeline name (e.g., "fmriprep", "mriqc")}
#'     \item{source}{Where found: "embedded" or "openneuro-derivatives"}
#'     \item{version}{Dataset/derivative version tag (if available)}
#'     \item{n_subjects}{Number of subjects (if available)}
#'     \item{n_files}{Number of files (if available)}
#'     \item{total_size}{Total size as human-readable string (if available)}
#'     \item{last_modified}{Last modification date (if available)}
#'     \item{s3_url}{S3 URL for direct access (OpenNeuroDerivatives only)}
#'   }
#'
#' @export
on_derivatives <- function(dataset_id,
                           sources = c("embedded", "openneuro-derivatives"),
                           refresh = FALSE,
                           client = NULL) {
  # Implementation...
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DataLad clone for derivatives | S3 direct access | 2023 | No git-annex required for OpenNeuroDerivatives |
| No standard derivatives location | BIDS derivatives/ folder spec | BIDS 1.4.0 | Embedded derivatives discoverable |
| Manual derivative finding | OpenNeuroDerivatives org | 2022 | 784+ pre-computed datasets available |

**Deprecated/outdated:**
- None identified - OpenNeuroDerivatives is actively maintained with new datasets added regularly

## Open Questions

Things that couldn't be fully resolved:

1. **Metadata for OpenNeuroDerivatives beyond repo name**
   - What we know: GitHub API returns repo name, size, pushed_at, description
   - What's unclear: Subject count, file count require additional API calls or dataset inspection
   - Recommendation: For initial implementation, populate only what's available from org repo list (name, pipeline, pushed_at); mark other columns as NA. Phase 11 can fetch detailed metadata lazily.

2. **OpenNeuroDerivatives S3 URL pattern verification**
   - What we know: Pattern is `s3://openneuro-derivatives/{pipeline}/{dataset_id}-{pipeline}/`
   - What's unclear: Whether all repos follow this exact pattern
   - Recommendation: Generate URL from pattern but test with one known dataset; document assumption

3. **GITHUB_PAT usage for higher rate limits**
   - What we know: With PAT, rate limit is 5000/hr vs 60/hr unauthenticated
   - What's unclear: Whether to document/encourage this for heavy users
   - Recommendation: Include in error message; don't require it

## Sources

### Primary (HIGH confidence)
- GitHub REST API Docs: https://docs.github.com/en/rest/repos/repos - Organization repos endpoint, rate limits
- httr2 Vignette: https://httr2.r-lib.org/articles/wrapping-apis.html - Rate limit handling pattern
- OpenNeuroDerivatives GitHub: https://github.com/OpenNeuroDerivatives - 784 repos, naming conventions
- BIDS Derivatives Spec: https://bids-specification.readthedocs.io/en/stable/common-principles.html - derivatives/ folder structure

### Secondary (MEDIUM confidence)
- R-hub Blog: https://blog.r-hub.io/2021/07/30/cache/ - Closure caching pattern
- hydroecology.net: https://hydroecology.net/implementing-session-cache-r-packages/ - Session cache implementation
- memoise Package: https://memoise.r-lib.org/ - Alternative caching approach (not used but researched)

### Tertiary (LOW confidence)
- None - all findings verified with primary/secondary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in package, patterns verified with official docs
- Architecture: HIGH - Closure pattern well-documented, httr2 rate limiting verified
- Pitfalls: HIGH - Rate limits documented by GitHub, cache issues documented in R ecosystem

**Research date:** 2026-01-23
**Valid until:** 2026-03-23 (60 days - GitHub API is stable, OpenNeuroDerivatives actively growing)
