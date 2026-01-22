# Phase 8: BIDS Bridge - Research

**Researched:** 2026-01-22
**Domain:** Optional package integration, BIDS neuroimaging format, bidser package
**Confidence:** HIGH

## Summary

This phase implements `on_bids()`, a bridge function that converts fetched OpenNeuro dataset handles into bidser `bids_project` objects for rich BIDS-aware data access. The primary challenge is handling bidser as an optional dependency (Suggests) while providing a seamless user experience.

The bidser package provides `bids_project(path, fmriprep=FALSE, prep_dir="derivatives/fmriprep")` as its main constructor. Our wrapper function needs to: (1) check bidser availability with helpful installation guidance, (2) auto-fetch handles if needed, (3) validate BIDS structure, and (4) pass through fmriprep/prep_dir parameters correctly.

Key technical decisions are already locked in CONTEXT.md: accept only handles (not raw paths), auto-fetch if pending, use `cli::cli_abort()` for errors, and let `prep_dir` override `fmriprep=TRUE`.

**Primary recommendation:** Use `rlang::check_installed("bidser", reason="...")` for dependency checking with interactive install prompt, wrap bidser calls with namespace qualification (`bidser::bids_project()`), and validate `dataset_description.json` exists before calling bidser.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bidser | dev (GitHub) | BIDS project objects | Author's own package, designed for this use case |
| rlang | >= 1.1.0 | Dependency checking | `check_installed()` provides interactive install prompts |
| cli | >= 3.6.0 | User messaging | Already used throughout openneuroR for consistent UX |
| fs | >= 1.6.6 | Path manipulation | Already imported, handles cross-platform paths |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jsonlite | >= 1.8.0 | BIDS validation | Already imported, validate dataset_description.json |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bidser | bidsr (CRAN) | bidsr is on CRAN but different API; bidser matches project author |
| rlang::check_installed | requireNamespace + stop | check_installed offers interactive install, cleaner UX |

**Installation:**
```r
# bidser is GitHub-only (Suggests)
# devtools::install_github("bbuchsbaum/bidser")
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── bids.R           # on_bids() main function
├── handle.R         # Existing handle functions (on_handle, on_fetch, on_path)
└── ...
```

Single new file `bids.R` containing `on_bids()` and helper functions.

### Pattern 1: Optional Dependency Check with rlang
**What:** Use `rlang::check_installed()` for graceful dependency handling
**When to use:** Before any call to bidser functions
**Example:**
```r
# Source: https://rlang.r-lib.org/reference/is_installed.html
on_bids <- function(handle, fmriprep = FALSE, prep_dir = "derivatives/fmriprep") {
  rlang::check_installed(
    "bidser",
    reason = "to create BIDS project objects from OpenNeuro datasets"
  )
  # ... rest of function
}
```

### Pattern 2: Auto-Fetch Pending Handles
**What:** Transparently fetch if handle not yet materialized
**When to use:** When user calls `on_bids()` on a pending handle
**Example:**
```r
# Source: Existing on_fetch() pattern in R/handle.R
on_bids <- function(handle, fmriprep = FALSE, prep_dir = "derivatives/fmriprep") {
  # Validate input is a handle
 .validate_handle(handle)

  # Auto-fetch if pending
  if (handle$state == "pending") {
    handle <- on_fetch(handle)
  }

  path <- on_path(handle)
  # ... continue with bidser
}
```

### Pattern 3: BIDS Validation Before bidser
**What:** Check dataset_description.json exists before calling bidser
**When to use:** Always, to provide better error messages
**Example:**
```r
# Source: BIDS spec requires dataset_description.json
.validate_bids_structure <- function(path) {
  desc_file <- fs::path(path, "dataset_description.json")
  if (!fs::file_exists(desc_file)) {
    cli::cli_abort(c(
      "Not a valid BIDS dataset",
      "x" = "Missing required {.file dataset_description.json}",
      "i" = "This file is required by the BIDS specification"
    ), class = "openneuro_bids_error")
  }
  invisible(TRUE)
}
```

### Pattern 4: Namespace-Qualified External Calls
**What:** Always use `bidser::` prefix for Suggests packages
**When to use:** All calls to bidser functions
**Example:**
```r
# Source: R Packages book - Dependencies in Practice
# https://r-pkgs.org/dependencies-in-practice.html
proj <- bidser::bids_project(
  path = path,
  fmriprep = fmriprep,
  prep_dir = prep_dir
)
```

### Pattern 5: Derivatives Path Validation with Warning
**What:** Warn but continue if fmriprep path doesn't exist
**When to use:** When fmriprep=TRUE or prep_dir specified
**Example:**
```r
# Source: CONTEXT.md decision - warn and continue without derivatives
.check_derivatives_path <- function(path, fmriprep, prep_dir) {
  if (!fmriprep && prep_dir == "derivatives/fmriprep") {
    return(invisible(NULL))  # Default, not requesting derivatives
  }

  deriv_path <- fs::path(path, prep_dir)
  if (!fs::dir_exists(deriv_path)) {
    cli::cli_warn(c(
      "Derivatives directory not found",
      "!" = "Path {.path {deriv_path}} does not exist",
      "i" = "Continuing without fMRIPrep derivatives"
    ))
    return(FALSE)  # Signal to set fmriprep=FALSE
  }
  TRUE
}
```

### Anti-Patterns to Avoid
- **Direct require()/library():** Never use `library(bidser)` or `require(bidser)` - these attach to search path and can cause conflicts
- **Assume bidser installed:** Always check first with `rlang::check_installed()`
- **Accept raw paths:** Per CONTEXT.md, only accept handle objects for API consistency
- **Cache bids_project in handle:** Per CONTEXT.md, create fresh object each call

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BIDS file parsing | Custom regex parsers | bidser::bids_project() | BIDS spec is complex with many edge cases |
| Install prompt | Custom message + readline | rlang::check_installed() | Handles interactive/non-interactive, offers install |
| Derivatives detection | String concatenation | bidser's prep_dir parameter | bidser handles internal path resolution |
| Subject enumeration | Parse directories | bidser bids_project methods | bidser tracks subjects, sessions correctly |

**Key insight:** bidser exists precisely to handle BIDS complexity. Our job is to bridge OpenNeuro handles to bidser, not replicate BIDS parsing.

## Common Pitfalls

### Pitfall 1: Forgetting Namespace Qualification
**What goes wrong:** `bids_project()` call fails because function not found
**Why it happens:** Suggests packages aren't loaded, so bare function names don't resolve
**How to avoid:** Always use `bidser::bids_project()` with full namespace
**Warning signs:** "could not find function" errors in tests or user reports

### Pitfall 2: Not Handling Auto-Fetch Return Value
**What goes wrong:** Handle remains "pending" after on_bids() because auto-fetch result wasn't captured
**Why it happens:** S3 objects have copy semantics - `on_fetch(handle)` doesn't modify `handle` in place
**How to avoid:** Always capture: `handle <- on_fetch(handle)`
**Warning signs:** "Handle not yet fetched" errors even after calling on_bids()

### Pitfall 3: Testing with Real bidser Installation
**What goes wrong:** Tests fail on systems without bidser, or tests pass locally but fail in CI
**Why it happens:** bidser is Suggests, not guaranteed to be installed
**How to avoid:**
  1. Use `testthat::skip_if_not_installed("bidser")` for integration tests
  2. Mock `rlang::check_installed` and `bidser::bids_project` for unit tests
**Warning signs:** Sporadic test failures, "package 'bidser' not available" errors

### Pitfall 4: Assuming Derivatives Always Exist
**What goes wrong:** bidser errors or returns empty/broken object when derivatives missing
**Why it happens:** User requests fmriprep=TRUE but dataset has no derivatives
**How to avoid:** Check path exists, warn, and call bidser with fmriprep=FALSE
**Warning signs:** Confusing bidser errors about missing directories

### Pitfall 5: R CMD check Failures with Suggests
**What goes wrong:** Examples fail during R CMD check when bidser unavailable
**Why it happens:** Examples run unconditionally unless wrapped
**How to avoid:** Wrap examples in `\dontrun{}` or use `@examplesIf` with condition
**Warning signs:** R CMD check errors about missing package in examples

### Pitfall 6: Input Validation Gaps
**What goes wrong:** Confusing errors from bidser when user passes wrong type
**Why it happens:** User passes raw path string instead of handle
**How to avoid:** Validate input is `openneuro_handle` class, provide helpful error with suggestion
**Warning signs:** Error messages that don't mention on_handle()

## Code Examples

Verified patterns from official sources and codebase conventions:

### Complete on_bids() Function Structure
```r
# Source: Synthesized from CONTEXT.md, rlang docs, bidser docs
#' Get BIDS Project from OpenNeuro Handle
#'
#' @param handle An `openneuro_handle` object (from [on_handle()]).
#' @param fmriprep If TRUE, include fMRIPrep derivatives. Default FALSE.
#' @param prep_dir Path to derivatives directory relative to dataset root.
#'   Default "derivatives/fmriprep". Overrides fmriprep=TRUE if specified.
#'
#' @return A `bids_project` object from the bidser package.
#'
#' @export
#' @examples
#' \dontrun{
#' handle <- on_handle("ds000001") |> on_fetch()
#' proj <- on_bids(handle)
#'
#' # With fMRIPrep derivatives
#' proj <- on_bids(handle, fmriprep = TRUE)
#' }
on_bids <- function(handle, fmriprep = FALSE, prep_dir = "derivatives/fmriprep") {
  # Check optional dependency
  rlang::check_installed(
    "bidser",
    reason = "to create BIDS project objects from OpenNeuro datasets"
  )

  # Validate input type
  if (!inherits(handle, "openneuro_handle")) {
    cli::cli_abort(c(
      "Expected an {.cls openneuro_handle} object",
      "x" = "Got {.cls {class(handle)[1]}} instead",
      "i" = "Create a handle with {.code on_handle(\"ds000001\")}"
    ), class = "openneuro_validation_error")
  }

 # Auto-fetch if pending
  if (handle$state == "pending") {
    handle <- on_fetch(handle)
  }

  path <- on_path(handle)

  # Validate BIDS structure
  .validate_bids_structure(path)

  # Check derivatives if requested
  use_fmriprep <- fmriprep
  if (fmriprep || prep_dir != "derivatives/fmriprep") {
    deriv_exists <- .check_derivatives_path(path, fmriprep, prep_dir)
    if (isFALSE(deriv_exists)) {
      use_fmriprep <- FALSE
    }
  }

  # Create BIDS project
  cli::cli_alert_info("Creating BIDS project from {.val {handle$dataset_id}}")

  bidser::bids_project(
    path = path,
    fmriprep = use_fmriprep,
    prep_dir = prep_dir
  )
}
```

### Helper: Validate BIDS Structure
```r
# Source: BIDS specification - dataset_description.json required
.validate_bids_structure <- function(path) {
  desc_file <- fs::path(path, "dataset_description.json")

  if (!fs::file_exists(desc_file)) {
    cli::cli_abort(c(
      "Not a valid BIDS dataset",
      "x" = "Missing required {.file dataset_description.json}",
      "i" = "This file is required by the BIDS specification",
      "i" = "The dataset at {.path {path}} may not be BIDS-formatted"
    ), class = "openneuro_bids_error")
  }

  invisible(TRUE)
}
```

### Helper: Check Derivatives Path
```r
# Source: CONTEXT.md - warn and continue if path missing
.check_derivatives_path <- function(path, fmriprep, prep_dir) {
  # If not requesting derivatives, nothing to check
  if (!fmriprep && prep_dir == "derivatives/fmriprep") {
    return(invisible(NULL))
  }

  deriv_path <- fs::path(path, prep_dir)

  if (!fs::dir_exists(deriv_path)) {
    cli::cli_warn(c(
      "Derivatives directory not found",
      "!" = "Path {.path {deriv_path}} does not exist",
      "i" = "Continuing without fMRIPrep derivatives"
    ))
    return(FALSE)
  }

  TRUE
}
```

### Test: Check Bidser Not Installed Message
```r
# Source: testthat mocking docs
# https://testthat.r-lib.org/articles/mocking.html
test_that("on_bids gives helpful message when bidser not installed", {
  # Create wrapper to mock
  check_bidser <- function() {
    rlang::check_installed("bidser", reason = "test")
  }

  local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if (pkg == "bidser") {
        rlang::abort(
          c("Package 'bidser' is required",
            "i" = "Install with: devtools::install_github(\"bbuchsbaum/bidser\")"),
          class = "rlib_error_package_not_found"
        )
      }
    },
    .package = "rlang"
  )

  handle <- on_handle("ds000001")
  handle$state <- "ready"
  handle$path <- tempdir()

  expect_error(on_bids(handle), class = "rlib_error_package_not_found")
})
```

### Test: Input Validation
```r
# Source: Existing test patterns in test-handle.R
test_that("on_bids rejects non-handle input", {
  skip_if_not_installed("bidser")

  expect_error(
    on_bids("/some/path"),
    class = "openneuro_validation_error"
  )

  expect_error(
    on_bids(list(dataset_id = "ds000001")),
    class = "openneuro_validation_error"
  )
})
```

### Test: Mock Full Integration
```r
# Source: Mocking pattern from testthat docs
test_that("on_bids creates bids_project from ready handle", {
  skip_if_not_installed("bidser")

  # Create temp BIDS-like structure
  tmp <- withr::local_tempdir()
  writeLines('{"Name": "Test", "BIDSVersion": "1.0.0"}',
             fs::path(tmp, "dataset_description.json"))

  handle <- on_handle("ds000001")
  handle$state <- "ready"
  handle$path <- tmp

  proj <- on_bids(handle)
  expect_s3_class(proj, "bids_project")
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| require() + stop() | rlang::check_installed() | rlang 1.0.0 (2022) | Interactive install prompts |
| with_mock() | local_mocked_bindings() | testthat 3.1.2 (2022) | Safer, no R internals abuse |
| Manual path handling | fs package | Ongoing | Cross-platform reliability |

**Deprecated/outdated:**
- `testthat::with_mock()`: Now defunct, use `local_mocked_bindings()`
- `require(pkg); if (!exists(...))`: Use `rlang::check_installed()` instead

## Open Questions

Things that couldn't be fully resolved:

1. **bidser CRAN status**
   - What we know: bidser is on GitHub only (bbuchsbaum/bidser), not CRAN
   - What's unclear: Timeline for CRAN submission
   - Recommendation: Document GitHub installation in error message and examples

2. **bidser error handling**
   - What we know: bidser::bids_project() can fail on malformed datasets
   - What's unclear: Exact error classes/messages bidser throws
   - Recommendation: Wrap in tryCatch with informative re-throw if needed

3. **Return type decision (Claude's Discretion)**
   - What we know: CONTEXT.md leaves this to discretion
   - Options: Direct bids_project vs wrapper with metadata (handle reference, etc.)
   - Recommendation: Return direct bids_project for simplicity - users can access handle separately

## Sources

### Primary (HIGH confidence)
- [rlang is_installed docs](https://rlang.r-lib.org/reference/is_installed.html) - check_installed() signature and behavior
- [bidser reference](https://bbuchsbaum.github.io/bidser/reference/bids_project.html) - bids_project() signature: `bids_project(path=".", fmriprep=FALSE, prep_dir="derivatives/fmriprep")`
- [bidser source](https://raw.githubusercontent.com/bbuchsbaum/bidser/master/R/bids.R) - Implementation details of fmriprep parameter handling
- [R Packages book - Dependencies](https://r-pkgs.org/dependencies-in-practice.html) - Suggests package handling patterns
- [testthat mocking](https://testthat.r-lib.org/articles/mocking.html) - local_mocked_bindings() patterns

### Secondary (MEDIUM confidence)
- [BIDS specification](https://bids-specification.readthedocs.io/en/stable/) - dataset_description.json requirements
- [testthat local_mocked_bindings](https://testthat.r-lib.org/reference/local_mocked_bindings.html) - Function signatures

### Tertiary (LOW confidence)
- WebSearch results for R CMD check behavior with Suggests - patterns verified against R Packages book

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - bidser API verified from official docs and source
- Architecture: HIGH - patterns follow existing codebase conventions and R best practices
- Pitfalls: HIGH - derived from documented R package development challenges

**Research date:** 2026-01-22
**Valid until:** 60 days (bidser API stable, rlang/testthat mature)
