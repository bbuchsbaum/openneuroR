# Stack Research: openneuro R Package

**Project:** openneuro - R package for programmatic OpenNeuro access
**Researched:** 2026-01-20
**Overall Confidence:** HIGH

## Executive Summary

The 2025 R ecosystem for building API-wrapping data access packages is mature and well-defined. The core stack centers on httr2 for HTTP, ghql for GraphQL, and the r-lib ecosystem (cli, rlang, fs, withr) for infrastructure. For a CRAN-bound package targeting neuroimaging researchers, prioritize stability, minimal dependencies, and graceful degradation when optional backends (DataLad, AWS CLI) are unavailable.

---

## Recommended Stack

### Core HTTP/API Layer

| Technology | Version | Purpose | Confidence |
|------------|---------|---------|------------|
| **httr2** | >= 1.2.1 | HTTP requests, OAuth, rate limiting | HIGH |
| **ghql** | >= 0.1.2 | GraphQL client (R6-based) | HIGH |
| **curl** | >= 7.0.0 | Low-level downloads, progress bars | HIGH |
| **jsonlite** | >= 1.8.9 | JSON parsing/generation | HIGH |

**Rationale:**

- **httr2** is the modern successor to httr, explicitly recommended by r-lib for new packages. It provides pipe-based API, built-in rate limiting (`req_throttle()`), automatic retries (`req_retry()`), and secure credential handling. Version 1.2.0+ includes parallel request support with `req_perform_parallel()`.

- **ghql** is the only CRAN-ready GraphQL client for R, maintained by rOpenSci. It uses R6 for connection management and integrates well with httr2/crul backends. OpenNeuro's API is GraphQL-native, making this essential.

- **curl** (not httr2) for bulk file downloads because `curl_download()` is optimized for large files with progress callbacks. httr2's `req_progress()` is good for API calls but curl is better for multi-GB neuroimaging data.

- **jsonlite** over yyjsonr because: (1) jsonlite is a universal dependency already pulled in by httr2/ghql, (2) yyjsonr's 2-10x speed gain is irrelevant for API metadata parsing, (3) CRAN-bound packages should minimize exotic dependencies.

### Caching Layer

| Technology | Version | Purpose | Confidence |
|------------|---------|---------|------------|
| **cachem** | >= 1.1.0 | In-memory + disk caching with pruning | HIGH |
| **memoise** | >= 2.0.0 | Function memoization (uses cachem) | HIGH |
| **rappdirs** | >= 0.3.3 | XDG-compliant cache directories | HIGH |
| **fs** | >= 1.6.6 | File system operations | HIGH |

**Rationale:**

- **cachem** provides automatic pruning (LRU eviction, max size/age limits) which is critical for neuroimaging data that can be gigabytes. `cache_disk()` handles persistent caching; `cache_layered()` allows memory + disk tiers.

- **memoise** wraps expensive functions (GraphQL queries, schema introspection) with automatic caching. Version 2.0+ uses cachem internally for race-condition-free operation.

- **rappdirs** ensures cross-platform cache location compliance (XDG on Linux, `~/Library/Caches` on macOS, `AppData/Local` on Windows). CRAN policy requires proper user directory handling.

- **fs** over base R file operations for: vectorization, UTF-8 consistency, explicit errors (not warnings), and tidyverse integration.

**Cache Architecture:**

```r
# Two-tier caching strategy
on_cache_dir <- function() {
  rappdirs::user_cache_dir("openneuro", "openneuro")
}

# Metadata cache (small, frequent)
metadata_cache <- cachem::cache_disk(
  dir = fs::path(on_cache_dir(), "metadata"),
  max_size = 100 * 1024^2,  # 100 MB
  max_age = 86400           # 24 hours
)

# Data cache (large, manifest-tracked)
data_cache <- cachem::cache_disk(
  dir = fs::path(on_cache_dir(), "data"),
  max_size = 50 * 1024^3,   # 50 GB default
  evict = "lru"
)
```

### CLI/External Tool Integration

| Technology | Version | Purpose | Confidence |
|------------|---------|---------|------------|
| **processx** | >= 3.8.0 | External process execution | HIGH |
| **sys** | >= 3.4.0 | Simple CLI calls (lighter weight) | MEDIUM |

**Rationale:**

- **processx** for DataLad/datalad-cli and AWS CLI integration. Key features:
  - No shell quoting issues (args passed directly)
  - Timeout support (critical for hanging datalad operations)
  - Real-time stdout/stderr capture
  - Background process support
  - Cross-platform (Windows/macOS/Linux)

- **sys** as lighter alternative for simple one-shot commands where processx is overkill.

**Pattern for Optional CLI Backends:**

```r
has_datalad <- function() {
  tryCatch({
    result <- processx::run("datalad", "--version", error_on_status = FALSE)
    result$status == 0
  }, error = function(e) FALSE)
}

has_aws_cli <- function() {
  tryCatch({
    result <- processx::run("aws", "--version", error_on_status = FALSE)
    result$status == 0
  }, error = function(e) FALSE)
}
```

### S3 Backend (Optional)

| Technology | Version | Purpose | Confidence |
|------------|---------|---------|------------|
| **paws.storage** | >= 0.7.0 | Native R S3 access | MEDIUM |
| **aws.s3** (cloudyr) | >= 0.3.22 | Alternative S3 client | MEDIUM |

**Recommendation:** Use **paws.storage** in Suggests, not Imports.

**Rationale:**

- OpenNeuro's S3 bucket (`openneuro.org`, us-east-1) is publicly accessible with anonymous credentials
- paws.storage supports `anonymous = TRUE` for credential-free access
- paws is more actively maintained and covers full AWS SDK
- aws.s3 is lighter but less complete

**However:** For v1, prefer AWS CLI via processx or plain HTTPS downloads. S3 SDK adds complexity for minimal benefit over `--no-sign-request` with AWS CLI.

```r
# S3 via AWS CLI (simpler, recommended for v1)
download_s3_cli <- function(s3_uri, dest) {
  processx::run(
    "aws", c("s3", "cp", "--no-sign-request", s3_uri, dest),
    timeout = 3600  # 1 hour timeout
  )
}

# S3 via paws (for future, if needed)
download_s3_native <- function(bucket, key, dest) {
  svc <- paws.storage::s3(
    config = list(
      credentials = list(anonymous = TRUE),
      region = "us-east-1"
    )
  )
  svc$download_file(Bucket = bucket, Key = key, Filename = dest)
}
```

### User Interface Layer

| Technology | Version | Purpose | Confidence |
|------------|---------|---------|------------|
| **cli** | >= 3.6.0 | Progress bars, messages, theming | HIGH |
| **rlang** | >= 1.1.0 | Errors, conditions, tidy eval | HIGH |
| **withr** | >= 3.0.0 | Temporary state management | HIGH |
| **tibble** | >= 3.2.0 | Data frame returns | HIGH |

**Rationale:**

- **cli** is the modern standard for R package user feedback. `cli_progress_bar()` integrates with httr2/curl downloads. Bullet-point error messages are cleaner than base R.

- **rlang** for `abort()`, `warn()`, `inform()` with structured error metadata. Integrates with cli for formatted output. Required for tidy eval if doing NSE.

- **withr** for `local_options()`, `local_envvar()`, `defer()`. Essential for test fixtures and temporary state (e.g., changing cache dir in tests).

- **tibble** because the neuroimaging R community expects tidyverse-style returns. `on_search()` should return a tibble, not a data.frame.

### Development/Testing

| Technology | Version | Purpose | Confidence |
|------------|---------|---------|------------|
| **testthat** | >= 3.2.0 | Unit testing | HIGH |
| **vcr** | >= 1.6.0 | HTTP mocking/recording | HIGH |
| **webmockr** | >= 1.0.0 | HTTP stubbing | HIGH |
| **httptest2** | >= 1.0.0 | httr2-specific mocking | MEDIUM |
| **covr** | >= 3.6.0 | Code coverage | HIGH |
| **roxygen2** | >= 7.3.0 | Documentation | HIGH |
| **pkgdown** | >= 2.0.0 | Website generation | HIGH |

**Rationale:**

- **vcr** records real API responses as "cassettes" for deterministic tests. Essential for GraphQL testing where responses are complex.

- **webmockr** for stubbing error conditions (502, rate limits) without hitting real API.

- Tests should work offline after initial cassette recording.

```r
# tests/testthat/helper-vcr.R
library(vcr)
vcr::vcr_configure(
  dir = "fixtures",
  filter_sensitive_data = list("<<API_KEY>>" = Sys.getenv("OPENNEURO_API_KEY"))
)
```

---

## HTTP/API Layer Details

### httr2 Request Pattern

```r
on_request <- function(query, variables = NULL) {
  req <- httr2::request("https://openneuro.org/crn/graphql") |>
    httr2::req_headers(
      "Content-Type" = "application/json",
      "User-Agent" = paste0("openneuro-r/", packageVersion("openneuro"))
    ) |>
    httr2::req_body_json(list(
      query = query,
      variables = variables
    )) |>
    httr2::req_retry(
      max_tries = 3,
      is_transient = httr2::resp_status %in% c(429, 500, 502, 503)
    ) |>
    httr2::req_throttle(rate = 10 / 60)  # 10 requests per minute

  httr2::req_perform(req)
}
```

### ghql Client Pattern

```r
on_graphql_client <- function() {
  client <- ghql::GraphqlClient$new(
    url = "https://openneuro.org/crn/graphql",
    headers = list(
      "User-Agent" = paste0("openneuro-r/", packageVersion("openneuro"))
    )
  )
  client
}

on_query <- function(query_name) {
  query_path <- system.file("graphql", paste0(query_name, ".gql"),
                            package = "openneuro")
  if (query_path == "") {
    cli::cli_abort("Query {.val {query_name}} not found")
  }
  readLines(query_path, warn = FALSE) |> paste(collapse = "\n")
}
```

---

## Caching Layer Details

### Manifest-Tracked Downloads

```r
# Cache manifest structure
# ~/.cache/openneuro/manifest.json
# {
#   "ds000001/1.0.0/sub-01/anat/T1w.nii.gz": {
#     "downloaded": "2025-01-20T10:30:00Z",
#     "backend": "s3",
#     "size": 12345678,
#     "md5": "abc123..."
#   }
# }

on_manifest_path <- function() {
  fs::path(on_cache_dir(), "manifest.json")
}

on_manifest_read <- function() {
  path <- on_manifest_path()
  if (fs::file_exists(path)) {
    jsonlite::read_json(path)
  } else {
    list()
  }
}

on_manifest_write <- function(manifest) {
  jsonlite::write_json(manifest, on_manifest_path(), auto_unbox = TRUE, pretty = TRUE)
}
```

---

## What NOT to Use

### Do NOT Use

| Technology | Why Not |
|------------|---------|
| **httr** | Superseded by httr2; no longer recommended for new packages |
| **RCurl** | Legacy; curl package is modern replacement |
| **rjson** | jsonlite is standard; rjson has worse data frame handling |
| **yyjsonr** | Performance gain unnecessary for API work; adds exotic dependency |
| **plumber** | Server-side; not relevant for client package |
| **pins** | Over-engineered for this use case; better for sharing R objects, not downloading external data |
| **R.cache** | cachem is modern replacement with better pruning |
| **digest** | rlang::hash() preferred; fewer dependencies |
| **parallel/future** | Premature optimization; httr2::req_perform_parallel() sufficient |

### Avoid These Patterns

| Pattern | Why Avoid | Alternative |
|---------|-----------|-------------|
| `system()` / `system2()` | Shell quoting issues, no timeout control | `processx::run()` |
| `download.file()` | Inconsistent behavior across platforms | `curl::curl_download()` |
| `tryCatch()` everywhere | Verbose, loses context | `rlang::abort()` with `call` |
| `options()` for config | Global state pollution | Function arguments + env vars |
| `<<-` assignment | Side effects, hard to test | Return values, R6 if needed |
| Storing auth in package | Security risk | `keyring` or env vars |

---

## Confidence Assessment

| Component | Confidence | Rationale |
|-----------|------------|-----------|
| httr2 for HTTP | HIGH | Official r-lib recommendation, active development, CRAN-proven |
| ghql for GraphQL | HIGH | Only CRAN option, rOpenSci-maintained, matches use case |
| cachem for caching | HIGH | r-lib standard, used by memoise, well-tested |
| processx for CLI | HIGH | Industry standard for subprocess management |
| paws.storage for S3 | MEDIUM | Works but adds complexity; AWS CLI may be simpler |
| cli for UX | HIGH | Universal adoption in tidyverse ecosystem |
| vcr for testing | HIGH | rOpenSci standard for HTTP testing |

---

## Installation Commands

### Core Dependencies (Imports)

```r
# These go in DESCRIPTION Imports
install.packages(c(
  "httr2",      # >= 1.2.1
  "ghql",       # >= 0.1.2
  "curl",       # >= 7.0.0
  "jsonlite",   # >= 1.8.9
  "cachem",     # >= 1.1.0
  "memoise",    # >= 2.0.0
  "rappdirs",   # >= 0.3.3
  "fs",         # >= 1.6.6
  "cli",        # >= 3.6.0
  "rlang",      # >= 1.1.0
  "tibble",     # >= 3.2.0
  "withr",      # >= 3.0.0
  "processx"    # >= 3.8.0
))
```

### Optional Dependencies (Suggests)

```r
# These go in DESCRIPTION Suggests
install.packages(c(
  "paws.storage",  # For native S3 access
  "testthat",      # Testing
  "vcr",           # HTTP mocking
  "webmockr",      # HTTP stubbing
  "covr",          # Coverage
  "roxygen2",      # Docs
  "pkgdown",       # Website
  "knitr",         # Vignettes
  "rmarkdown"      # Vignettes
))
```

---

## DESCRIPTION File (Partial)

```
Imports:
    cachem (>= 1.1.0),
    cli (>= 3.6.0),
    curl (>= 7.0.0),
    fs (>= 1.6.6),
    ghql (>= 0.1.2),
    httr2 (>= 1.2.1),
    jsonlite (>= 1.8.9),
    memoise (>= 2.0.0),
    processx (>= 3.8.0),
    rappdirs (>= 0.3.3),
    rlang (>= 1.1.0),
    tibble (>= 3.2.0),
    withr (>= 3.0.0)
Suggests:
    covr,
    httptest2,
    knitr,
    paws.storage (>= 0.7.0),
    pkgdown,
    rmarkdown,
    testthat (>= 3.2.0),
    vcr (>= 1.6.0),
    webmockr (>= 1.0.0)
```

---

## Sources

### Primary (HIGH confidence)

- [httr2 CRAN](https://cran.r-project.org/web/packages/httr2/index.html) - Version 1.2.1, July 2025
- [httr2 Wrapping APIs Vignette](https://httr2.r-lib.org/articles/wrapping-apis.html)
- [ghql CRAN](https://cran.r-project.org/web/packages/ghql/index.html) - Version 0.1.2, September 2025
- [cachem r-lib](https://cachem.r-lib.org/) - Version 1.1.0
- [processx r-lib](https://processx.r-lib.org/) - Version 3.8.x
- [HTTP Testing in R Book](https://books.ropensci.org/http-testing/) - October 2025 update
- [R Packages (2e) - CRAN Chapter](https://r-pkgs.org/release.html)
- [OpenNeuro Documentation](https://docs.openneuro.org/architecture.html)

### Secondary (MEDIUM confidence)

- [paws.storage CRAN](https://cran.r-project.org/web/packages/paws.storage/paws.storage.pdf) - July 2025
- [rOpenSci System Commands Guide](https://ropensci.org/blog/2021/09/13/system-calls-r-package/)
- [pins Package Documentation](https://pins.rstudio.com/)
- [R-hub Caching Blog](https://blog.r-hub.io/2021/07/30/cache/)

---

# Addendum: bidser Integration (v1.1 Milestone)

**Researched:** 2026-01-22
**Confidence:** HIGH

## Stack Changes for bidser Integration

### Single Change: Add bidser to Suggests

```
Suggests:
    testthat (>= 3.0.0),
    httptest2,
    withr,
    bidser
```

**No version constraint** - bidser is at 0.0.0.9000 (development version).

### Why Suggests (Not Imports)

| Reason | Explanation |
|--------|-------------|
| **Optional functionality** | Core openneuroR download/search works without BIDS awareness |
| **Heavy dependency chain** | bidser pulls in neuroim2, data.tree, stringdist - not needed for basic use |
| **GitHub-only** | bidser is not on CRAN; Imports would block openneuroR CRAN submission |
| **No circular dependency** | bidser does not depend on openneuroR |

### No Additional Dependencies Needed

Shared dependencies already in openneuroR Imports:
- `rlang` - for `check_installed()` / `is_installed()`
- `fs` - filesystem operations
- `tibble`, `dplyr` - data frame manipulation
- `jsonlite` - JSON parsing

bidser-specific heavy deps (neuroim2, data.tree) stay isolated in bidser.

---

## CRAN-Compliant Integration Pattern

### Pattern 1: Functions Requiring bidser

Use `rlang::check_installed()` - already available since rlang is in Imports:

```r
#' Convert fetched handle to bids_project
#'
#' @param handle A fetched openneuro_handle
#' @return A bids_project object from bidser
#' @export
as_bids_project <- function(handle) {
  rlang::check_installed("bidser", reason = "to create BIDS projects")

  path <- on_path(handle)
  bidser::bids_project(path)
}
```

**Why rlang::check_installed() over base requireNamespace():**
- Already in Imports (no new dependency)
- Interactive install prompt in RStudio
- Better error message with `reason` parameter
- Returns invisibly on success (cleaner code flow)

### Pattern 2: Optional Enhancement Functions

For functions that work with or without bidser:

```r
#' Check if bidser is available
#' @return Logical
#' @keywords internal
has_bidser <- function() {
  rlang::is_installed("bidser")
}

#' Get participants from handle (enhanced with bidser if available)
#' @export
on_participants <- function(handle) {
  path <- on_path(handle)

  if (has_bidser()) {
    proj <- bidser::bids_project(path)
    bidser::participants(proj)
  } else {
    # Fallback: read participants.tsv directly
    pfile <- fs::path(path, "participants.tsv")
    if (fs::file_exists(pfile)) {
      readr::read_tsv(pfile, show_col_types = FALSE)
    } else {
      cli::cli_warn("No participants.tsv found; install bidser for BIDS parsing")
      NULL
    }
  }
}
```

### Pattern 3: For Tests

```r
test_that("as_bids_project creates valid bids_project", {
  testthat::skip_if_not_installed("bidser")

  # Test code using bidser
})
```

---

## Updated DESCRIPTION Suggests Section

```
Suggests:
    testthat (>= 3.0.0),
    httptest2,
    withr,
    bidser
```

**Note:** No version constraint on bidser since it is development-only (0.0.0.9000).

---

## User Documentation

Add to README or vignette:

```markdown
## BIDS Integration (Optional)

For BIDS-aware features, install bidser:

\`\`\`r
# Install bidser from GitHub
remotes::install_github("bbuchsbaum/bidser")

# Now BIDS functions are available
handle <- on_handle("ds000001") |> on_fetch()
proj <- as_bids_project(handle)
bidser::participants(proj)
\`\`\`
```

---

## Quality Gate Checklist

- [x] **CRAN-compliant**: bidser in Suggests, not Imports
- [x] **Rationale documented**: Suggests because optional, heavy deps, GitHub-only
- [x] **No circular dependency**: bidser does not depend on openneuroR
- [x] **Pattern uses existing deps**: rlang::check_installed() already available
- [x] **Test pattern**: testthat::skip_if_not_installed()

---

## Sources

- [R Packages (2e) - Dependencies in Practice](https://r-pkgs.org/dependencies-in-practice.html)
- [bidser GitHub](https://github.com/bbuchsbaum/bidser) - version 0.0.0.9000
- [rlang check_installed documentation](https://rlang.r-lib.org/reference/is_installed.html)

---

# Addendum: fMRIPrep Derivative Discovery Stack (Milestone 2)

**Researched:** 2026-01-22
**Confidence:** HIGH (verified against existing codebase, official docs, CRAN)

## Executive Summary

fMRIPrep derivative discovery requires **ZERO new CRAN dependencies**. The existing stack (httr2, processx, fs, dplyr, tibble, cli, rlang, jsonlite) fully supports this capability. The only consideration is optional enhancement of the existing `bidser` Suggests dependency.

**Key finding:** OpenNeuroDerivatives is a **separate GitHub organization** from OpenNeuroDatasets. Derivatives are accessed via:
1. **GitHub API** - List available derivative datasets (httr2 handles this)
2. **DataLad** - Clone from `github.com/OpenNeuroDerivatives/{dataset_id}-fmriprep`
3. **S3 embedded** - `s3://openneuro/{dataset_id}/{version}/uncompressed/derivatives/`
4. **S3 OpenNeuroDerivatives** - `s3://openneuro-derivatives/fmriprep/{dataset_id}-fmriprep`

## Stack Additions for Derivative Discovery

### Required Additions: NONE

The current stack already handles all derivative discovery needs:

| Capability Needed | Existing Technology | How It's Used |
|-------------------|---------------------|---------------|
| GitHub API calls | httr2 >= 1.2.1 | List OpenNeuroDerivatives org repos |
| GitHub pagination | httr2 `req_url_query()` | `per_page`, `page` params |
| DataLad cloning | processx >= 3.8.0 | Different GitHub org URL |
| S3 sync | processx + AWS CLI | Different S3 paths |
| File listing | on_files() + GraphQL | `tree="derivatives"` parameter |
| Path manipulation | fs >= 1.6.6 | Build derivative paths |
| User feedback | cli >= 3.6.0 | Progress for discovery |

### Explicitly NOT Adding

| Library | Why NOT to Add |
|---------|----------------|
| **gh** (>= 1.5.0) | Adds CRAN dependency for ~50 lines of code that httr2 handles natively |
| **paws.storage** | AWS CLI via processx is already working; no benefit for public buckets |
| **aws.s3** | Same as above - adds complexity without benefit |

**gh package rejection rationale:**
- gh adds transitively: gitcreds, glue, ini (3 new dependencies)
- GitHub API pagination is straightforward with httr2's `req_url_query()`
- The `.limit` auto-pagination in gh is convenient but not worth the dependency cost
- Package already depends on httr2; adding gh wrapper adds no capability

## Integration with Existing Code

### 1. GitHub API for Derivative Discovery (httr2)

```r
#' List available fMRIPrep derivatives from OpenNeuroDerivatives
#' @keywords internal
.list_openneuro_derivatives <- function(type = "fmriprep") {
  # Uses existing httr2 - NO NEW DEPENDENCY
  base_url <- "https://api.github.com/orgs/OpenNeuroDerivatives/repos"

  all_repos <- list()
  page <- 1

  repeat {
    req <- httr2::request(base_url) |>
      httr2::req_url_query(per_page = 100, page = page, type = "public") |>
      httr2::req_headers(
        "Accept" = "application/vnd.github+json",
        "User-Agent" = paste0("openneuro-r/", packageVersion("openneuro"))
      ) |>
      httr2::req_retry(max_tries = 3)

    resp <- httr2::req_perform(req)
    repos <- httr2::resp_body_json(resp)

    if (length(repos) == 0) break
    all_repos <- c(all_repos, repos)
    page <- page + 1
  }

  # Filter by type suffix (e.g., "-fmriprep")
  pattern <- paste0("-", type, "$")
  names <- vapply(all_repos, function(r) r$name, character(1))
  matches <- grepl(pattern, names)

  tibble::tibble(
    derivative_repo = names[matches],
    source_dataset = sub(pattern, "", names[matches]),
    type = type,
    github_url = vapply(all_repos[matches], function(r) r$html_url, character(1))
  )
}
```

### 2. DataLad Backend Extension

Extend existing `.download_datalad()` in `backend-datalad.R`:

```r
# CURRENT (raw datasets):
github_url <- paste0("https://github.com/OpenNeuroDatasets/", dataset_id, ".git")

# NEW (derivatives):
github_url <- paste0("https://github.com/OpenNeuroDerivatives/", dataset_id, "-fmriprep.git")
```

**No new dependencies** - same processx pattern, different URL.

### 3. S3 Backend Extension

Extend existing `.download_s3()` in `backend-s3.R` with derivative paths:

```r
# Two S3 access patterns for derivatives:

# Pattern A: Embedded derivatives (in main OpenNeuro bucket)
s3_uri <- paste0("s3://openneuro/", dataset_id, "/", version, "/uncompressed/derivatives/fmriprep")

# Pattern B: OpenNeuroDerivatives bucket
s3_uri <- paste0("s3://openneuro-derivatives/fmriprep/", dataset_id, "-fmriprep")
```

**Important caveat:** The `openneuro-derivatives` bucket has had [access issues](https://neurostars.org/t/openneuro-derivatives-bucket/26531) (ListObjectsV2 denied). The embedded path via the main `openneuro` bucket is more reliable.

### 4. GraphQL Extension for Embedded Derivatives

The existing `on_files()` already supports the `tree` parameter:

```r
# Already works - no changes needed
on_files("ds000001", tree = "derivatives")
on_files("ds000001", tree = "derivatives:fmriprep")
```

## Discovery Architecture

### Recommended Discovery Flow

```
on_derivatives(dataset_id, type = "fmriprep")
  |
  v
1. Check OpenNeuroDerivatives GitHub for {dataset_id}-fmriprep repo
   |-- EXISTS --> Return metadata + DataLad URL
   |
   v
2. Check embedded derivatives via on_files(id, tree="derivatives/fmriprep")
   |-- EXISTS --> Return file listing
   |
   v
3. No fMRIPrep derivatives available --> Return empty tibble with message
```

### Data Source Priority

| Source | Access Method | Completeness | Reliability |
|--------|---------------|--------------|-------------|
| OpenNeuroDerivatives GitHub | GitHub API + DataLad | HIGH (curated) | HIGH |
| OpenNeuro S3 embedded | S3 `derivatives/` path | MEDIUM | HIGH |
| OpenNeuro GraphQL | `on_files(tree="derivatives")` | MEDIUM | HIGH |
| openneuro-derivatives S3 | S3 bucket | HIGH | MEDIUM (past issues) |

## Version Compatibility (No Changes)

All existing version requirements remain sufficient:

| Package | Minimum | Current CRAN | Status |
|---------|---------|--------------|--------|
| httr2 | >= 1.2.1 | 1.2.1 | Already required |
| processx | >= 3.8.0 | 3.8.0+ | Already required |
| fs | >= 1.6.6 | 1.6.6+ | Already required |
| R | >= 4.1.0 | 4.4.x | Already required |

## Testing Considerations

No new test dependencies needed. Existing patterns apply:

```r
test_that("on_derivatives returns tibble for known dataset", {
  # Use httptest2 fixtures for GitHub API responses
  # Use existing vcr cassettes for GraphQL
})

test_that("on_derivatives returns empty tibble for no derivatives", {
  # Mock 404 from GitHub API
})
```

## Quality Gate Checklist

- [x] **No new Imports**: All capabilities use existing httr2, processx, fs
- [x] **No new Suggests**: Existing test framework sufficient
- [x] **Versions verified**: httr2 1.2.1 on CRAN, processx 3.8.0+ on CRAN
- [x] **Rationale for rejections**: gh package adds 3 transitive deps for marginal benefit
- [x] **Integration points documented**: GitHub API, DataLad, S3, GraphQL all covered
- [x] **Reliability caveat noted**: openneuro-derivatives S3 bucket has had access issues

## Sources (Derivative Discovery)

### Verified Sources (HIGH confidence)

- [OpenNeuroDerivatives GitHub](https://github.com/OpenNeuroDerivatives) - Naming conventions, access methods
- [OpenNeuro API Documentation](https://docs.openneuro.org/api.html) - GraphQL schema, file queries
- [CRAN httr2](https://cran.r-project.org/package=httr2) - Version 1.2.1 verified
- [httr2 1.2.0 changelog](https://httr2.r-lib.org/news/index.html) - Pagination improvements
- [GitHub API repos endpoint](https://docs.github.com/en/rest/repos/repos) - Organization repo listing
- [CRAN gh package](https://cran.r-project.org/package=gh) - Version 1.5.0, dependencies evaluated
- [Neurostars discussion](https://neurostars.org/t/openneuro-derivatives-bucket/26531) - S3 bucket access issues

### Codebase Verification

- `/Users/bbuchsbaum/code/openneuroR/R/backend-s3.R` - Existing S3 patterns
- `/Users/bbuchsbaum/code/openneuroR/R/backend-datalad.R` - Existing DataLad patterns
- `/Users/bbuchsbaum/code/openneuroR/R/graphql.R` - Existing httr2 patterns
- `/Users/bbuchsbaum/code/openneuroR/R/api-files.R` - Tree parameter support
- `/Users/bbuchsbaum/code/openneuroR/DESCRIPTION` - Current dependencies

---
*Stack research for: fMRIPrep derivative discovery*
*Researched: 2026-01-22*
