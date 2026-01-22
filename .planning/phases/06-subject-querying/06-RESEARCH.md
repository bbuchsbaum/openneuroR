# Phase 6: Subject Querying - Research

**Researched:** 2026-01-22
**Domain:** GraphQL API querying, R tibble design, natural sorting
**Confidence:** HIGH

## Summary

This phase implements `on_subjects()` to query subject IDs from an OpenNeuro dataset without downloading data. The research confirms this is a straightforward extension of existing GraphQL infrastructure. The OpenNeuro API already provides subject lists via the `snapshot.summary.subjects` field, which returns an array of subject IDs (e.g., `["sub-01", "sub-02", "sub-10"]`). The existing codebase already queries this field in `list_datasets.gql` and `search_datasets.gql`, so the pattern is proven.

The implementation requires a new GraphQL query file (`get_subjects.gql`), a new API function (`on_subjects()`), and a parsing function (`.parse_subjects()`). The function should follow existing patterns from `on_files()` and `on_snapshots()`: validate input, resolve latest snapshot if no tag provided, execute GraphQL query, parse response to tibble.

Natural sorting of subject IDs (sub-01, sub-02, ... sub-10, sub-11) is achievable without adding new dependencies by using `stringi::stri_sort(numeric = TRUE)` since stringi is already an indirect dependency via stringr. Alternatively, a simple regex-based extraction of numeric portions can be implemented in base R.

**Primary recommendation:** Create `get_subjects.gql` querying `snapshot.summary.subjects`, implement `on_subjects()` following `on_files()` pattern, return tibble with columns: dataset_id, subject_id, n_sessions, n_files. Use stringi for natural sorting.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | >= 1.2.1 | HTTP requests | Already in package Imports |
| tibble | >= 3.2.0 | Return data structure | Already in package Imports |
| rlang | >= 1.1.0 | Error handling | Already in package Imports |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| stringi | any | Natural sorting via `stri_sort(numeric=TRUE)` | Indirect dependency via stringr |
| gtools | any | Alternative: `mixedsort()` | Only if stringi unavailable |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| stringi::stri_sort | gtools::mixedsort | gtools is extra dependency; stringi already available |
| stringi::stri_sort | Base R numeric_version() | numeric_version only works for version strings, not "sub-XX" format |
| stringi::stri_sort | Custom regex sort | More code, more maintenance |

**Installation:**
```bash
# No new dependencies required
# stringi is already an indirect dependency via tidyverse/stringr
```

## Architecture Patterns

### Recommended File Structure
```
R/
├── api-subjects.R           # on_subjects() function
├── utils-response.R         # Add .parse_subjects() helper

inst/graphql/
├── get_subjects.gql         # New GraphQL query
```

### Pattern 1: GraphQL Query for Subjects
**What:** Query the summary.subjects field from a snapshot
**When to use:** Always - this is the only way to get subjects without downloading
**Example:**
```graphql
# inst/graphql/get_subjects.gql
query getSubjects($datasetId: ID!, $tag: String!) {
  snapshot(datasetId: $datasetId, tag: $tag) {
    tag
    summary {
      subjects
      sessions
      totalFiles
    }
  }
}
```

**Note on fields:** The `summary.subjects` field returns an array of subject IDs like `["sub-01", "sub-02"]`. The `summary.sessions` field returns an array of session IDs. The `summary.totalFiles` provides file count context.

### Pattern 2: Function Signature Following on_files()
**What:** Match existing API function patterns for consistency
**When to use:** All new API functions
**Example:**
```r
# Source: existing on_files() pattern in R/api-files.R
on_subjects <- function(id, tag = NULL, client = NULL) {
  # 1. Validate input
  if (missing(id) || is.null(id) || !is.character(id) || nchar(id) == 0) {
    rlang::abort(
      c("Invalid dataset ID",
        "x" = "Dataset ID must be a non-empty character string"),
      class = "openneuro_validation_error"
    )
  }

  # 2. Get default client
  client <- client %||% on_client()

  # 3. Resolve latest snapshot if no tag
  if (is.null(tag)) {
    snapshots <- on_snapshots(id, client)
    if (nrow(snapshots) == 0) {
      rlang::abort(
        c("No snapshots available",
          "x" = paste0("Dataset ", id, " has no snapshots")),
        class = "openneuro_not_found_error"
      )
    }
    tag <- snapshots$tag[1]
  }

  # 4. Execute GraphQL query
  gql <- .on_read_gql("get_subjects")
  variables <- list(datasetId = id, tag = tag)

  response <- tryCatch(
    on_request(gql, variables, client),
    # ... error handling following on_files() pattern
  )

  # 5. Parse and return
  .parse_subjects(response, dataset_id = id)
}
```

### Pattern 3: Natural Sorting with stringi
**What:** Sort subject IDs numerically within alphanumeric strings
**When to use:** Always - subjects should appear as sub-01, sub-02, ... sub-10, not sub-01, sub-10, sub-02
**Example:**
```r
# Using stringi (indirect dependency)
sort_subjects_natural <- function(subjects) {
  if (requireNamespace("stringi", quietly = TRUE)) {
    stringi::stri_sort(subjects, numeric = TRUE)
  } else {
    # Fallback: extract numeric portion and sort
    nums <- as.integer(gsub("^sub-0*", "", subjects))
    subjects[order(nums)]
  }
}

# Example:
# sort_subjects_natural(c("sub-01", "sub-10", "sub-02"))
# Returns: c("sub-01", "sub-02", "sub-10")
```

### Pattern 4: Output Tibble Structure
**What:** Return tibble matching CONTEXT.md specification
**When to use:** For on_subjects() return value
**Example:**
```r
# Per CONTEXT.md: dataset_id, subject_id, n_sessions, n_files
.parse_subjects <- function(response, dataset_id) {
  summary <- response$snapshot$summary
  subjects <- summary$subjects %||% character(0)
  sessions <- summary$sessions %||% character(0)
  total_files <- summary$totalFiles %||% NA_integer_

  if (length(subjects) == 0) {
    return(tibble::tibble(
      dataset_id = character(),
      subject_id = character(),
      n_sessions = integer(),
      n_files = integer()
    ))
  }

  # Sort naturally
  subjects <- sort_subjects_natural(subjects)

  # Note: Session and file counts per subject not available from summary
  # Using dataset-level totals as context
  n_sessions_total <- length(sessions)
  avg_files_per_subject <- if (length(subjects) > 0 && !is.na(total_files)) {
    as.integer(total_files / length(subjects))
  } else {
    NA_integer_
  }

  tibble::tibble(
    dataset_id = dataset_id,
    subject_id = subjects,
    n_sessions = n_sessions_total,  # Dataset-level, same for all rows
    n_files = avg_files_per_subject # Estimated average
  )
}
```

**Important caveat:** The OpenNeuro GraphQL summary does NOT provide per-subject session or file counts. The `summary.sessions` is a dataset-wide list, not per-subject. The planner should note this limitation and decide whether to:
1. Use dataset-level counts (n_sessions = total sessions, same for all subjects)
2. Omit these columns if per-subject data isn't available
3. Indicate "NA" for unavailable per-subject breakdowns

### Anti-Patterns to Avoid
- **Downloading files to get subjects:** Use the GraphQL summary endpoint; never download data for metadata queries
- **Hardcoding API response structure:** Use `.null_to_na()` and safe extraction patterns for optional fields
- **Alphabetical sorting of subjects:** Always use natural sort; "sub-10" must come after "sub-9"
- **Adding gtools dependency:** Use stringi (already available) instead

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Natural sorting | Custom regex parser | `stringi::stri_sort(numeric=TRUE)` | Handles edge cases, tested, fast |
| Null handling | `if(is.null(x)) NA else x` | `.null_to_na()` utility | Consistent typing, already exists |
| Snapshot resolution | Manual API call | `on_snapshots()` then take first | Reuses tested code |
| Input validation | Custom checks | Existing validation pattern | Consistent error classes |

**Key insight:** The existing codebase already has all the patterns needed. Follow `on_files()` as the template.

## Common Pitfalls

### Pitfall 1: Assuming Per-Subject Metadata
**What goes wrong:** Expecting per-subject session/file counts from the API
**Why it happens:** Natural assumption that summary provides granular data
**How to avoid:**
1. Check actual API response structure (subjects is just a list of IDs)
2. Document limitations clearly in function help
3. Consider if columns should be omitted vs showing dataset-level estimates
**Warning signs:** Returned data shows same n_sessions for all subjects

### Pitfall 2: Non-BIDS Datasets
**What goes wrong:** Dataset has no sub-* directories, returns empty subject list
**Why it happens:** OpenNeuro accepts some non-BIDS data; summary.subjects only populated for BIDS
**How to avoid:**
1. Handle empty subjects array gracefully (return empty tibble with correct structure)
2. Document that function only works for BIDS-compliant datasets
3. Consider a clear message when subjects is empty: "No BIDS subjects found"
**Warning signs:** Function returns 0-row tibble silently

### Pitfall 3: Inconsistent Snapshot Handling
**What goes wrong:** Using different default snapshot logic than other functions
**Why it happens:** Not checking how on_files() handles missing tag parameter
**How to avoid:**
1. Copy exact pattern from on_files() for snapshot resolution
2. Same parameter name (`tag`, not `version` or `snapshot`)
3. Same error message format
**Warning signs:** Different behavior when tag omitted vs on_files()

### Pitfall 4: Lexicographic Subject Sorting
**What goes wrong:** Subjects appear as sub-01, sub-10, sub-11, sub-02
**Why it happens:** Default R sort() is lexicographic
**How to avoid:**
1. Always apply natural sort before returning
2. Test with datasets that have > 9 subjects
3. Use stringi::stri_sort(numeric = TRUE)
**Warning signs:** Test case with sub-01 through sub-15 shows wrong order

### Pitfall 5: Network Calls in Tests
**What goes wrong:** Tests hit real API, fail on CRAN
**Why it happens:** Forgetting to use httptest2 mocking
**How to avoid:**
1. Follow test-api-files.R pattern exactly
2. Use `skip_if_no_mocks()` helper
3. Create mock response in tests/testthat/openneuro.org/
**Warning signs:** Tests pass locally, fail in CI

## Code Examples

Verified patterns from existing codebase:

### GraphQL Query (from existing patterns)
```graphql
# inst/graphql/get_subjects.gql
# Based on existing get_files.gql and list_datasets.gql patterns
query getSubjects($datasetId: ID!, $tag: String!) {
  snapshot(datasetId: $datasetId, tag: $tag) {
    tag
    summary {
      subjects
      sessions
      totalFiles
    }
  }
}
```

### Error Handling Pattern (from on_files())
```r
# Source: R/api-files.R lines 90-103
response <- tryCatch(
  on_request(gql, variables, client),
  openneuro_api_error = function(e) {
    msg <- conditionMessage(e)
    if (grepl("does not exist|not found", msg, ignore.case = TRUE)) {
      rlang::abort(
        c("Snapshot not found",
          "x" = paste0("No snapshot '", tag, "' for dataset ", id)),
        class = "openneuro_not_found_error"
      )
    }
    rlang::cnd_signal(e)
  }
)
```

### Test Pattern (from test-api-files.R)
```r
# Source: tests/testthat/test-api-files.R
test_that("on_subjects returns tibble with subject information", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_subjects("ds000001")
    expect_s3_class(result, "tbl_df")
    expect_true(nrow(result) >= 1)
    expect_true("subject_id" %in% names(result))
    expect_true("dataset_id" %in% names(result))
  })
})

test_that("on_subjects returns naturally sorted subjects", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_subjects("ds000117")  # Has > 9 subjects
    # Check sub-10 comes after sub-9, not after sub-1
    ids <- result$subject_id
    nums <- as.integer(gsub("sub-0*", "", ids))
    expect_equal(nums, sort(nums))
  })
})
```

### Empty Result Pattern (from .parse_files())
```r
# Source: R/utils-response.R lines 263-270
# Empty tibble with correct column structure
if (length(subjects) == 0) {
  return(tibble::tibble(
    dataset_id = character(),
    subject_id = character(),
    n_sessions = integer(),
    n_files = integer()
  ))
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Download participants.tsv | Query GraphQL summary | OpenNeuro v4+ | No data download needed |
| Custom BIDS parsing | Use summary.subjects | Always available | API handles BIDS extraction |
| gtools::mixedsort | stringi::stri_sort(numeric=TRUE) | stringi widespread | No extra dependency |

**Deprecated/outdated:**
- Parsing file listings to infer subjects: API now provides subject list directly
- Using datalad to list subjects: GraphQL is faster for metadata

## Open Questions

Things that couldn't be fully resolved:

1. **Per-subject session/file counts**
   - What we know: summary.subjects returns just IDs, not per-subject stats
   - What's unclear: Whether any GraphQL field provides per-subject breakdowns
   - Recommendation: Use dataset-level totals or omit these columns; document limitation

2. **Non-BIDS dataset handling**
   - What we know: summary.subjects will be empty for non-BIDS datasets
   - What's unclear: Whether to warn, error, or return empty silently
   - Recommendation: Return empty tibble with informative message attribute or cli::cli_inform()

3. **Session list format**
   - What we know: summary.sessions exists as array
   - What's unclear: Whether sessions are like ["ses-01", "ses-02"] or have different format
   - Recommendation: Query a known multi-session dataset during implementation to verify

## Sources

### Primary (HIGH confidence)
- `/Users/bbuchsbaum/code/openneuroR/inst/graphql/list_datasets.gql` - Existing query showing `summary { subjects }` field
- `/Users/bbuchsbaum/code/openneuroR/R/api-files.R` - Template for function structure
- `/Users/bbuchsbaum/code/openneuroR/R/utils-response.R` - Parsing patterns and utilities
- `/Users/bbuchsbaum/code/openneuroR/tests/testthat/test-api-files.R` - Test patterns

### Secondary (MEDIUM confidence)
- [OpenNeuro API Documentation](https://docs.openneuro.org/api.html) - GraphQL schema info
- [stringi documentation](https://stringi.gagolewski.com/) - `stri_sort(numeric=TRUE)` usage
- [gtools mixedsort](https://rdrr.io/cran/gtools/man/mixedsort.html) - Natural sort reference

### Tertiary (LOW confidence)
- WebSearch results for OpenNeuro GraphQL schema - Verified against existing codebase queries

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new dependencies, using existing patterns
- Architecture: HIGH - Direct extension of proven on_files() pattern
- Pitfalls: HIGH - Based on codebase analysis and API documentation
- GraphQL query: HIGH - Field verified in existing list_datasets.gql

**Research date:** 2026-01-22
**Valid until:** 60 days (stable API, mature codebase patterns)
