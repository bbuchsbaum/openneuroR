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
