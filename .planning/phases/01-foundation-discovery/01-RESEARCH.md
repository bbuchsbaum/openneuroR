# Phase 1: Foundation + Discovery - Research

**Researched:** 2026-01-20
**Domain:** R package for GraphQL-based dataset discovery (OpenNeuro API)
**Confidence:** HIGH

## Summary

Phase 1 establishes the package skeleton and implements GraphQL-based dataset discovery functions (`on_search()`, `on_dataset()`, `on_snapshots()`, `on_files()`). Research confirms the standard approach uses httr2 for HTTP requests (not ghql directly) combined with external `.gql` query files. The OpenNeuro GraphQL API is well-documented with clear query patterns for datasets, snapshots, and file trees.

Key findings:
- OpenNeuro exposes `dataset(id)`, `datasets()` (with pagination), `snapshot(datasetId, tag)` queries
- File trees are hierarchical and require recursive traversal via `key` field
- The `datasets()` query supports filtering and sorting, though specific parameters require schema introspection
- httr2 provides all needed functionality (retry, throttle, error handling) without ghql overhead

**Primary recommendation:** Use httr2 directly for GraphQL requests with external `.gql` query documents. Store queries in `inst/graphql/` for maintainability. Implement pagination with sensible defaults (limit=50) and optional `all=TRUE` for complete results.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | >= 1.2.1 | HTTP requests, retry, throttle | r-lib recommended, httr successor |
| jsonlite | >= 1.8.9 | JSON parsing | Universal, pulled in by httr2 anyway |
| tibble | >= 3.2.0 | Return format | Tidyverse standard, expected by users |
| rlang | >= 1.1.0 | Errors, conditions | Modern error handling with context |
| cli | >= 3.6.0 | User messages, progress | r-lib standard for CLI output |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| fs | >= 1.6.6 | File paths | Query file loading from inst/ |
| withr | >= 3.0.0 | Temporary state | Test fixtures, options management |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| httr2 direct | ghql | ghql adds R6 complexity; httr2 sufficient for simple POST |
| External .gql files | Inline queries | Inline harder to maintain, doesn't match schema changes |
| jsonlite | yyjsonr | yyjsonr faster but exotic dependency, no real benefit for metadata |

**Installation:**
```bash
# These are Imports (required)
install.packages(c("httr2", "jsonlite", "tibble", "rlang", "cli", "fs", "withr"))

# These are Suggests (for testing)
install.packages(c("testthat", "vcr", "webmockr"))
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── client.R           # on_client() - connection configuration
├── graphql.R          # on_query() - raw query execution, .gql loading
├── api-search.R       # on_search() - dataset search
├── api-dataset.R      # on_dataset() - single dataset metadata
├── api-snapshots.R    # on_snapshots() - list snapshots
├── api-files.R        # on_files() - list files in snapshot
├── utils-response.R   # Response parsing helpers
└── zzz.R              # .onLoad, package state

inst/
└── graphql/
    ├── search_datasets.gql
    ├── get_dataset.gql
    ├── get_snapshots.gql
    └── get_files.gql

tests/
└── testthat/
    ├── helper-vcr.R   # VCR configuration
    ├── fixtures/      # Recorded HTTP cassettes
    ├── test-search.R
    ├── test-dataset.R
    ├── test-snapshots.R
    └── test-files.R
```

### Pattern 1: Base Request Function
**What:** Single function handling all GraphQL requests with auth, retry, throttle
**When to use:** Every API call goes through this
**Example:**
```r
# Source: httr2 wrapping APIs vignette
on_request <- function(query, variables = NULL, client = NULL) {
  client <- client %||% on_client()

  body <- list(query = query)
  if (!is.null(variables)) {
    body$variables <- variables
  }

  req <- httr2::request(client$url) |>
    httr2::req_headers(
      "Content-Type" = "application/json",
      "User-Agent" = paste0("openneuro-r/", utils::packageVersion("openneuro"))
    ) |>
    httr2::req_body_json(body) |>
    httr2::req_retry(
      max_tries = 3,
      is_transient = \(resp) httr2::resp_status(resp) %in% c(429, 500, 502, 503)
    ) |>
    httr2::req_throttle(rate = 10 / 60)  # 10 requests per minute

  # Add auth if available
  if (!is.null(client$token)) {
    req <- httr2::req_auth_bearer_token(req, client$token)
  }

  resp <- httr2::req_perform(req)
  data <- httr2::resp_body_json(resp)

  # Check for GraphQL errors in response body
  if (!is.null(data$errors)) {
    rlang::abort(
      c("OpenNeuro API error",
        "i" = data$errors[[1]]$message),
      class = "openneuro_api_error"
    )
  }

  data$data
}
```

### Pattern 2: External Query Files
**What:** Store GraphQL queries in `inst/graphql/*.gql` files
**When to use:** All queries should be external for maintainability
**Example:**
```r
# R/graphql.R
.on_read_gql <- function(name) {
  path <- system.file("graphql", paste0(name, ".gql"), package = "openneuro")
  if (path == "") {
    rlang::abort(
      c("Query file not found",
        "x" = paste0("No file found for query: ", name)),
      class = "openneuro_query_error"
    )
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

# inst/graphql/search_datasets.gql
# query searchDatasets($query: String, $first: Int, $after: String) {
#   datasets(first: $first, after: $after, filterBy: { all: $query }) {
#     edges {
#       node {
#         id
#         name
#         created
#         public
#         latestSnapshot {
#           tag
#           summary { modalities subjects tasks }
#         }
#       }
#     }
#     pageInfo {
#       hasNextPage
#       endCursor
#     }
#   }
# }
```

### Pattern 3: Response to Tibble Transformation
**What:** Convert nested GraphQL responses to tidy tibbles
**When to use:** All user-facing functions return tibbles
**Example:**
```r
# R/utils-response.R
.parse_datasets <- function(response) {
  edges <- response$datasets$edges
  if (length(edges) == 0) {
    return(tibble::tibble(
      id = character(),
      name = character(),
      created = as.POSIXct(character()),
      public = logical()
    ))
  }

  tibble::tibble(
    id = vapply(edges, \(x) x$node$id, character(1)),
    name = vapply(edges, \(x) x$node$name %||% NA_character_, character(1)),
    created = as.POSIXct(
      vapply(edges, \(x) x$node$created %||% NA_character_, character(1)),
      format = "%Y-%m-%dT%H:%M:%S"
    ),
    public = vapply(edges, \(x) x$node$public %||% NA, logical(1)),
    # List column for nested data
    summary = lapply(edges, \(x) x$node$latestSnapshot$summary)
  )
}
```

### Pattern 4: Client Object (Simple List)
**What:** Connection configuration as simple S3 class (not R6)
**When to use:** Package initialization, explicit client passing
**Example:**
```r
# R/client.R
on_client <- function(url = "https://openneuro.org/crn/graphql",
                      token = NULL) {
  token <- token %||% Sys.getenv("OPENNEURO_API_KEY", unset = NA)
  if (is.na(token)) token <- NULL

  structure(
    list(url = url, token = token),
    class = "openneuro_client"
  )
}

print.openneuro_client <- function(x, ...) {
  cli::cli_text("<openneuro_client>")
  cli::cli_text("URL: {.url {x$url}}")
  cli::cli_text("Authenticated: {.val {!is.null(x$token)}}")
  invisible(x)
}
```

### Anti-Patterns to Avoid
- **Inline GraphQL strings:** Hard to maintain, easy to make syntax errors
- **R6 for simple client:** Overkill when a list-with-class suffices
- **Ignoring GraphQL errors:** HTTP 200 can contain errors in body
- **Blocking pagination:** Always paginate, even if returning first page only
- **camelCase in returns:** User expects snake_case from R packages

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP retry/backoff | Custom retry loop | httr2::req_retry() | Handles transient errors, Retry-After headers |
| Rate limiting | Sleep statements | httr2::req_throttle() | Token bucket algorithm, automatic |
| JSON parsing | Manual list traversal | jsonlite::fromJSON() | Handles edge cases, NA values |
| Error conditions | stop() with strings | rlang::abort() with class | Enables catch by class, better messages |
| Progress bars | cat() statements | cli::cli_progress_*() | Consistent UX, handles non-interactive |
| Date parsing | Manual regex | as.POSIXct() with format | Handles timezones, NA values |

**Key insight:** httr2 was designed specifically for wrapping APIs. Every common need (retry, throttle, auth, user agent, error handling) is built-in and tested. Don't reinvent.

## Common Pitfalls

### Pitfall 1: GraphQL Errors on HTTP 200
**What goes wrong:** API returns HTTP 200 but with errors in response body. Package reports success when operation failed.
**Why it happens:** GraphQL spec allows errors alongside data, unlike REST's status-code-based errors.
**How to avoid:** Always check `response$errors` after parsing JSON, even on HTTP 200.
**Warning signs:** Tests pass but users report "data not found" on valid IDs.

### Pitfall 2: Missing User Agent
**What goes wrong:** API maintainers cannot identify misbehaving clients. Package may get blocked with no warning.
**Why it happens:** Seems like minor detail, skipped during development.
**How to avoid:** Set user agent in base request: `req_user_agent("openneuro-r/VERSION (URL)")`
**Warning signs:** Mysterious 403 errors, no response from API maintainers.

### Pitfall 3: Ignoring Pagination
**What goes wrong:** Search returns only first 25 results. Users think that's all data.
**Why it happens:** Pagination works on small test queries, issue only visible with real data.
**How to avoid:** Always return pagination info, document limits, provide `all=TRUE` option.
**Warning signs:** Users report "missing datasets" that exist on web interface.

### Pitfall 4: Wrong Cache Directory (CRAN rejection)
**What goes wrong:** Package writes to `~/` or uses `rappdirs`. CRAN rejects.
**Why it happens:** rappdirs is popular but CRAN policy changed to require `tools::R_user_dir()`.
**How to avoid:** Use `tools::R_user_dir("openneuro", "cache")` exclusively.
**Warning signs:** CRAN rejection email mentioning file system policy.

### Pitfall 5: Tests Hit Real API
**What goes wrong:** Tests fail on CRAN because API is slow/unavailable. Package fails R CMD check.
**Why it happens:** Developer tests with real API, forgets mocking.
**How to avoid:** Set up vcr from first test. Use `skip_on_cran()` for integration tests.
**Warning signs:** Tests pass locally, fail on GitHub Actions or CRAN.

### Pitfall 6: Network Failures Not Graceful
**What goes wrong:** Cryptic error stack trace when offline instead of helpful message.
**Why it happens:** Error handling focuses on API errors, not network errors.
**How to avoid:** Wrap network calls in tryCatch, return informative errors.
**Warning signs:** CRAN rejection: "Packages which use Internet resources should fail gracefully."

## Code Examples

Verified patterns from official sources:

### on_search() Implementation
```r
# Source: httr2 wrapping APIs pattern + OpenNeuro API docs
on_search <- function(query = NULL,
                      modality = NULL,
                      species = NULL,
                      limit = 50,
                      all = FALSE,
                      client = NULL) {
  client <- client %||% on_client()
  gql <- .on_read_gql("search_datasets")

  variables <- list(first = as.integer(limit))
  if (!is.null(query)) variables$query <- query
  if (!is.null(modality)) variables$modality <- modality
  if (!is.null(species)) variables$species <- species

  if (!all) {
    # Single page
    response <- on_request(gql, variables, client)
    return(.parse_datasets(response))
  }

  # Paginate through all results
  results <- list()
  cursor <- NULL


  repeat {
    variables$after <- cursor
    response <- on_request(gql, variables, client)
    results <- c(results, list(.parse_datasets(response)))

    page_info <- response$datasets$pageInfo
    if (!isTRUE(page_info$hasNextPage)) break
    cursor <- page_info$endCursor
  }

  do.call(rbind, results)
}
```

### on_dataset() Implementation
```r
# Source: OpenNeuro API docs
on_dataset <- function(id, client = NULL) {
  client <- client %||% on_client()
  gql <- .on_read_gql("get_dataset")

  response <- on_request(gql, list(id = id), client)

  if (is.null(response$dataset)) {
    rlang::abort(
      c("Dataset not found",
        "x" = paste0("No dataset with id: ", id)),
      class = "openneuro_not_found_error"
    )
  }

  d <- response$dataset
  tibble::tibble(
    id = d$id,
    name = d$name %||% NA_character_,
    created = as.POSIXct(d$created, format = "%Y-%m-%dT%H:%M:%S"),
    modified = as.POSIXct(d$modified %||% d$created, format = "%Y-%m-%dT%H:%M:%S"),
    public = d$public %||% FALSE
  )
}
```

### on_snapshots() Implementation
```r
# Source: OpenNeuro API docs
on_snapshots <- function(id, client = NULL) {
  client <- client %||% on_client()
  gql <- .on_read_gql("get_snapshots")

  response <- on_request(gql, list(id = id), client)

  snapshots <- response$dataset$snapshots
  if (length(snapshots) == 0) {
    return(tibble::tibble(
      tag = character(),
      created = as.POSIXct(character()),
      size = numeric()
    ))
  }

  tibble::tibble(
    tag = vapply(snapshots, \(x) x$tag, character(1)),
    created = as.POSIXct(
      vapply(snapshots, \(x) x$created, character(1)),
      format = "%Y-%m-%dT%H:%M:%S"
    ),
    size = vapply(snapshots, \(x) x$size %||% NA_real_, numeric(1))
  )
}
```

### on_files() Implementation
```r
# Source: OpenNeuro API docs - files have id, key, filename, size, directory, annexed
on_files <- function(id, tag = NULL, tree = NULL, client = NULL) {
  client <- client %||% on_client()
  gql <- .on_read_gql("get_files")

  # If no tag, use latest snapshot
  if (is.null(tag)) {
    snapshots <- on_snapshots(id, client)
    if (nrow(snapshots) == 0) {
      rlang::abort(
        c("No snapshots available",
          "x" = paste0("Dataset ", id, " has no snapshots")),
        class = "openneuro_not_found_error"
      )
    }
    tag <- snapshots$tag[1]  # Most recent
  }

  variables <- list(datasetId = id, tag = tag)
  if (!is.null(tree)) variables$tree <- tree

  response <- on_request(gql, variables, client)
  files <- response$snapshot$files

  if (length(files) == 0) {
    return(tibble::tibble(
      filename = character(),
      size = numeric(),
      directory = logical(),
      annexed = logical(),
      key = character()
    ))
  }

  tibble::tibble(
    filename = vapply(files, \(x) x$filename, character(1)),
    size = vapply(files, \(x) x$size %||% NA_real_, numeric(1)),
    directory = vapply(files, \(x) x$directory %||% FALSE, logical(1)),
    annexed = vapply(files, \(x) x$annexed %||% FALSE, logical(1)),
    key = vapply(files, \(x) x$key %||% NA_character_, character(1))
  )
}
```

### VCR Test Setup
```r
# tests/testthat/helper-vcr.R
# Source: HTTP Testing in R book
library(vcr)

vcr::vcr_configure(
  dir = testthat::test_path("fixtures"),
  filter_sensitive_data = list(
    "<<API_KEY>>" = Sys.getenv("OPENNEURO_API_KEY")
  ),
  record = "once"  # Record once, replay forever
)

# Fake token when cassettes exist but no real token
if (Sys.getenv("OPENNEURO_API_KEY") == "" && dir.exists(testthat::test_path("fixtures"))) {
  Sys.setenv(OPENNEURO_API_KEY = "fake_for_testing")
}
```

### Example Test with VCR
```r
# tests/testthat/test-search.R
test_that("on_search returns tibble of datasets", {
  vcr::local_cassette("search_basic", {
    result <- on_search("fmri", limit = 5)
  })

  expect_s3_class(result, "tbl_df")
  expect_true(nrow(result) > 0)
  expect_named(result, c("id", "name", "created", "public", "summary"))
  expect_type(result$id, "character")
  expect_s3_class(result$created, "POSIXct")
})

test_that("on_search handles empty results", {
  vcr::local_cassette("search_empty", {
    result <- on_search("xyznonexistent12345", limit = 5)
  })

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})
```

## OpenNeuro GraphQL API Details

### Available Types and Fields

**Dataset type** (from schema introspection):
- `id` - Dataset identifier (e.g., "ds000001")
- `name` - Dataset title
- `created` - ISO timestamp
- `public` - Boolean visibility
- `draft` - Current working version
- `snapshots` - List of tagged versions
- `latestSnapshot` - Most recent snapshot

**Snapshot type**:
- `id` - Composite identifier
- `tag` - Version tag (e.g., "1.0.0")
- `created` - ISO timestamp
- `size` - Total bytes
- `files` - File tree (accepts `tree` argument for subdirectories)
- `description` - BIDS dataset_description.json fields
- `summary` - Aggregated info (modalities, subjects, tasks)

**DatasetFile type**:
- `id` - File identifier
- `key` - Git tree key (for subdirectory traversal)
- `filename` - File name
- `size` - Bytes
- `directory` - Boolean (true if directory)
- `annexed` - Boolean (true if in git-annex)

### Query Examples

```graphql
# Search datasets
query searchDatasets($query: String, $first: Int, $after: String) {
  datasets(first: $first, after: $after, filterBy: { all: $query }) {
    edges {
      node {
        id
        name
        created
        public
        latestSnapshot {
          tag
          summary { modalities subjects tasks }
        }
      }
    }
    pageInfo { hasNextPage endCursor }
  }
}

# Get single dataset
query getDataset($id: ID!) {
  dataset(id: $id) {
    id
    name
    created
    public
    latestSnapshot { tag }
  }
}

# Get snapshots
query getSnapshots($id: ID!) {
  dataset(id: $id) {
    snapshots {
      tag
      created
      size
    }
  }
}

# Get files
query getFiles($datasetId: ID!, $tag: String!, $tree: String) {
  snapshot(datasetId: $datasetId, tag: $tag) {
    files(tree: $tree) {
      id
      key
      filename
      size
      directory
      annexed
    }
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| httr | httr2 | 2023 | Modern pipe API, built-in retry/throttle |
| ghql client | httr2 direct | Current | Simpler, fewer dependencies |
| rappdirs | tools::R_user_dir() | 2021 | CRAN policy compliance |
| stop() | rlang::abort() | 2019 | Structured errors with classes |
| data.frame | tibble | 2016+ | Better printing, list-columns |

**Deprecated/outdated:**
- **httr**: Superseded by httr2, no new development
- **rappdirs for cache**: Use tools::R_user_dir() for CRAN compliance
- **R6 for simple state**: List-with-class is simpler, sufficient for client object

## Open Questions

Things that couldn't be fully resolved:

1. **Exact filter parameters for datasets() query**
   - What we know: `filterBy` accepts object, `all` field for text search
   - What's unclear: Exact fields for modality/species filtering
   - Recommendation: Use GraphQL introspection in first implementation to discover schema, document findings

2. **Rate limit specifics**
   - What we know: OpenNeuro uses standard rate limiting (429 responses)
   - What's unclear: Exact limits (requests/minute, burst allowance)
   - Recommendation: Start conservative (10/min), adjust based on production behavior

3. **Recursive file tree efficiency**
   - What we know: Subdirectories require separate queries with `tree` key
   - What's unclear: Best approach for full tree (parallel queries? single deep query?)
   - Recommendation: Implement basic single-level first, optimize in later phase if needed

## Sources

### Primary (HIGH confidence)
- [OpenNeuro API Documentation](https://docs.openneuro.org/api.html) - Query examples, types
- [httr2 Wrapping APIs Vignette](https://httr2.r-lib.org/articles/wrapping-apis.html) - Request patterns, auth, errors
- [ghql Documentation](https://docs.ropensci.org/ghql/) - GraphQL R patterns (decided not to use, but informed design)
- [HTTP Testing in R Book](https://books.ropensci.org/http-testing/) - vcr/webmockr setup
- [OpenNeuro GitHub - schema.ts](https://github.com/OpenNeuroOrg/openneuro/blob/master/packages/openneuro-server/src/graphql/schema.ts) - Type definitions

### Secondary (MEDIUM confidence)
- [GraphQL over HTTP Spec](https://graphql.org/learn/serving-over-http/) - Content-Type headers, POST format
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html) - Cache location requirements

### Tertiary (LOW confidence)
- WebSearch results on OpenNeuro filtering - Needs validation via introspection

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - httr2/tibble well-documented, widely used
- Architecture patterns: HIGH - Follows httr2 vignette patterns exactly
- API schema: MEDIUM - Documented but filter params need introspection
- Pitfalls: HIGH - Well-documented in rOpenSci resources

**Research date:** 2026-01-20
**Valid until:** 60 days (OpenNeuro API is stable, httr2/tibble are mature)
