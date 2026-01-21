# Phase 3: Caching Layer - Research

**Researched:** 2026-01-21
**Domain:** R package caching, CRAN-compliant file storage, manifest tracking
**Confidence:** HIGH

## Summary

This research covers implementing a CRAN-compliant caching layer for downloaded OpenNeuro datasets. The standard approach uses `tools::R_user_dir("openneuroR", "cache")` for storage, with per-dataset JSON manifest files tracking downloads. The existing download infrastructure (Phase 2) already supports atomic downloads, size validation, and progress reporting - the cache layer wraps this with location management and manifest tracking.

The key architectural decisions are already locked in CONTEXT.md:
- Nested cache structure mirroring OpenNeuro paths: `cache/ds000001/sub-01/anat/...`
- Per-dataset JSON manifests at `cache/ds000001/manifest.json`
- Human-browsable paths using `tools::R_user_dir()`

**Primary recommendation:** Use `tools::R_user_dir("openneuroR", "cache")` as the cache root, with `jsonlite` for manifest I/O, and provide `on_cache_list()`, `on_cache_info()`, and `on_cache_clear()` management functions.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| tools (base R) | R >= 4.0 | `R_user_dir()` for CRAN-compliant paths | Official R function, required for CRAN |
| jsonlite | >= 1.8.9 | JSON manifest read/write | Universal, human-readable format |
| fs | >= 1.6.6 | File system operations | Already a dependency, cross-platform |
| cli | >= 3.6.0 | User messaging, progress | Already a dependency |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| rlang | >= 1.1.0 | Error handling, conditions | Already a dependency |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| JSON manifest | SQLite (BiocFileCache) | SQLite more powerful but adds DBI dependency, overkill for simple tracking |
| JSON manifest | RDS files | RDS not human-readable, harder to debug |
| tools::R_user_dir | rappdirs | rappdirs deprecated for CRAN packages, tools::R_user_dir is the standard |

**Installation:**
```bash
# jsonlite needs to be re-added to DESCRIPTION Imports
# (was removed in Phase 2 since httr2 handles API JSON internally)
```

**Note:** `jsonlite` must be added back to DESCRIPTION Imports. It was removed in Phase 2 because httr2 handles API JSON parsing internally, but we need explicit jsonlite for manifest file I/O.

## Architecture Patterns

### Recommended Project Structure
```
R/
├── cache-path.R         # Cache path resolution, directory helpers
├── cache-manifest.R     # Manifest read/write/update operations
├── cache-management.R   # User-facing cache management functions
└── download.R           # Modified to use cache by default
```

### Pattern 1: CRAN-Compliant Cache Location

**What:** Use `tools::R_user_dir("openneuroR", "cache")` as the base cache directory.

**When to use:** Always - this is required for CRAN compliance.

**Example:**
```r
# Source: https://search.r-project.org/R/refmans/tools/html/userdir.html
.on_cache_root <- function() {
  tools::R_user_dir("openneuroR", "cache")
}

# Returns platform-appropriate paths:
# Mac:   ~/Library/Caches/R/openneuroR
# Linux: ~/.cache/R/openneuroR
# Win:   ~\AppData\Local\R\cache\openneuroR
```

### Pattern 2: Per-Dataset Manifest Files

**What:** JSON manifest file at `cache/ds000001/manifest.json` tracking files in that dataset.

**When to use:** For each dataset that has cached files.

**Example:**
```r
# Source: Decision from CONTEXT.md + jsonlite documentation
# https://rdrr.io/cran/jsonlite/man/read_json.html

# Manifest structure
manifest <- list(
  dataset_id = "ds000001",
  snapshot_tag = "1.0.0",
  cached_at = Sys.time(),
  files = list(
    list(
      path = "sub-01/anat/sub-01_T1w.nii.gz",
      size = 15234567,
      downloaded_at = "2026-01-21T10:30:00Z",
      backend = "s3"
    )
  )
)

# Write with atomic pattern
.write_manifest <- function(manifest, dataset_dir) {
  path <- fs::path(dataset_dir, "manifest.json")
  temp_path <- fs::file_temp(ext = "json")
  jsonlite::write_json(manifest, temp_path, auto_unbox = TRUE, pretty = TRUE)
  fs::file_move(temp_path, path)  # Atomic on same filesystem
}
```

### Pattern 3: Cache-First Download Integration

**What:** Modify `on_download()` to use cache directory by default, check manifest before downloading.

**When to use:** When user calls `on_download()` without specifying `dest_dir`.

**Example:**
```r
# Pseudocode for modified on_download()
on_download <- function(id, tag = NULL, files = NULL, dest_dir = NULL, ...) {
  # If no dest_dir specified, use cache
  if (is.null(dest_dir)) {
    dest_dir <- .on_dataset_cache_path(id)
  }

  # Check manifest for already-cached files
  manifest <- .read_manifest(dest_dir)
  cached_files <- .get_cached_file_paths(manifest)

  # Filter out already-cached files (unless force = TRUE)
  files_to_download <- setdiff(requested_files, cached_files)

  # Download new files (existing Phase 2 logic)
  # ...

  # Update manifest with newly downloaded files
  .update_manifest(dest_dir, new_files)
}
```

### Pattern 4: Cache Management Functions

**What:** User-facing functions to list, inspect, and clear cached data.

**When to use:** Users need visibility and control over cache contents.

**Example:**
```r
# Source: pak package cache utilities pattern
# https://pak.r-lib.org/reference/cache.html

#' List Cached Datasets
#' @return tibble with dataset_id, snapshot_tag, n_files, total_size, cached_at
on_cache_list <- function() {
  # Enumerate all dataset directories in cache
  # Read manifest from each
  # Return summary tibble
}

#' Get Cache Information
#' @return list with cache_path, n_datasets, total_size
on_cache_info <- function() {
  cache_root <- .on_cache_root()
  list(
    cache_path = cache_root,
    n_datasets = length(cached_datasets),
    total_size = sum(sizes),
    total_size_formatted = .format_bytes(sum(sizes))
  )
}

#' Clear Cache
#' @param dataset_id Optional - clear specific dataset; NULL clears all
on_cache_clear <- function(dataset_id = NULL) {
  # If dataset_id specified, delete that dataset's directory
  # Otherwise, delete entire cache directory
  # Provide confirmation in interactive sessions
}
```

### Anti-Patterns to Avoid

- **Writing to user's working directory by default:** CRAN policy violation. Always use `tools::R_user_dir()`.
- **Global manifest for all datasets:** Creates contention, harder to manage. Use per-dataset manifests.
- **Tracking partial downloads in manifest:** Only record complete files. Manifest = source of truth for valid cache entries.
- **Modifying cache during R CMD check:** Tests must set `R_USER_CACHE_DIR` to a temp directory.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cross-platform cache paths | Custom path logic | `tools::R_user_dir()` | Handles Mac/Linux/Windows, XDG spec |
| JSON serialization | Manual string formatting | `jsonlite::write_json()` | Handles escaping, encoding, edge cases |
| Atomic file operations | Direct writes | Temp file + `fs::file_move()` | Already pattern in codebase |
| Human-readable sizes | Manual calculation | `.format_bytes()` | Already implemented in download-progress.R |
| Directory traversal | `list.files()` | `fs::dir_ls()` | Consistent with existing code |

**Key insight:** The caching layer mostly composes existing building blocks (fs, jsonlite, tools) with the existing download infrastructure. The novel work is manifest schema design and cache management UX.

## Common Pitfalls

### Pitfall 1: Writing to User's Home Directory Directly

**What goes wrong:** CRAN rejects packages that write to `~/.packagename/` or any non-standard location.

**Why it happens:** Developers test locally where permissions are loose, then CRAN's automated checks fail.

**How to avoid:** Always use `tools::R_user_dir("openneuroR", "cache")`. Never use `rappdirs` (deprecated for this purpose) or construct paths manually.

**Warning signs:** Paths starting with `~/` or `~/.` in production code.

### Pitfall 2: Tests Modifying Real Cache

**What goes wrong:** R CMD check fails or leaves behind files in user's cache directory.

**Why it happens:** Test code calls cache functions without mocking the cache location.

**How to avoid:** In `tests/testthat/setup.R`:
```r
# Set cache to temp directory for all tests
Sys.setenv(R_USER_CACHE_DIR = tempfile())
```

**Warning signs:** Tests passing locally but failing on CRAN, or `R CMD check` leaving behind files.

### Pitfall 3: Manifest Corruption on Interrupted Write

**What goes wrong:** Power failure or crash during manifest write leaves corrupted JSON.

**Why it happens:** Writing directly to manifest.json without atomic pattern.

**How to avoid:** Always use temp file + rename pattern:
```r
temp <- fs::file_temp(ext = "json")
jsonlite::write_json(data, temp, ...)
fs::file_move(temp, final_path)  # Atomic
```

**Warning signs:** Users reporting "invalid JSON" errors, cache becoming unusable.

### Pitfall 4: Snapshot Version Mismatch

**What goes wrong:** User caches dataset at version 1.0.0, later requests 1.1.0, but gets cached 1.0.0 files.

**Why it happens:** Cache lookup doesn't consider snapshot version.

**How to avoid:** Manifest must track snapshot_tag. When requested version differs from cached version, either:
1. Re-download (replacing cached files)
2. Error with clear message

**Decision per CONTEXT.md:** Claude's discretion on behavior. Recommendation: Replace cached files with warning message.

**Warning signs:** Users reporting "stale data" or files not matching API-reported sizes.

### Pitfall 5: Cache Growing Without Bound

**What goes wrong:** Users download many datasets, cache grows to tens of GB, disk fills up.

**Why it happens:** No visibility into cache size, no easy way to clear.

**How to avoid:** Provide `on_cache_info()` for visibility and `on_cache_clear()` for cleanup. Consider adding cache size to package startup message if large.

**Warning signs:** User complaints about disk space.

## Code Examples

Verified patterns from official sources:

### CRAN-Compliant Cache Root
```r
# Source: https://search.r-project.org/R/refmans/tools/html/userdir.html
# R_user_dir signature: R_user_dir(package, which = c("data", "config", "cache"))

.on_cache_root <- function() {
  root <- tools::R_user_dir("openneuroR", "cache")
  # Ensure directory exists
  if (!fs::dir_exists(root)) {
    fs::dir_create(root, recurse = TRUE)
  }
  root
}
```

### Dataset Cache Path
```r
# Follows decision from CONTEXT.md: cache/ds000001/sub-01/anat/...

.on_dataset_cache_path <- function(dataset_id) {
  fs::path(.on_cache_root(), dataset_id)
}

.on_file_cache_path <- function(dataset_id, file_path) {
  fs::path(.on_dataset_cache_path(dataset_id), file_path)
}
```

### Manifest Schema
```json
{
  "schema_version": 1,
  "dataset_id": "ds000001",
  "snapshot_tag": "1.0.0",
  "cached_at": "2026-01-21T10:30:00Z",
  "files": [
    {
      "path": "sub-01/anat/sub-01_T1w.nii.gz",
      "size": 15234567,
      "downloaded_at": "2026-01-21T10:30:00Z",
      "backend": "s3"
    },
    {
      "path": "participants.tsv",
      "size": 1234,
      "downloaded_at": "2026-01-21T10:30:05Z",
      "backend": "s3"
    }
  ]
}
```

### Manifest Read/Write
```r
# Source: https://rdrr.io/cran/jsonlite/man/read_json.html

.manifest_path <- function(dataset_dir) {
  fs::path(dataset_dir, "manifest.json")
}

.read_manifest <- function(dataset_dir) {
  path <- .manifest_path(dataset_dir)
  if (!fs::file_exists(path)) {
    return(NULL)
  }
  jsonlite::read_json(path, simplifyVector = FALSE)
}

.write_manifest <- function(manifest, dataset_dir) {
  path <- .manifest_path(dataset_dir)
  temp_path <- fs::file_temp(ext = "json")

  tryCatch({
    jsonlite::write_json(manifest, temp_path, auto_unbox = TRUE, pretty = TRUE)
    fs::dir_create(fs::path_dir(path), recurse = TRUE)
    fs::file_move(temp_path, path)
  }, error = function(e) {
    if (fs::file_exists(temp_path)) fs::file_delete(temp_path)
    rlang::abort(
      c("Failed to write cache manifest",
        "x" = conditionMessage(e)),
      class = "openneuro_cache_error"
    )
  })

  invisible(path)
}
```

### Cache File Validation
```r
# Check if file is in cache and valid (exists + correct size)

.is_cached <- function(dataset_id, file_path, expected_size) {
  cache_path <- .on_file_cache_path(dataset_id, file_path)
  if (!fs::file_exists(cache_path)) {
    return(FALSE)
  }
  actual_size <- as.numeric(fs::file_size(cache_path))
  actual_size == expected_size
}
```

### Test Setup for CRAN Compliance
```r
# Source: https://cran.r-project.org/web/packages/pkgcache/readme/README.html
# tests/testthat/setup.R

# Use temp directory for cache during tests
# This prevents modifying user's real cache during R CMD check
if (Sys.getenv("R_USER_CACHE_DIR") == "") {
  test_cache_dir <- tempfile("openneuroR_test_cache")
  Sys.setenv(R_USER_CACHE_DIR = test_cache_dir)
}

# Cleanup after all tests
withr::defer(
  unlink(Sys.getenv("R_USER_CACHE_DIR"), recursive = TRUE),
  teardown_env()
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| rappdirs::user_cache_dir() | tools::R_user_dir() | R 4.0.0 (2020) | rappdirs no longer CRAN-recommended |
| Single global manifest | Per-dataset manifests | Best practice | Better scalability, isolation |
| SQLite for tracking | JSON manifest for simple cases | Ongoing | JSON sufficient for file metadata |

**Deprecated/outdated:**
- `rappdirs`: CRAN now complains about it for user directory management. Use `tools::R_user_dir()`.
- Global package options for cache path: Use environment variables (`R_USER_CACHE_DIR`) for override capability.

## Open Questions

Things that couldn't be fully resolved:

1. **Checksum verification**
   - What we know: BiocFileCache and pkgfilecache support MD5 checksums for verification
   - What's unclear: Does OpenNeuro API provide checksums? Cost-benefit for large neuroimaging files?
   - Recommendation: Start without checksums (size validation is already implemented), add later if needed. OpenNeuro's git-annex backend has checksums built-in.

2. **Cache expiration/freshness**
   - What we know: Some caching systems have TTL (time-to-live) or ETag-based freshness
   - What's unclear: Should cached files expire? OpenNeuro datasets are versioned via snapshots.
   - Recommendation: No automatic expiration. Snapshots are immutable, so cached version N should always be valid. Users can clear cache manually.

3. **Multi-process concurrency**
   - What we know: BiocFileCache uses SQLite with locking for concurrent access
   - What's unclear: Is concurrent access a real concern for this package?
   - Recommendation: Start simple with JSON manifests. Rare edge case for interactive R usage. Document that concurrent writes to same dataset may conflict.

## Sources

### Primary (HIGH confidence)
- [tools::R_user_dir documentation](https://search.r-project.org/R/refmans/tools/html/userdir.html) - Official R documentation for CRAN-compliant cache paths
- [jsonlite read_json/write_json](https://rdrr.io/cran/jsonlite/man/read_json.html) - JSON file I/O functions
- [pak cache utilities](https://pak.r-lib.org/reference/cache.html) - Pattern for cache management API design

### Secondary (MEDIUM confidence)
- [R-hub blog: Caching function results](https://blog.r-hub.io/2021/07/30/cache/) - Best practices for R package caching
- [pkgcache README](https://cran.r-project.org/web/packages/pkgcache/readme/README.html) - CRAN testing requirements for cache packages
- [pkgfilecache vignette](https://cran.r-project.org/web/packages/pkgfilecache/vignettes/pkgfilecache.html) - File cache tracking patterns

### Tertiary (LOW confidence)
- [BiocFileCache vignette](https://www.bioconductor.org/packages/devel/bioc/vignettes/BiocFileCache/inst/doc/BiocFileCache.html) - SQLite-based alternative (not used, but informed design)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - tools::R_user_dir is definitive for CRAN, jsonlite is universal
- Architecture: HIGH - Patterns verified against pak, pkgcache, pkgfilecache
- Pitfalls: HIGH - CRAN test requirements verified in pkgcache documentation

**Research date:** 2026-01-21
**Valid until:** 60 days (stable domain, minimal churn in R caching patterns)
