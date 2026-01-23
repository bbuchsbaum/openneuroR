# Architecture: fMRIPrep Derivative Discovery

**Milestone:** v1.2 fMRIPrep Derivative Discovery
**Researched:** 2026-01-22
**Confidence:** HIGH

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Layer D: User-facing API                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  ┌──────────────┐│
│  │ on_dataset() │  │ on_files()   │  │ on_derivatives() │  │ on_bids()    ││
│  │ on_search()  │  │ on_subjects()│  │       NEW        │  │              ││
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  └──────┬───────┘│
│         │                 │                   │                   │        │
├─────────┴─────────────────┴───────────────────┴───────────────────┴────────┤
│                        Layer C: Cache + Handle                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  on_handle()  ─→  on_fetch()  ─→  on_path()                           │ │
│  │  on_download(..., derivatives=)  <── ENHANCED                         │ │
│  │  on_download_derivatives()       <── NEW                              │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│                        Layer B: Download Backends                           │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                 │
│  │ .download_     │  │ .download_     │  │ .download_     │                 │
│  │   datalad()    │  │   s3()         │  │   https()      │                 │
│  │                │  │   ENHANCED     │  │                │                 │
│  └────────────────┘  └────────────────┘  └────────────────┘                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                        Layer A: GraphQL + Discovery                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────┐  ┌────────────────────────────────────┐ │
│  │ on_client() + on_request()    │  │ .discover_derivatives()  <── NEW   │ │
│  │ (GraphQL to OpenNeuro API)    │  │ (GitHub API or S3 listing)         │ │
│  └────────────────────────────────┘  └────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        External Services                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                 │
│  │ OpenNeuro      │  │ GitHub API     │  │ AWS S3         │                 │
│  │ GraphQL API    │  │ (derivatives)  │  │ (derivatives)  │                 │
│  └────────────────┘  └────────────────┘  └────────────────┘                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Layer | Responsibility | Changes |
|-----------|-------|----------------|---------|
| `on_derivatives()` | D | List available derivatives for dataset | NEW |
| `on_download_derivatives()` | C | Download fMRIPrep derivatives to cache | NEW |
| `.discover_derivatives()` | A | Query GitHub/S3 for derivative availability | NEW |
| `.download_s3()` | B | S3 sync for derivatives bucket | ENHANCED (new bucket) |
| `on_download()` | C | Main download with `derivatives=` param | ENHANCED (optional) |
| Cache path utilities | C | Derivatives subdirectory management | ENHANCED |

## Integration Points

### Integration 1: Derivative Discovery (Layer A)

**What:** Query OpenNeuroDerivatives for available fMRIPrep/MRIQC outputs.

**Challenge:** OpenNeuro GraphQL API does NOT expose derivatives. Derivatives live in:
1. GitHub: `github.com/OpenNeuroDerivatives/{dataset}-fmriprep`
2. S3: `s3://openneuro-derivatives/fmriprep/{dataset}-fmriprep/`

**Recommended approach:** GitHub API first, S3 fallback.

```r
# Internal: Check if derivatives exist via GitHub API
.discover_derivatives <- function(dataset_id, pipeline = "fmriprep") {
  repo_name <- paste0(dataset_id, "-", pipeline)
  url <- paste0("https://api.github.com/repos/OpenNeuroDerivatives/", repo_name)

  resp <- httr2::request(url) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    # Repo exists - derivatives available
    list(
      available = TRUE,
      source = "github",
      repo_url = paste0("https://github.com/OpenNeuroDerivatives/", repo_name),
      s3_uri = paste0("s3://openneuro-derivatives/", pipeline, "/", repo_name, "/")
    )
  } else {
    list(available = FALSE, source = NA, repo_url = NA, s3_uri = NA)
  }
}
```

**Why GitHub over S3:**
- GitHub API is reliable, rate-limited but generous (60/hour unauthenticated)
- S3 bucket has had AccessDenied issues for ListObjects operations
- GitHub provides repo metadata (stars, last update, file count)

### Integration 2: S3 Backend Enhancement (Layer B)

**What:** Support downloading from `openneuro-derivatives` bucket.

**Current state:** `.download_s3()` hardcodes `s3://openneuro.org/{dataset_id}`.

**Required change:** Parameterize bucket and path.

```r
# Enhanced .download_s3 signature
.download_s3 <- function(dataset_id, dest_dir, files = NULL, quiet = FALSE,
                          timeout = 1800,
                          bucket = "openneuro.org",    # NEW: parameterized
                          prefix = NULL) {             # NEW: path prefix

  # Construct S3 URI
  s3_uri <- if (is.null(prefix)) {
    paste0("s3://", bucket, "/", dataset_id)
  } else {
    paste0("s3://", bucket, "/", prefix)
  }

  # ... rest unchanged
}
```

**Derivatives-specific call:**

```r
# For fMRIPrep derivatives
.download_s3(
  dataset_id = "ds000001",
  dest_dir = dest_dir,
  bucket = "openneuro-derivatives",
  prefix = "fmriprep/ds000001-fmriprep"
)
```

### Integration 3: Cache Path Structure (Layer C)

**Current structure:**

```
~/.cache/R/openneuroR/
├── ds000001/
│   ├── manifest.json
│   ├── dataset_description.json
│   ├── participants.tsv
│   └── sub-01/
│       └── anat/
│           └── sub-01_T1w.nii.gz
```

**Enhanced structure with derivatives:**

```
~/.cache/R/openneuroR/
├── ds000001/
│   ├── manifest.json              # Raw data manifest
│   ├── dataset_description.json
│   ├── participants.tsv
│   ├── sub-01/
│   │   └── anat/
│   │       └── sub-01_T1w.nii.gz
│   └── derivatives/               # NEW: derivatives subdirectory
│       └── fmriprep/
│           ├── manifest.json      # Derivatives manifest (separate)
│           ├── dataset_description.json
│           └── sub-01/
│               ├── anat/
│               └── func/
```

**Why nested under dataset:**
- Matches BIDS structure (`derivatives/fmriprep/` under dataset root)
- bidser's `bids_project(path, fmriprep=TRUE, prep_dir="derivatives/fmriprep")` works directly
- Single `on_path(handle)` works for both raw and derivatives access

**Alternative considered (rejected):**
```
# Separate top-level derivatives cache - REJECTED
~/.cache/R/openneuroR/
├── ds000001/           # Raw
├── ds000001-fmriprep/  # Derivatives
```
Rejected because: Breaks bidser integration, requires separate paths, confusing UX.

### Integration 4: User-facing API (Layer D)

**New function: `on_derivatives()`**

```r
#' List Available Derivatives for a Dataset
#'
#' Checks OpenNeuroDerivatives for available preprocessed outputs.
#'
#' @param id Dataset identifier (e.g., "ds000001")
#' @param pipeline Character: Pipeline name ("fmriprep", "mriqc"). Default "fmriprep".
#'
#' @return A tibble with columns:
#'   - pipeline: Name of the processing pipeline
#'   - available: TRUE if derivatives exist
#'   - repo_url: GitHub repository URL (if available)
#'   - s3_uri: S3 bucket path for downloads
#'
#' @export
on_derivatives <- function(id, pipeline = c("fmriprep", "mriqc")) {
  pipeline <- match.arg(pipeline, several.ok = TRUE)

  results <- lapply(pipeline, function(p) {
    info <- .discover_derivatives(id, p)
    tibble::tibble(
      pipeline = p,
      available = info$available,
      repo_url = info$repo_url %||% NA_character_,
      s3_uri = info$s3_uri %||% NA_character_
    )
  })

  dplyr::bind_rows(results)
}
```

**New function: `on_download_derivatives()`**

```r
#' Download fMRIPrep/MRIQC Derivatives
#'
#' Downloads preprocessed derivatives from OpenNeuroDerivatives.
#'
#' @param id Dataset identifier (e.g., "ds000001")
#' @param pipeline Character: "fmriprep" (default) or "mriqc"
#' @param subjects Character vector of subject IDs to download (optional)
#' @param dest_dir Destination directory. If NULL, uses cache with BIDS structure.
#' @inheritParams on_download
#'
#' @return Invisibly returns download summary (same structure as on_download)
#'
#' @export
on_download_derivatives <- function(id, pipeline = "fmriprep", subjects = NULL,
                                     dest_dir = NULL, use_cache = TRUE,
                                     quiet = FALSE, force = FALSE, backend = NULL) {
  # Check availability first
  deriv_info <- .discover_derivatives(id, pipeline)
  if (!deriv_info$available) {
    rlang::abort(
      c(paste0("No ", pipeline, " derivatives available for ", id),
        "i" = "Check https://github.com/OpenNeuroDerivatives for available datasets"),
      class = "openneuro_not_found_error"
    )
  }

  # Determine destination (BIDS-compliant structure)
  if (is.null(dest_dir) && use_cache) {
    dest_dir <- fs::path(.on_dataset_cache_path(id), "derivatives", pipeline)
  }

  # Download via S3 backend (derivatives bucket)
  # ... implementation
}
```

### Integration 5: bidser Bridge

**Current `on_bids()` signature:**

```r
on_bids <- function(handle, fmriprep = FALSE, prep_dir = "derivatives/fmriprep")
```

**Enhanced with derivatives download:**

```r
on_bids <- function(handle, fmriprep = FALSE, prep_dir = "derivatives/fmriprep",
                    download_derivatives = FALSE) {  # NEW: auto-download option

  # Fetch raw data if needed
  if (handle$state != "ready") {
    handle <- on_fetch(handle, quiet = TRUE)
  }

  path <- on_path(handle)

  # Optionally download derivatives if requested and not present
  if (download_derivatives && fmriprep) {
    deriv_path <- fs::path(path, prep_dir)
    if (!fs::dir_exists(deriv_path)) {
      on_download_derivatives(
        handle$dataset_id,
        pipeline = "fmriprep",
        dest_dir = deriv_path,
        quiet = TRUE
      )
    }
  }

  rlang::check_installed("bidser")
  bidser::bids_project(path, fmriprep = fmriprep, prep_dir = prep_dir)
}
```

## Data Flow

### Flow 1: Derivative Discovery

```
User                    on_derivatives()         .discover_derivatives()      GitHub API
  |                           |                          |                        |
  |-- on_derivatives(id) ---->|                          |                        |
  |                           |-- .discover(id, "fmriprep") ------------------->  |
  |                           |                          |<-- 200 OK / 404 -------|
  |                           |<-- {available, url, s3} -|                        |
  |<-- tibble(pipeline, ...) -|                          |                        |
```

### Flow 2: Derivative Download

```
User                    on_download_derivatives()   .download_s3()        S3 (derivatives)
  |                              |                       |                      |
  |-- on_download_derivatives -->|                       |                      |
  |                              |-- discover ---------->|                      |
  |                              |<-- s3_uri ------------|                      |
  |                              |                       |                      |
  |                              |-- .download_s3(bucket="openneuro-derivatives")
  |                              |                       |-- sync ----------->  |
  |                              |                       |<-- files ------------|
  |                              |<-- success -----------|                      |
  |<-- {downloaded, dest_dir} ---|                       |                      |
```

### Flow 3: Integrated bidser Access

```
User                    on_bids()               on_download_derivatives()    bidser
  |                        |                              |                     |
  |-- on_bids(h, fmriprep=TRUE, download_derivatives=TRUE)                     |
  |                        |                              |                     |
  |                        |-- check derivatives path --->|                     |
  |                        |   (not exists)               |                     |
  |                        |-- on_download_derivatives -->|                     |
  |                        |                              |-- (download) ----->  |
  |                        |<-- success ------------------|                     |
  |                        |                              |                     |
  |                        |-- bidser::bids_project(path, fmriprep=TRUE) ----->|
  |                        |<-- bids_project object ----------------------------|
  |<-- bids_project -------|                              |                     |
```

## New Functions Summary

| Function | Layer | Purpose | Dependencies |
|----------|-------|---------|--------------|
| `on_derivatives()` | D | List available derivatives | httr2 (GitHub API) |
| `on_download_derivatives()` | C | Download derivatives | .download_s3(), .discover_derivatives() |
| `.discover_derivatives()` | A | Check derivative availability | httr2 |
| `.derivatives_cache_path()` | C | Get cache path for derivatives | fs |

## Modified Functions Summary

| Function | Change | Reason |
|----------|--------|--------|
| `.download_s3()` | Add `bucket` and `prefix` params | Support derivatives bucket |
| `on_bids()` | Add `download_derivatives` param | One-step derivative access |
| `.on_dataset_cache_path()` | No change | Derivatives nest under dataset |

## Build Order

Based on dependencies, build in this order:

1. **Phase 1: Discovery Layer**
   - `.discover_derivatives()` internal function
   - `on_derivatives()` user function
   - Tests with mocked GitHub API responses

2. **Phase 2: S3 Backend Enhancement**
   - Parameterize `.download_s3()` for bucket/prefix
   - Add derivatives bucket support
   - Tests with mocked S3 responses

3. **Phase 3: Download Integration**
   - `on_download_derivatives()` function
   - Cache path utilities for derivatives
   - Subject filtering for derivatives
   - Integration tests

4. **Phase 4: bidser Bridge Enhancement**
   - Add `download_derivatives` param to `on_bids()`
   - Test with mocked bidser

**Rationale for order:**
- Discovery must exist before download can check availability
- S3 enhancement needed before download can fetch derivatives
- Download needed before bidser bridge can auto-download

## Anti-Patterns to Avoid

### Anti-Pattern 1: Separate Derivative Handles

**What people might do:** Create `on_handle_derivatives()` returning a separate handle type.

**Why it's wrong:** Fragments the API, breaks the simple handle->fetch->path flow, confuses users.

**Do this instead:** Use `on_download_derivatives()` as standalone, or `on_bids(..., download_derivatives=TRUE)` for integrated access. Keep handles for raw datasets only.

### Anti-Pattern 2: Inline Bucket Names

**What people might do:** Hardcode `"openneuro-derivatives"` in new functions.

**Why it's wrong:** Bucket names/paths may change, makes testing harder.

**Do this instead:** Define as package constants or options:

```r
.OPENNEURO_DERIVATIVES_BUCKET <- "openneuro-derivatives"
.OPENNEURO_RAW_BUCKET <- "openneuro.org"
```

### Anti-Pattern 3: GraphQL Dependency for Derivatives

**What people might do:** Try to query derivatives via OpenNeuro GraphQL API.

**Why it's wrong:** OpenNeuro GraphQL API does NOT expose derivatives. They are managed separately by OpenNeuroDerivatives project.

**Do this instead:** Use GitHub API for discovery, S3 for downloads. Document this clearly in code comments.

### Anti-Pattern 4: Parallel Raw+Derivatives Cache

**What people might do:** Cache derivatives separately from raw data.

**Why it's wrong:** Breaks bidser integration which expects BIDS structure with `derivatives/` under dataset root.

**Do this instead:** Always cache derivatives under `{dataset}/derivatives/{pipeline}/` to maintain BIDS compatibility.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1-10 datasets | Current design works well |
| 10-100 datasets | Consider parallel discovery queries |
| 100+ datasets | Batch discovery via GitHub Search API |

### First Bottleneck: GitHub API Rate Limits

**What breaks:** GitHub API has 60 requests/hour for unauthenticated access.

**Mitigation:**
1. Cache discovery results locally (derivatives don't change often)
2. Support optional GitHub token via `GITHUB_PAT` env var
3. Batch queries when checking multiple pipelines

```r
# Discovery cache (session-level)
.derivatives_cache <- new.env(parent = emptyenv())

.discover_derivatives <- function(dataset_id, pipeline) {
  cache_key <- paste0(dataset_id, "_", pipeline)

  if (exists(cache_key, envir = .derivatives_cache)) {
    return(get(cache_key, envir = .derivatives_cache))
  }

  # ... fetch from GitHub API ...

  assign(cache_key, result, envir = .derivatives_cache)
  result
}
```

## Sources

**Official documentation:**
- [OpenNeuro API Examples](https://docs.openneuro.org/api.html) - GraphQL API does not include derivatives
- [fMRIPrep Outputs](https://fmriprep.org/en/stable/outputs.html) - BIDS Derivatives structure
- [BIDS Derivatives Spec](https://bids.neuroimaging.io/getting_started/folders_and_files/derivatives.html) - Folder conventions

**OpenNeuroDerivatives project:**
- [GitHub Organization](https://github.com/OpenNeuroDerivatives) - 784+ derivative datasets
- [Superdataset](https://github.com/OpenNeuroDerivatives/OpenNeuroDerivatives) - Index of all derivatives

**S3 access:**
- [NeurStars Discussion](https://neurostars.org/t/openneuro-derivatives-bucket/26531) - S3 bucket access issues documented
- Confirmed: `s3://openneuro-derivatives/{pipeline}/{dataset}-{pipeline}/` path structure

**bidser integration:**
- [bidser docs](https://bbuchsbaum.github.io/bidser/reference/bids_project.html) - `prep_dir` parameter

---
*Architecture research for: v1.2 fMRIPrep Derivative Discovery*
*Researched: 2026-01-22*
*Confidence: HIGH*
