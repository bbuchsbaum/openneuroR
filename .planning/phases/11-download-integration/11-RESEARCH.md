# Phase 11: Download Integration - Research

**Researched:** 2026-01-23
**Domain:** Derivative data download with BIDS-compliant filtering (R package extending existing openneuroR infrastructure)
**Confidence:** HIGH

## Summary

Phase 11 adds `on_download_derivatives()` to enable downloading fMRIPrep derivative data with filtering by subject and output space. The existing codebase provides nearly all required infrastructure: `on_download()` for raw datasets with subject filtering, `on_derivatives()` for discovery, `on_spaces()` for space detection, and S3 backend support for the openneuro-derivatives bucket via parameterized `.download_s3()`.

The primary work involves creating a new function that: (1) constructs the correct S3 path for derivatives (`{pipeline}/{dataset_id}-{pipeline}`), (2) lists files from the derivative source, (3) applies subject, space, and suffix filters, (4) downloads to BIDS-compliant cache structure, and (5) updates the unified manifest with derivative type tagging.

**Primary recommendation:** Follow the existing `on_download()` pattern closely. Reuse `.filter_files_by_subjects()` for subject filtering, add new `.filter_files_by_space()` and `.filter_files_by_suffix()` helpers using established regex extraction patterns. Extend the manifest schema to include a `type` field ("raw" or "derivative") for unified cache visibility.

## Standard Stack

### Core (Already in Package)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| httr2 | >= 1.2.1 | HTTP downloads (HTTPS fallback) | In DESCRIPTION |
| processx | >= 3.8.0 | AWS CLI execution for S3 backend | In DESCRIPTION |
| fs | >= 1.6.6 | Cross-platform filesystem operations | In DESCRIPTION |
| cli | >= 3.6.0 | Progress bars and user messaging | In DESCRIPTION |
| tibble | >= 3.2.0 | Data frame returns (dry_run tibble) | In DESCRIPTION |
| jsonlite | >= 1.8.0 | Manifest JSON read/write | In DESCRIPTION |
| rlang | >= 1.1.0 | Error handling and conditions | In DESCRIPTION |

### Supporting (For Tests)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| testthat | >= 3.0.0 | Unit testing framework | All tests |
| withr | - | Temporary directory/options management | Test isolation |
| local_mocked_bindings | (testthat) | Mock internal functions | Avoid real API/S3 calls |

**Installation:** No new dependencies required. All packages already in DESCRIPTION.

## Architecture Patterns

### Recommended Function Signature
```r
on_download_derivatives <- function(
  dataset_id,           # "ds000001"
  pipeline,             # "fmriprep"
  subjects = NULL,      # c("sub-01", "sub-02") or regex("sub-0[1-5]")
  space = NULL,         # "MNI152NLin2009cAsym" (exact or prefix match)
  suffix = NULL,        # c("bold", "T1w", "mask")
  dry_run = FALSE,      # TRUE returns tibble without downloading
  dest_dir = NULL,
  use_cache = TRUE,
  quiet = FALSE,
  verbose = FALSE,
  force = FALSE,
  backend = NULL,       # "s3", "https", or NULL (auto)
  client = NULL
)
```

### Recommended Project Structure
```
R/
├── download-derivatives.R    # NEW: on_download_derivatives() and helpers
├── download.R                # Existing: on_download() for raw data
├── download-utils.R          # Existing: .construct_download_url(), etc.
├── download-progress.R       # Existing: .download_with_progress()
├── cache-manifest.R          # MODIFY: Add type field support
├── cache-management.R        # MODIFY: Unified view with type column
├── subject-filter.R          # Existing: reuse for subjects= filtering
├── discovery-spaces.R        # Existing: .extract_space_from_filename()
├── backend-s3.R              # Existing: .download_s3(bucket=...)
└── backend-dispatch.R        # Existing: .download_with_backend(bucket=...)

tests/testthat/
├── test-download-derivatives.R  # NEW: Comprehensive mocked tests
├── test-download.R              # Existing: pattern to follow
└── helper-mocks.R               # Existing: local_temp_cache()
```

### Pattern 1: Filter Chain Pattern
**What:** Apply filters sequentially using existing helper patterns
**When to use:** Building filtered file list from full derivative listing
**Example:**
```r
# Source: Follows pattern from R/download.R lines 158-252
.build_derivative_file_list <- function(files_df, subjects, space, suffix,
                                         include_root = TRUE) {
  # Start with all files
  filtered <- files_df

  # Apply subject filter (reuse existing helper)
  if (!is.null(subjects)) {
    filtered <- .filter_files_by_subjects(filtered, subjects,
                                           include_derivatives = TRUE)
  }

  # Apply space filter
  if (!is.null(space)) {
    filtered <- .filter_files_by_space(filtered, space)
  }

  # Apply suffix filter
  if (!is.null(suffix)) {
    filtered <- .filter_files_by_suffix(filtered, suffix)
  }

  filtered
}
```

### Pattern 2: S3 Path Construction for Derivatives
**What:** Build correct S3 path for openneuro-derivatives bucket
**When to use:** Downloading from S3 backend
**Example:**
```r
# Source: R/backend-s3.R documentation
# OpenNeuroDerivatives S3 bucket structure:
# s3://openneuro-derivatives/{pipeline}/{dataset_id}-{pipeline}/

.construct_derivative_s3_path <- function(dataset_id, pipeline) {
  # Returns: "fmriprep/ds000001-fmriprep"
  paste0(pipeline, "/", dataset_id, "-", pipeline)
}

# Call .download_s3() with bucket = "openneuro-derivatives"
.download_s3(
  dataset_id = .construct_derivative_s3_path("ds000001", "fmriprep"),
  dest_dir = dest_dir,
  files = files,
  bucket = "openneuro-derivatives"
)
```

### Pattern 3: BIDS Entity Extraction
**What:** Extract BIDS entities (_space-, _suffix) from filenames using regex
**When to use:** Filtering files by space or suffix
**Example:**
```r
# Source: R/discovery-spaces.R pattern for _space- extraction
.extract_suffix_from_filename <- function(filename) {
  # BIDS suffix is the part before the extension, after the last underscore
  # sub-01_space-MNI_desc-preproc_bold.nii.gz -> "bold"
  # Match: _<suffix>.<extension> at end of filename
  basename_part <- basename(filename)
  # Remove all extensions (.nii.gz, .json, .tsv, etc.)
  no_ext <- sub("\\.[^/]+$", "", basename_part)
  # Get last underscore-separated element
  parts <- strsplit(no_ext, "_", fixed = TRUE)[[1]]
  if (length(parts) > 0) {
    return(parts[length(parts)])
  }
  NA_character_
}

.filter_files_by_space <- function(files_df, space, exact_match = TRUE) {
  # Extract space from each filename
  spaces <- vapply(files_df$full_path, function(path) {
    .extract_space_from_filename(basename(path))
  }, character(1), USE.NAMES = FALSE)

  if (exact_match) {
    keep <- spaces == space | is.na(spaces)  # NA = no space entity = include
  } else {
    keep <- startsWith(spaces, space) | is.na(spaces)
  }

  files_df[keep, ]
}
```

### Pattern 4: Manifest Type Tagging
**What:** Add `type` field to manifest entries to distinguish raw vs derivative
**When to use:** Updating manifest after derivative download
**Example:**
```r
# Source: Extend R/cache-manifest.R .update_manifest()
file_entry <- list(
  path = new_file_info$path,
  size = new_file_info$size,
  downloaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  backend = backend,
  type = "derivative"  # NEW: "raw" or "derivative"
)
```

### Pattern 5: Dry Run Return Structure
**What:** Return tibble of files that would be downloaded without downloading
**When to use:** dry_run = TRUE parameter
**Example:**
```r
# Return what would be downloaded
if (dry_run) {
  return(tibble::tibble(
    path = filtered_files$full_path,
    size = filtered_files$size,
    size_formatted = vapply(filtered_files$size, .format_bytes, character(1)),
    dest_path = fs::path(dest_dir, filtered_files$full_path)
  ))
}
```

### Anti-Patterns to Avoid
- **Duplicating download logic:** Reuse `.download_with_progress()` and `.download_with_backend()` - do not re-implement download flow
- **Separate manifest files for derivatives:** Use single manifest per dataset with type field, not separate derivative manifests
- **Hardcoded bucket names:** Always use bucket parameter, default to "openneuro-derivatives" in the derivative function
- **Modifying on_download():** Create new function; do not add complexity to existing on_download()

## Don't Hand-Roll

Problems that have existing solutions in the codebase:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Subject ID normalization | Custom parsing | `.normalize_subject_ids()` | Already handles sub- prefix |
| Subject filtering | New filter logic | `.filter_files_by_subjects()` | Tested, handles derivatives path |
| File existence check | Custom stat calls | `.validate_existing_file()` | Checks path AND size |
| Atomic downloads | Direct file write | `.download_atomic()` | Handles temp file + move |
| Progress bars | Manual loops | `.download_with_progress()` | Integrated with cli |
| Backend dispatch | Manual if/else | `.download_with_backend()` | Handles fallback chain |
| Space extraction | New regex | `.extract_space_from_filename()` | Tested, documented |
| Manifest read/write | Direct JSON | `.read_manifest()` / `.write_manifest()` | Atomic, handles corruption |
| Cache path | Manual path building | `.on_dataset_cache_path()` | Platform-appropriate |

**Key insight:** The codebase has been built incrementally with Phase 2-10, providing all download primitives. Phase 11 is primarily orchestration and filtering, not new infrastructure.

## Common Pitfalls

### Pitfall 1: Incorrect S3 Path for Derivatives
**What goes wrong:** Using raw dataset path format for derivatives bucket
**Why it happens:** Raw datasets use `s3://openneuro.org/{dataset_id}/`, but derivatives use `s3://openneuro-derivatives/{pipeline}/{dataset_id}-{pipeline}/`
**How to avoid:** Always construct derivative path with `.construct_derivative_s3_path()` helper
**Warning signs:** S3 "not found" errors when derivative exists on GitHub

### Pitfall 2: Missing Space Entity in Native Files
**What goes wrong:** Space filter removes files that are in native T1w space
**Why it happens:** Per [BIDS convention](https://bids-specification.readthedocs.io/en/stable/common-principles.html), native space files often omit the `_space-` entity entirely
**How to avoid:** When filtering by space, files without `_space-` entity should NOT be excluded (they are native space)
**Warning signs:** Filtered file count much smaller than expected

### Pitfall 3: Caching Separate from Raw Data
**What goes wrong:** Derivatives cached in different location, lost on cache clear
**Why it happens:** Natural tendency to create `{cache}/derivatives/` instead of `{cache}/{dataset}/derivatives/`
**How to avoid:** Cache structure MUST be `{cache}/{dataset}/derivatives/{pipeline}/` per CONTEXT.md decision
**Warning signs:** on_cache_clear() doesn't remove derivatives, disk space accumulates

### Pitfall 4: Filter AND vs OR Logic Confusion
**What goes wrong:** Filters applied incorrectly, returning wrong file set
**Why it happens:** Decision says "AND logic" but implementation uses OR
**How to avoid:** Per CONTEXT.md: "Subject and space filters combine with AND logic (file must match both)"
**Warning signs:** Files returned that don't match all specified filters

### Pitfall 5: Real API Calls in Tests
**What goes wrong:** Tests fail on CI, hit rate limits, are slow
**Why it happens:** Forgetting to mock dependencies
**How to avoid:** Use `local_mocked_bindings()` for all functions that make network calls. Pattern from test-download.R.
**Warning signs:** Tests pass locally but fail on CI, or tests take >10s

### Pitfall 6: Size Check Skipping Files Incorrectly
**What goes wrong:** Files re-downloaded unnecessarily or corrupt files not replaced
**Why it happens:** Only checking path exists, not checking size matches
**How to avoid:** Per CONTEXT.md: "skip if file exists AND size matches (check size, not just path)"
**Warning signs:** Downloads slower than expected, or corrupt files persist

## Code Examples

### Example 1: File Listing for Derivatives
```r
# Source: Pattern from R/discovery-spaces.R .list_derivative_files_s3()
.list_derivative_files <- function(dataset_id, pipeline, source, tag = NULL,
                                    client = NULL) {
  if (source == "embedded") {
    # Use API to list files in derivatives/{pipeline}/ tree
    .list_derivative_files_embedded(dataset_id, pipeline, tag, client)
  } else if (source == "openneuro-derivatives") {
    # Use AWS CLI to list from S3 bucket
    .list_derivative_files_s3_full(dataset_id, pipeline)
  } else {
    rlang::abort(
      c("Unknown derivative source",
        "x" = paste0("Source '", source, "' not supported")),
      class = "openneuro_validation_error"
    )
  }
}
```

### Example 2: Space Filtering with Match Mode
```r
# Recommendation: Exact match by default (Claude's discretion decision)
.filter_files_by_space <- function(files_df, space) {
  if (length(space) == 0) return(files_df)

  # Extract space from each file
  file_spaces <- vapply(files_df$full_path, function(path) {
    .extract_space_from_filename(basename(path))
  }, character(1), USE.NAMES = FALSE)

  # Keep files that:
  # 1. Have matching space
  # 2. Have no space entity (native space files)
  keep <- file_spaces %in% space | is.na(file_spaces)

  # Warn if requested space not found in any file
  available_spaces <- unique(file_spaces[!is.na(file_spaces)])
  missing <- setdiff(space, available_spaces)
  if (length(missing) > 0) {
    rlang::warn(
      c("Requested space(s) not found",
        "x" = paste0("Not found: ", paste(missing, collapse = ", ")),
        "i" = paste0("Available: ", paste(available_spaces, collapse = ", "))),
      class = "openneuro_space_warning"
    )
  }

  files_df[keep, ]
}
```

### Example 3: Suffix Extraction and Filtering
```r
# BIDS suffix is the final underscore-separated element before extension
.extract_suffix_from_filename <- function(filename) {
  # Remove directory path
  basename_part <- basename(filename)

  # Handle compound extensions (.nii.gz, .dtseries.nii, etc.)
  no_ext <- sub("\\.(nii(\\.gz)?|json|tsv|func\\.gii|surf\\.gii|dtseries\\.nii)$",
                "", basename_part, ignore.case = TRUE)

  # Get last underscore-separated part
  parts <- strsplit(no_ext, "_", fixed = TRUE)[[1]]
  if (length(parts) > 0) {
    return(parts[length(parts)])
  }
  NA_character_
}

.filter_files_by_suffix <- function(files_df, suffix) {
  if (length(suffix) == 0) return(files_df)

  file_suffixes <- vapply(files_df$full_path, .extract_suffix_from_filename,
                           character(1), USE.NAMES = FALSE)

  # Match any of the requested suffixes
  keep <- file_suffixes %in% suffix | is.na(file_suffixes)
  files_df[keep, ]
}
```

### Example 4: Cache Path for Derivatives
```r
# Per CONTEXT.md: {cache}/ds000001/derivatives/fmriprep/
.on_derivative_cache_path <- function(dataset_id, pipeline) {
  base_path <- .on_dataset_cache_path(dataset_id)
  fs::path(base_path, "derivatives", pipeline)
}
```

### Example 5: Test Mock Pattern
```r
# Source: Pattern from tests/testthat/test-download.R
test_that("on_download_derivatives filters by space", {
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives",
      version = NA_character_,
      n_subjects = NA_integer_,
      n_files = NA_integer_,
      total_size = NA_character_,
      last_modified = as.POSIXct(NA, tz = "UTC"),
      s3_url = "s3://openneuro-derivatives/fmriprep/ds000001-fmriprep/"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("bold_MNI.nii.gz", "bold_T1w.nii.gz", "mask.nii.gz"),
      full_path = c(
        "sub-01/func/sub-01_space-MNI152NLin2009cAsym_bold.nii.gz",
        "sub-01/func/sub-01_space-T1w_bold.nii.gz",
        "sub-01/anat/sub-01_desc-brain_mask.nii.gz"
      ),
      size = c(1000, 1000, 100)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id),
    .download_with_backend = function(...) {
      args <- list(...)
      files_passed <<- args$files
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  withr::local_tempdir()
  on_download_derivatives("ds000001", "fmriprep",
                          space = "MNI152NLin2009cAsym", quiet = TRUE)

  # Should only include MNI space file and mask (no space = included)
  expect_true(any(grepl("MNI152NLin2009cAsym", files_passed)))
  expect_false(any(grepl("T1w", files_passed)))
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single openneuro.org bucket | Parameterized bucket (openneuro.org + openneuro-derivatives) | Phase 10 | Enables derivative S3 downloads |
| Download all, filter later | Filter-before-download with dry_run | Phase 11 | Faster, less bandwidth |
| Separate raw/derivative caches | Unified cache with type tagging | Phase 11 | Single manifest, unified view |

**Deprecated/outdated:**
- Manual AWS S3 URL construction: Use `.download_s3()` with bucket parameter
- DataLad for OpenNeuroDerivatives: S3 is primary, DataLad org is different (OpenNeuroDerivatives not OpenNeuroDatasets)

## Open Questions

### 1. Space Match Mode Decision
**What we know:** User can filter by space. CONTEXT.md says match mode is "Claude's discretion"
**What's unclear:** Whether to use exact match or prefix match for space
**Recommendation:** **Use exact match by default.** Rationale: Space names are standardized (MNI152NLin2009cAsym, fsaverage, T1w), and prefix matching could cause unexpected results (e.g., "MNI" matching both MNI152NLin2009cAsym and MNI152NLin6Asym). Document that users should specify full space name.

### 2. Invalid Space Error Behavior
**What we know:** User requests space that doesn't exist. CONTEXT.md says behavior is "Claude's discretion"
**What's unclear:** Error vs warning when requested space not found
**Recommendation:** **Warn and continue** (consistent with invalid subjects behavior in CONTEXT.md). Return empty file list if ALL requested spaces are invalid. This matches "warn about missing, download what exists" pattern for subjects.

### 3. Full File Listing for S3 Derivatives
**What we know:** `.list_derivative_files_s3()` exists but samples only 500 items for space detection
**What's unclear:** Need full listing for download filtering
**Recommendation:** Create `.list_derivative_files_s3_full()` that paginates through entire S3 listing. Use `--recursive` without `--max-items` or implement pagination. May be slow for large derivatives.

## Sources

### Primary (HIGH confidence)
- **Codebase analysis:** R/download.R, R/cache-manifest.R, R/discovery-spaces.R, R/backend-s3.R
- **Phase 10 PLAN files:** .planning/phases/10-spaces-and-s3-backend/10-01-PLAN.md, 10-02-PLAN.md
- **CONTEXT.md decisions:** .planning/phases/11-download-integration/11-CONTEXT.md
- **Test patterns:** tests/testthat/test-download.R

### Secondary (MEDIUM confidence)
- [BIDS Specification - Common Principles](https://bids-specification.readthedocs.io/en/stable/common-principles.html) - BIDS filename conventions
- [fMRIPrep Outputs Documentation](https://fmriprep.org/en/stable/outputs.html) - Derivative filename patterns

### Tertiary (LOW confidence)
- WebSearch for dry_run patterns - No specific R package examples found; implemented based on tibble return pattern

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages already in DESCRIPTION, no new dependencies
- Architecture patterns: HIGH - Direct extensions of existing patterns in codebase
- Filter implementation: HIGH - BIDS regex patterns verified in Phase 10 research
- Manifest extension: MEDIUM - Type field is new but follows existing schema pattern
- S3 full listing: MEDIUM - May need pagination for large derivatives

**Research date:** 2026-01-23
**Valid until:** 60 days (infrastructure stable, no external API changes expected)
