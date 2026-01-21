# Phase 2: Download Engine - Research

**Researched:** 2026-01-21
**Domain:** HTTP file downloads with httr2, progress reporting with cli
**Confidence:** HIGH

## Summary

Phase 2 implements download mechanics for fetching OpenNeuro dataset files via HTTPS. The research confirms httr2 provides robust built-in support for retries with exponential backoff (`req_retry()`), progress bars (`req_progress()`), and direct-to-disk downloads (`req_perform(path = path)`). HTTP range requests for resumable downloads require manual implementation using `req_headers()` with Range headers.

OpenNeuro files can be downloaded via two URL patterns: (1) the GraphQL API can return a `urls` field for files, or (2) direct S3 URLs follow the pattern `https://s3.amazonaws.com/openneuro.org/{dataset_id}/{path}`. The existing `on_files()` function returns file metadata but needs enhancement to include download URLs.

**Primary recommendation:** Use httr2's native `req_progress()`, `req_retry()`, and `req_perform(path=)` for core download mechanics. Implement custom wrapper functions for resumable downloads using Range headers and temp file handling with fs package.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | 1.1.0+ | HTTP requests | Native progress, retry, direct-to-disk downloads |
| cli | 3.6.0+ | Progress bars | Native download-type progress bars with bytes |
| fs | 1.6.0+ | File operations | Cross-platform temp files, atomic moves, path handling |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| rappdirs | 0.3.3+ | Cache directory | Determining default download locations (Phase 3) |
| rlang | 1.1.0+ | Error handling | Custom error classes, abort() messages |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| httr2 + fs | curl directly | Lower level, more code, but more control over streaming |
| cli progress | progress package | Similar capability, cli is already a dependency |

**Installation:**
```bash
# Already in DESCRIPTION from Phase 1
# No new dependencies needed for core download
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── download.R           # Main download functions (on_download, on_download_file)
├── download-progress.R  # Progress bar management
├── download-resume.R    # Resumable download utilities (Range headers)
└── utils-files.R        # File path utilities (dest_dir, temp files)
```

### Pattern 1: httr2 Download Pipeline
**What:** Use httr2's pipe-based API for download configuration
**When to use:** All file downloads
**Example:**
```r
# Source: https://httr2.r-lib.org/reference/req_progress.html
download_file <- function(url, dest_path, client) {
  request(url) |>
    req_progress(type = "down") |>
    req_retry(
      max_tries = 3,
      retry_on_failure = TRUE,
      is_transient = \(resp) resp_status(resp) %in% c(429, 500, 502, 503, 504)
    ) |>
    req_perform(path = dest_path)
}
```

### Pattern 2: Resumable Downloads with Range Headers
**What:** Use HTTP Range headers for partial content requests
**When to use:** Files >= 10 MB (per CONTEXT.md decision)
**Example:**
```r
# Source: https://httr2.r-lib.org/reference/req_headers.html
# Source: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Range_requests
download_resumable <- function(url, dest_path, existing_bytes = 0) {
  req <- request(url) |>
    req_progress(type = "down") |>
    req_retry(max_tries = 3, retry_on_failure = TRUE)

  if (existing_bytes > 0) {
    req <- req |> req_headers("Range" = paste0("bytes=", existing_bytes, "-"))
  }

  # Perform request, check for 206 Partial Content or 200 OK
  resp <- req_perform(req, path = dest_path)

  # 206 = partial content (resumed), 200 = full content
  resp_status(resp) %in% c(200, 206)
}
```

### Pattern 3: Batch Download with Overall Progress
**What:** Download multiple files with overall progress tracking
**When to use:** Dataset downloads (multiple files)
**Example:**
```r
# Source: https://cli.r-lib.org/reference/cli_progress_bar.html
download_batch <- function(file_list, dest_dir, quiet = FALSE) {
  n_files <- nrow(file_list)

  if (!quiet && interactive()) {
    cli::cli_progress_bar(
      name = "Downloading",
      total = n_files,
      format = "{cli::pb_bar} {cli::pb_current}/{cli::pb_total} files"
    )
  }

  for (i in seq_len(n_files)) {
    download_single_file(file_list[i, ], dest_dir)
    if (!quiet && interactive()) cli::cli_progress_update()
  }

  if (!quiet && interactive()) cli::cli_progress_done()
}
```

### Pattern 4: Temp File + Atomic Move
**What:** Download to temp file, rename on success to prevent partial files
**When to use:** All downloads to ensure no corrupt files on disk
**Example:**
```r
# Source: https://fs.r-lib.org/reference/file_temp.html
download_atomic <- function(url, final_path) {
  temp_path <- fs::file_temp(ext = fs::path_ext(final_path))

  tryCatch({
    download_file(url, temp_path)
    fs::dir_create(fs::path_dir(final_path))
    fs::file_move(temp_path, final_path)  # Atomic on same filesystem
    TRUE
  }, error = function(e) {
    # Clean up partial file on failure
    if (fs::file_exists(temp_path)) fs::file_delete(temp_path)
    stop(e)
  })
}
```

### Anti-Patterns to Avoid
- **Writing directly to final destination:** Risk of partial/corrupt files on interruption. Always use temp file + rename.
- **Checking file existence only by name:** Use size comparison to detect incomplete downloads.
- **Ignoring HTTP status codes:** 206 vs 200 distinction is critical for resume logic.
- **Using `file.rename()` for cross-filesystem moves:** Use `fs::file_copy()` when temp and dest are on different filesystems.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Exponential backoff | Custom retry loop | `httr2::req_retry()` | Handles jitter, caps, Retry-After header |
| Progress bars | Print statements | `httr2::req_progress()` + `cli::cli_progress_bar()` | Handles non-interactive, cleanup, formatting |
| Temp files | `paste0(path, ".tmp")` | `fs::file_temp()` | Unique names, cleanup, cross-platform |
| Path construction | `paste(..., sep="/")` | `fs::path()` | Handles trailing slashes, platform differences |
| Directory creation | Nested `dir.create()` | `fs::dir_create()` | Creates parents, no error if exists |

**Key insight:** httr2 and fs have already solved the edge cases (jitter in backoff, non-interactive progress suppression, cross-filesystem moves) that custom implementations typically miss.

## Common Pitfalls

### Pitfall 1: Progress Bar in Non-Interactive Sessions
**What goes wrong:** Progress bars clutter logs in CI/batch jobs
**Why it happens:** Default cli/httr2 progress shows in all sessions
**How to avoid:** Check `interactive()` before showing progress; cli auto-suppresses but verify
**Warning signs:** Garbled output in log files, excessive console output

### Pitfall 2: Resumable Download Without Size Check
**What goes wrong:** Corrupt file if server returns 200 instead of 206 and overwrites partial
**Why it happens:** Server may not support Range requests or file changed
**How to avoid:** Check response status (206 for partial, 200 for full); if 200, re-download from start
**Warning signs:** Downloaded file smaller than expected size

### Pitfall 3: Cross-Filesystem Temp File Move
**What goes wrong:** `fs::file_move()` fails when temp dir and dest are different filesystems
**Why it happens:** OS rename() syscall doesn't work across filesystems
**How to avoid:** Use `fs::file_copy()` + `fs::file_delete()` as fallback, or download to dest filesystem
**Warning signs:** "Invalid cross-device link" errors

### Pitfall 4: Missing Parent Directories
**What goes wrong:** Download fails because dest directory doesn't exist
**Why it happens:** Dataset has nested structure (e.g., `sub-01/anat/`)
**How to avoid:** Always call `fs::dir_create(fs::path_dir(dest_path))` before download
**Warning signs:** "No such file or directory" errors on first download

### Pitfall 5: OpenNeuro URL Encoding
**What goes wrong:** Downloads fail for files with special characters in names
**Why it happens:** Paths not properly URL-encoded
**How to avoid:** Use `utils::URLencode()` on file paths in URL construction
**Warning signs:** 404 errors for files that exist

## Code Examples

Verified patterns from official sources:

### httr2 Progress Bar for Downloads
```r
# Source: https://httr2.r-lib.org/reference/req_progress.html
req <- request("https://s3.amazonaws.com/openneuro.org/ds000001/participants.tsv") |>
  req_progress()

path <- tempfile()
req |> req_perform(path = path)
```

### httr2 Retry with Custom Transient Detection
```r
# Source: https://httr2.r-lib.org/reference/req_retry.html
request(url) |>
  req_retry(
    max_tries = 3,
    retry_on_failure = TRUE,  # Retry on curl/connection failures
    is_transient = \(resp) resp_status(resp) %in% c(429, 500, 502, 503, 504),
    backoff = \(n) min(2^n + runif(1), 60)  # Custom exponential with jitter, cap 60s
  ) |>
  req_perform(path = dest)
```

### cli Download Progress Bar
```r
# Source: https://cli.r-lib.org/reference/cli_progress_bar.html
cli::cli_progress_bar(
  name = "Downloading",
  total = n_files,
  type = "download",  # Shows bytes
  format = "{cli::pb_bar} {cli::pb_current}/{cli::pb_total} [{cli::pb_rate}]"
)

# Update in loop
cli::cli_progress_update(set = i)

# Terminate
cli::cli_progress_done()
```

### HTTP Range Request for Resume
```r
# Source: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Range_requests
existing_size <- fs::file_size(partial_file)

resp <- request(url) |>
  req_headers("Range" = paste0("bytes=", existing_size, "-")) |>
  req_perform(path = partial_file)

# Check response: 206 = partial content (success), 200 = full file (server ignored Range)
if (resp_status(resp) == 206) {
  # Partial content received, append to existing
} else if (resp_status(resp) == 200) {
  # Server returned full file, replace existing
}
```

### OpenNeuro S3 Download URL Construction
```r
# Source: https://neurostars.org/t/downloading-part-of-data-from-openneuro-with-aws/7217
# Pattern: https://s3.amazonaws.com/openneuro.org/{dataset_id}/{file_path}
construct_download_url <- function(dataset_id, file_path) {
  base_url <- "https://s3.amazonaws.com/openneuro.org"
  path_encoded <- utils::URLencode(file_path, reserved = TRUE)
  paste0(base_url, "/", dataset_id, "/", path_encoded)
}

# Example
url <- construct_download_url("ds000001", "sub-01/anat/sub-01_T1w.nii.gz")
# https://s3.amazonaws.com/openneuro.org/ds000001/sub-01/anat/sub-01_T1w.nii.gz
```

### File Size Validation
```r
# Check if existing file matches expected size (skip if complete)
validate_file <- function(path, expected_size) {
  if (!fs::file_exists(path)) return(FALSE)
  actual_size <- as.numeric(fs::file_size(path))
  actual_size == expected_size
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `httr::GET()` with progress callback | `httr2::req_progress()` pipe | httr2 1.0.0 (2023) | Simpler API, better integration |
| `httr::RETRY()` | `httr2::req_retry()` | httr2 1.0.0 (2023) | Built-in exponential backoff |
| `req_perform_stream()` callback | `req_perform_connection()` | httr2 1.1.0 (Jan 2025) | Better streaming API |
| Custom progress bars | `cli::cli_progress_bar()` | cli 3.0 (2021) | Auto non-interactive handling |

**Deprecated/outdated:**
- `httr::GET()` with `write_disk()`: Use httr2 `req_perform(path=)` instead
- `req_perform_stream()`: Superseded by `req_perform_connection()` in httr2 1.2.0
- Manual progress printing: Use cli for proper terminal handling

## OpenNeuro-Specific Findings

### Download URL Options

**Option 1: Direct S3 URLs (Recommended)**
- Pattern: `https://s3.amazonaws.com/openneuro.org/{dataset_id}/{file_path}`
- Works for public datasets without authentication
- Only downloads latest snapshot (historical snapshots not supported via S3)
- Confidence: HIGH (verified in OpenNeuro docs and community posts)

**Option 2: GraphQL `urls` Field**
- The GraphQL API can return a `urls` field for files
- Query: `snapshot(datasetId: "...", tag: "...") { files { urls ... } }`
- Requires modifying `get_files.gql` to include `urls` field
- Confidence: MEDIUM (mentioned in docs but not fully verified)

**Recommendation:** Use direct S3 URL construction for Phase 2. This is simpler, well-documented, and avoids additional API calls. The GraphQL `urls` field can be added later if needed for versioned snapshots or special cases.

### File Path Construction

The existing `on_files()` function returns:
- `filename` - file/directory name
- `size` - file size in bytes
- `directory` - boolean
- `annexed` - boolean (large files)
- `key` - for directory traversal

To get full paths for downloading:
1. Recursively traverse directories using `key` field
2. Build path by tracking parent directories
3. Construct S3 URL from full path

### annexed vs non-annexed Files

Per CONTEXT.md decision, all files (annexed and non-annexed) are downloaded by default. However:
- Annexed files are typically larger (stored in git-annex)
- Non-annexed files are typically smaller metadata files (JSON sidecars, TSV)
- Both use same HTTPS download mechanism

## Open Questions

Things that couldn't be fully resolved:

1. **GraphQL `urls` field availability**
   - What we know: The field exists in the API based on documentation
   - What's unclear: Exact field behavior, whether it requires authentication
   - Recommendation: Test against live API during implementation; fall back to S3 URLs

2. **Versioned snapshot downloads via S3**
   - What we know: S3 sync only gets latest snapshot
   - What's unclear: How to download specific historical versions via HTTPS
   - Recommendation: For Phase 2, document that latest snapshot is downloaded; versioned downloads via DataLad/git-annex is Phase 4 scope

3. **Server Range request support**
   - What we know: HTTP Range requests are standard
   - What's unclear: Whether OpenNeuro's S3 bucket supports Range headers
   - Recommendation: Test during implementation; gracefully fall back to full re-download if unsupported

## Sources

### Primary (HIGH confidence)
- [httr2 req_progress()](https://httr2.r-lib.org/reference/req_progress.html) - Progress bar API
- [httr2 req_retry()](https://httr2.r-lib.org/reference/req_retry.html) - Exponential backoff, retry configuration
- [httr2 req_headers()](https://httr2.r-lib.org/reference/req_headers.html) - Custom headers for Range requests
- [httr2 req_perform()](https://httr2.r-lib.org/reference/req_perform.html) - Direct-to-disk downloads via `path` parameter
- [cli progress bars](https://cli.r-lib.org/reference/cli_progress_bar.html) - Download-type progress with bytes
- [MDN Range Requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Range_requests) - HTTP resume protocol
- [fs file_temp()](https://fs.r-lib.org/reference/file_temp.html) - Temp file handling

### Secondary (MEDIUM confidence)
- [httr2 1.1.0 release](https://tidyverse.org/blog/2025/01/httr2-1-1-0/) - Latest httr2 features
- [OpenNeuro API docs](https://docs.openneuro.org/api.html) - GraphQL API structure
- [OpenNeuro architecture](https://docs.openneuro.org/architecture.html) - S3 storage overview

### Tertiary (LOW confidence)
- [Neurostars S3 download discussion](https://neurostars.org/t/downloading-part-of-data-from-openneuro-with-aws/7217) - Community S3 URL patterns
- [openneuro-py GitHub](https://github.com/hoechenberger/openneuro-py) - Python implementation reference

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - httr2 and cli are official r-lib packages with extensive documentation
- Architecture: HIGH - Patterns directly from official httr2 documentation
- Pitfalls: MEDIUM - Combination of documentation and practical experience
- OpenNeuro URLs: MEDIUM - Documentation confirmed, live testing recommended

**Research date:** 2026-01-21
**Valid until:** 2026-02-21 (30 days - stable domain, httr2 API unlikely to change)
