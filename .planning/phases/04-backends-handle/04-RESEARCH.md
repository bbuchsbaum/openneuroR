# Phase 4: Backends + Handle - Research

**Researched:** 2026-01-21
**Domain:** CLI backend integration (AWS CLI, DataLad), lazy handle patterns in R
**Confidence:** MEDIUM

## Summary

This phase adds alternative download backends (S3 via AWS CLI, DataLad via CLI) to the existing HTTPS backend, with automatic backend selection based on availability, plus lazy handles that defer downloads until explicitly fetched. The research confirms that:

1. **S3 Backend:** Use `aws s3 sync --no-sign-request` for public bucket access. The OpenNeuro S3 bucket (`s3://openneuro.org`) supports anonymous access. AWS CLI provides incremental sync (only downloads new/changed files), making it efficient for large datasets.

2. **DataLad Backend:** Use `datalad clone` followed by `datalad get` for selective file retrieval with integrity verification. DataLad provides checksum-based verification via git-annex, supporting partial retrieval of specific files or directories.

3. **CLI Execution:** Use `processx::run()` for executing CLI commands from R. It provides robust error handling, timeout support, and proper stdout/stderr capture without shell overhead.

4. **Lazy Handle Pattern:** Implement using S3 class (not R6) to stay consistent with the package's tidyverse style. Use a list-based structure with a class attribute tracking state (pending, ready) and deferred download execution.

**Primary recommendation:** Use `processx::run()` for CLI execution, detect backends via `Sys.which()` at first use (lazy detection), implement handles as S3 classes with `$fetch()` and `$path()` methods, and provide silent fallback through the priority chain.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| processx | 3.8.0+ | Execute CLI commands | r-lib package, robust error handling, timeout support |
| cli | 3.6.0+ | User messaging | Already a dependency |
| fs | 1.6.0+ | File operations | Already a dependency |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| rlang | 1.1.0+ | Error handling | Already a dependency |

### External Dependencies (System)
| Tool | Version | Purpose | Detection |
|------|---------|---------|-----------|
| AWS CLI | 2.x | S3 downloads | `Sys.which("aws")` |
| DataLad | 0.18+ | DataLad downloads | `Sys.which("datalad")` |
| git-annex | 10+ | DataLad dependency | `Sys.which("git-annex")` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| processx | system2() | system2 lacks timeout, proper error handling |
| processx | sys package | sys is simpler but less control |
| S3 class for handles | R6 class | R6 more powerful but adds dependency, non-idiomatic for tidyverse |

**Installation:**
```bash
# processx needs to be added to DESCRIPTION Imports
# External tools are user's responsibility to install
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── backend-detect.R     # Backend availability detection
├── backend-s3.R         # S3/AWS CLI backend implementation
├── backend-datalad.R    # DataLad backend implementation
├── backend-https.R      # Existing HTTPS backend (refactored from download-file.R)
├── backend-dispatch.R   # Auto-select and fallback logic
├── handle.R             # Lazy handle class and methods
└── download.R           # Modified to support backend parameter
```

### Pattern 1: Backend Availability Detection
**What:** Check if CLI tools are installed using `Sys.which()`
**When to use:** On first backend use (lazy detection)
**Example:**
```r
# Source: https://rdrr.io/r/base/Sys.which.html
.backend_available <- function(backend) {
  switch(backend,
    "s3" = nzchar(Sys.which("aws")),
    "datalad" = nzchar(Sys.which("datalad")) && nzchar(Sys.which("git-annex")),
    "https" = TRUE,  # Always available
    FALSE
  )
}

# Cache result for session
.backend_status <- local({
  cache <- list()
  function(backend, refresh = FALSE) {
    if (refresh || is.null(cache[[backend]])) {
      cache[[backend]] <<- .backend_available(backend)
    }
    cache[[backend]]
  }
})
```

### Pattern 2: S3 Backend with processx
**What:** Execute AWS CLI commands for S3 sync
**When to use:** S3 backend downloads
**Example:**
```r
# Source: https://processx.r-lib.org/reference/run.html
# Source: https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html
.download_s3 <- function(dataset_id, dest_dir, files = NULL, quiet = FALSE) {
  s3_uri <- paste0("s3://openneuro.org/", dataset_id)

  args <- c("s3", "sync", "--no-sign-request", s3_uri, dest_dir)

  # Add include patterns if specific files requested
  if (!is.null(files)) {
    # Exclude everything first, then include specific patterns
    args <- c(args, "--exclude", "*")
    for (f in files) {
      args <- c(args, "--include", f)
    }
  }

  if (quiet) {
    args <- c(args, "--only-show-errors")
  }

  result <- processx::run(
    command = "aws",
    args = args,
    error_on_status = FALSE,
    timeout = 600  # 10 minute timeout
  )

  if (result$status != 0) {
    rlang::abort(
      c("S3 download failed",
        "x" = result$stderr),
      class = "openneuro_backend_error"
    )
  }

  invisible(result)
}
```

### Pattern 3: DataLad Backend with processx
**What:** Execute DataLad CLI commands for dataset retrieval
**When to use:** DataLad backend downloads
**Example:**
```r
# Source: https://handbook.datalad.org/en/latest/usecases/openneuro.html
# Source: http://docs.datalad.org/en/stable/generated/man/datalad-get.html
.download_datalad <- function(dataset_id, dest_dir, files = NULL, quiet = FALSE) {
  github_url <- paste0("https://github.com/OpenNeuroDatasets/", dataset_id, ".git")

  # Clone if not already present
  if (!fs::dir_exists(dest_dir)) {
    result <- processx::run(
      command = "datalad",
      args = c("clone", github_url, dest_dir),
      error_on_status = FALSE,
      timeout = 300
    )

    if (result$status != 0) {
      rlang::abort(
        c("DataLad clone failed",
          "x" = result$stderr),
        class = "openneuro_backend_error"
      )
    }
  }

  # Get specific files or all
  get_args <- c("get")
  if (is.null(files)) {
    get_args <- c(get_args, ".")
  } else {
    get_args <- c(get_args, files)
  }

  result <- processx::run(
    command = "datalad",
    args = get_args,
    wd = dest_dir,
    error_on_status = FALSE,
    timeout = 600
  )

  if (result$status != 0) {
    rlang::abort(
      c("DataLad get failed",
        "x" = result$stderr),
      class = "openneuro_backend_error"
    )
  }

  invisible(result)
}
```

### Pattern 4: Auto-Select with Fallback
**What:** Automatically select best available backend with silent fallback
**When to use:** Default behavior when backend not specified
**Example:**
```r
# Source: CONTEXT.md - DataLad > S3 > HTTPS priority
.select_backend <- function(preferred = NULL) {
  # If user specified, use that (but check availability)
  if (!is.null(preferred)) {
    if (.backend_status(preferred)) {
      return(preferred)
    }
    rlang::warn(
      c("Requested backend not available",
        "!" = paste0("Backend '", preferred, "' is not installed"),
        "i" = "Falling back to next available backend")
    )
  }

  # Auto-select by priority
  backends <- c("datalad", "s3", "https")
  for (backend in backends) {
    if (.backend_status(backend)) {
      return(backend)
    }
  }

  # Should never reach here (https always available)
  "https"
}

.download_with_backend <- function(dataset_id, dest_dir, files = NULL,
                                    backend = NULL, quiet = FALSE) {
  selected <- .select_backend(backend)

  tryCatch({
    switch(selected,
      "datalad" = .download_datalad(dataset_id, dest_dir, files, quiet),
      "s3" = .download_s3(dataset_id, dest_dir, files, quiet),
      "https" = .download_https(dataset_id, dest_dir, files, quiet)  # existing
    )

    list(success = TRUE, backend = selected)
  }, openneuro_backend_error = function(e) {
    # Fallback on error
    if (selected != "https") {
      if (!quiet) {
        cli::cli_alert_warning("{selected} backend failed, falling back...")
      }
      .download_with_backend(dataset_id, dest_dir, files,
                              backend = if (selected == "datalad") "s3" else "https",
                              quiet = quiet)
    } else {
      stop(e)
    }
  })
}
```

### Pattern 5: S3 Class Lazy Handle
**What:** S3 class representing a lazy reference to a dataset
**When to use:** Pipeline-friendly deferred downloads
**Example:**
```r
# S3 class approach (consistent with tidyverse style)
# Source: STATE.md decision - S3 client class (not R6)

#' Create Lazy Handle to Dataset
#' @export
on_handle <- function(dataset_id, tag = NULL, files = NULL, backend = NULL) {
  # Validate dataset exists (lightweight check via API)
  # Don't download anything yet

  structure(
    list(
      dataset_id = dataset_id,
      tag = tag,
      files = files,
      backend = backend,
      state = "pending",    # pending | downloading | ready
      path = NULL,          # Populated after fetch
      fetch_time = NULL
    ),
    class = c("openneuro_handle", "list")
  )
}

#' Fetch Handle (Materialize Download)
#' @export
on_fetch <- function(handle, ...) {
  UseMethod("on_fetch")
}

#' @export
on_fetch.openneuro_handle <- function(handle, quiet = FALSE, force = FALSE, ...) {
  if (handle$state == "ready" && !force) {
    return(handle)
  }

  handle$state <- "downloading"

  # Perform download using backend
  result <- on_download(
    id = handle$dataset_id,
    tag = handle$tag,
    files = handle$files,
    backend = handle$backend,
    quiet = quiet
  )

  handle$state <- "ready"
  handle$path <- result$dest_dir
  handle$fetch_time <- Sys.time()

  handle
}

#' Get Path from Handle
#' @export
on_path <- function(handle) {
  UseMethod("on_path")
}

#' @export
on_path.openneuro_handle <- function(handle) {
  if (handle$state != "ready") {
    rlang::abort(
      c("Handle not yet fetched",
        "i" = "Call on_fetch(handle) first"),
      class = "openneuro_handle_error"
    )
  }
  handle$path
}

# Print method for nice display
#' @export
print.openneuro_handle <- function(x, ...) {
  cli::cli_text("{.cls openneuro_handle}")
  cli::cli_bullets(c(
    " " = "Dataset: {.val {x$dataset_id}}",
    " " = "State: {.val {x$state}}",
    " " = if (!is.null(x$path)) "Path: {.path {x$path}}" else "Path: <not fetched>"
  ))
  invisible(x)
}
```

### Anti-Patterns to Avoid

- **Checking backend availability at package load:** Too slow, may not be needed. Use lazy detection.
- **Using shell=TRUE with processx:** Introduces security risks and portability issues. Pass args as vector.
- **Hardcoding S3 bucket name everywhere:** Define once in a constant or config.
- **R6 for simple data containers:** S3 classes are more idiomatic for tidyverse packages. R6 is overkill for handles.
- **Blocking on backend detection:** Cache detection results for the session.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CLI execution | system()/system2() | processx::run() | Timeout, proper error handling, no shell |
| Path checking | Custom PATH search | Sys.which() | Cross-platform, handles edge cases |
| S3 partial downloads | Custom S3 client | aws s3 sync | Handles incremental, retries, parallelism |
| Data integrity | Manual checksums | DataLad/git-annex | Built-in verification, deduplication |
| Temp file handling | Manual paths | fs::file_temp() | Already used in codebase |

**Key insight:** AWS CLI and DataLad are battle-tested tools. Wrapping them via processx is simpler and more robust than reimplementing their functionality in R.

## Common Pitfalls

### Pitfall 1: AWS CLI Not in PATH
**What goes wrong:** `Sys.which("aws")` returns empty string even though AWS CLI is installed
**Why it happens:** AWS CLI installed via pip/homebrew may not be in system PATH
**How to avoid:** Check common installation paths, provide helpful error message
**Warning signs:** Works locally, fails in CI or for other users

```r
.find_aws_cli <- function() {
  path <- Sys.which("aws")
  if (nzchar(path)) return(path)

  # Check common locations
  common_paths <- c(
    "/usr/local/bin/aws",
    "/opt/homebrew/bin/aws",
    "~/.local/bin/aws",
    if (.Platform$OS.type == "windows") {
      c("C:/Program Files/Amazon/AWSCLIV2/aws.exe",
        "C:/Program Files/Amazon/AWSCLI/bin/aws.exe")
    }
  )

  for (p in common_paths) {
    if (fs::file_exists(p)) return(p)
  }

  ""  # Not found
}
```

### Pitfall 2: DataLad Clone to Existing Directory
**What goes wrong:** DataLad clone fails if directory already exists
**Why it happens:** User may have partial download or changed settings
**How to avoid:** Check for existing .datalad directory, use update instead of clone
**Warning signs:** "destination path already exists" errors

```r
.datalad_get_or_clone <- function(dataset_id, dest_dir) {
  datalad_dir <- fs::path(dest_dir, ".datalad")

  if (fs::dir_exists(datalad_dir)) {
    # Already a DataLad dataset - use update/get
    return("update")
  } else if (fs::dir_exists(dest_dir) && length(fs::dir_ls(dest_dir)) > 0) {
    # Non-empty directory that's not a DataLad dataset
    rlang::abort(
      c("Destination exists but is not a DataLad dataset",
        "x" = paste0("Directory not empty: ", dest_dir),
        "i" = "Use a different destination or clear the directory"),
      class = "openneuro_backend_error"
    )
  }

  "clone"
}
```

### Pitfall 3: S3 Sync Downloads Everything
**What goes wrong:** User requests specific files but aws s3 sync downloads entire dataset
**Why it happens:** --include/--exclude order matters; --include without --exclude doesn't filter
**How to avoid:** Always start with --exclude "*" when using --include patterns
**Warning signs:** Downloads take much longer than expected

### Pitfall 4: Timeout on Large Datasets
**What goes wrong:** Download killed by processx timeout
**Why it happens:** Default timeout too short for large datasets
**How to avoid:** Set generous timeout or disable (timeout = NULL) for known large operations
**Warning signs:** Partial downloads, "timeout" in result

### Pitfall 5: Handle State Not Persisting
**What goes wrong:** User modifies handle but changes don't persist
**Why it happens:** S3 objects have copy semantics, not reference semantics
**How to avoid:** Document that `on_fetch()` returns a NEW handle; user must capture it
**Warning signs:** `handle$state` still shows "pending" after fetch

```r
# WRONG - handle not updated
on_fetch(handle)
handle$state  # Still "pending"!

# CORRECT - capture returned handle
handle <- on_fetch(handle)
handle$state  # Now "ready"
```

## Code Examples

Verified patterns from official sources:

### processx::run() for CLI Commands
```r
# Source: https://processx.r-lib.org/reference/run.html
# Execute command and capture output
result <- processx::run(
  command = "aws",
  args = c("s3", "ls", "--no-sign-request", "s3://openneuro.org/"),
  error_on_status = FALSE,
  timeout = 60
)

# Check result
if (result$status == 0) {
  # Success - parse stdout
  lines <- strsplit(result$stdout, "\n")[[1]]
} else {
  # Failure - report stderr
  message("Error: ", result$stderr)
}
```

### AWS CLI S3 Sync with Include/Exclude
```r
# Source: https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html
# Download specific files from OpenNeuro
args <- c(
  "s3", "sync",
  "--no-sign-request",
  "s3://openneuro.org/ds000001",
  "/path/to/dest",
  "--exclude", "*",                     # Exclude everything first
  "--include", "participants.tsv",      # Include specific files
  "--include", "sub-*/anat/*.nii.gz"    # Include with glob pattern
)

processx::run(command = "aws", args = args, error_on_status = FALSE)
```

### DataLad Clone and Get
```r
# Source: https://handbook.datalad.org/en/latest/usecases/openneuro.html
# Clone dataset
processx::run(
  command = "datalad",
  args = c("clone", "https://github.com/OpenNeuroDatasets/ds000001.git", "ds000001"),
  error_on_status = FALSE
)

# Get specific files (run from within dataset directory)
processx::run(
  command = "datalad",
  args = c("get", "sub-01/anat/"),
  wd = "ds000001",
  error_on_status = FALSE
)

# Get with glob pattern
processx::run(
  command = "datalad",
  args = c("get", "sub-*/func/*bold*.nii.gz"),
  wd = "ds000001",
  error_on_status = FALSE
)
```

### Backend Availability Check
```r
# Source: https://rdrr.io/r/base/Sys.which.html
.check_backends <- function() {
  backends <- c(
    aws = nzchar(Sys.which("aws")),
    datalad = nzchar(Sys.which("datalad")),
    git_annex = nzchar(Sys.which("git-annex"))
  )

  available <- names(backends)[backends]

  list(
    datalad = backends["datalad"] && backends["git_annex"],
    s3 = backends["aws"],
    https = TRUE
  )
}
```

### S3 Class Print Method
```r
# Source: R convention for S3 print methods
#' @export
print.openneuro_handle <- function(x, ...) {
  cat("<openneuro_handle>\n")
  cat("  Dataset:", x$dataset_id, "\n")
  cat("  Tag:", x$tag %||% "latest", "\n")
  cat("  State:", x$state, "\n")
  if (x$state == "ready") {
    cat("  Path:", x$path, "\n")
  }
  invisible(x)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| system()/system2() | processx::run() | processx 3.0 (2018) | Robust timeout, error handling |
| R6 for everything | S3 for simple classes | Ongoing discussion | R6 only when reference semantics truly needed |
| Direct S3 API calls | aws.s3 or AWS CLI | Varies | CLI simpler for public bucket access |
| Custom checksum verification | DataLad/git-annex | Ongoing | Battle-tested integrity |

**Deprecated/outdated:**
- `system()` with `paste0()` command strings: Security risk, use processx with args vector
- `aws.s3` package for public buckets: Requires credentials config; CLI with --no-sign-request is simpler
- Global backend detection at load: Use lazy detection instead

## Integration with Existing Infrastructure

### Cache Integration
The new backends must integrate with the existing cache infrastructure:

1. **S3 Backend:** Downloads to cache path, then updates manifest
2. **DataLad Backend:** Clone to cache path, manifest tracks DataLad source
3. **Manifest Backend Field:** Already exists (`backend` field in manifest entries)

```r
# Manifest entry with backend tracking
file_entry <- list(
  path = "sub-01/anat/T1w.nii.gz",
  size = 15234567,
  downloaded_at = "2026-01-21T10:30:00Z",
  backend = "s3"  # or "datalad" or "https"
)
```

### Download Function Integration
Modify `on_download()` to accept `backend` parameter:

```r
on_download <- function(id, tag = NULL, files = NULL, dest_dir = NULL,
                        use_cache = TRUE, quiet = FALSE, verbose = FALSE,
                        force = FALSE, backend = NULL,  # NEW
                        client = NULL) {
  # ... existing validation ...

  # Use backend dispatcher
  result <- .download_with_backend(
    dataset_id = id,
    dest_dir = dest_dir,
    files = filtered_files$full_path,
    backend = backend,
    quiet = quiet
  )

  # ... existing manifest/return logic ...
}
```

## Open Questions

Things that couldn't be fully resolved:

1. **S3 Bucket Snapshot Versioning**
   - What we know: S3 sync downloads "latest snapshot"
   - What's unclear: Can specific snapshot versions be accessed via S3? Structure of versioned paths?
   - Recommendation: Document that S3 backend downloads latest only; use DataLad for specific versions

2. **DataLad Performance vs S3**
   - What we know: DataLad has integrity checks; S3 is generally faster for bulk downloads
   - What's unclear: Actual performance comparison for typical OpenNeuro dataset sizes
   - Recommendation: Keep DataLad as default for integrity; S3 for speed-priority users

3. **Partial S3 Sync with File Patterns**
   - What we know: aws s3 sync supports --include/--exclude glob patterns
   - What's unclear: How well glob patterns map to on_files() file list format
   - Recommendation: Test extensively; may need to construct patterns carefully or fall back to HTTPS

4. **Handle Serialization**
   - What we know: S3 objects can be serialized with saveRDS()
   - What's unclear: Should handles be portable across sessions? What about path changes?
   - Recommendation: Start simple; handles reference cache paths which are stable per-user

## Sources

### Primary (HIGH confidence)
- [processx documentation](https://processx.r-lib.org/) - CLI execution from R
- [processx::run() reference](https://processx.r-lib.org/reference/run.html) - Function parameters and return value
- [AWS CLI s3 sync reference](https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html) - S3 sync options
- [DataLad Handbook - OpenNeuro](https://handbook.datalad.org/en/latest/usecases/openneuro.html) - DataLad commands for OpenNeuro
- [Sys.which documentation](https://rdrr.io/r/base/Sys.which.html) - Command detection in R

### Secondary (MEDIUM confidence)
- [OpenNeuro Registry on AWS](https://registry.opendata.aws/openneuro/) - S3 bucket details
- [rOpenSci System Calls Guide](https://ropensci.org/blog/2021/09/13/system-calls-r-package/) - Best practices for CLI wrappers
- [DataLad install](http://docs.datalad.org/en/stable/generated/man/datalad-install.html) - Install command docs
- [DataLad get](http://docs.datalad.org/en/stable/generated/man/datalad-get.html) - Get command docs
- [Advanced R - OO Tradeoffs](https://adv-r.hadley.nz/oo-tradeoffs.html) - S3 vs R6 guidance

### Tertiary (LOW confidence)
- [Neurostars OpenNeuro S3 discussion](https://neurostars.org/t/downloading-part-of-data-from-openneuro-with-aws/7217) - Community patterns
- [DataLad integrity docs](https://handbook.datalad.org/en/latest/basics/101-115-symlinks.html) - Checksum verification details

## Metadata

**Confidence breakdown:**
- S3 Backend: MEDIUM - AWS CLI well-documented; OpenNeuro S3 structure needs testing
- DataLad Backend: MEDIUM - DataLad docs good; integration with cache needs validation
- Backend Detection: HIGH - Sys.which() is base R, well-understood
- Lazy Handle Pattern: MEDIUM - S3 class approach follows package conventions; lifecycle needs testing
- Auto-Select/Fallback: MEDIUM - Logic clear; error recovery paths need testing

**Research date:** 2026-01-21
**Valid until:** 2026-02-21 (30 days - processx/AWS CLI stable; DataLad evolving)
