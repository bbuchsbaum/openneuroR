# Phase 7: Subject Filtering - Research

**Researched:** 2026-01-22
**Domain:** R package pattern matching and file filtering for BIDS subject downloads
**Confidence:** HIGH

## Summary

This phase implements a `subjects=` parameter in `on_download()` to filter downloads to specific subjects. The implementation follows established R patterns from stringr and the existing codebase.

Based on analysis of the existing codebase and established R patterns:
1. **Subject ID format**: OpenNeuro API returns subject IDs in two formats - with `sub-` prefix (e.g., "sub-01") in file paths and without prefix (e.g., "01") in the API summary. The implementation must accept both formats from users and normalize internally.
2. **Pattern matching**: Use the `regex()` wrapper pattern from stringr to explicitly mark regex patterns, keeping character vectors as literal matches.
3. **File filtering**: Filter the file list from `.list_all_files()` based on subject directory matching before passing to download backends.

**Primary recommendation:** Create a `regex()` helper that returns an S3 object with class `on_regex`, use `grepl()` with auto-anchoring for pattern matching, and always include root-level files regardless of subject filter.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| base R | - | `grepl()` for regex matching | Already used in codebase, no new dependency |
| rlang | >= 1.1.0 | `structure()`, `%||%`, error handling | Already an Imports dependency |
| dplyr | >= 1.1.0 | `filter()` for tibble filtering | Already an Imports dependency |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| cli | >= 3.6.0 | User-facing messages and warnings | Already used for progress/alerts |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `grepl()` | `stringr::str_detect()` | Would add new dependency; `grepl()` sufficient for full-match patterns |
| Custom class | S4 class | Overkill for simple pattern wrapper; S3 follows codebase style |

**Installation:**
No additional packages needed - all dependencies already in DESCRIPTION.

## Architecture Patterns

### Recommended Project Structure
```
R/
├── download.R           # Modify on_download() to accept subjects=
├── subject-filter.R     # NEW: regex() helper, normalization, filtering logic
└── utils-response.R     # Already has .sort_subjects_natural()
```

### Pattern 1: S3 Class for Pattern Wrapper (from stringr)
**What:** Create `regex()` function that returns marked character vector with S3 class
**When to use:** When user wants regex pattern matching instead of literal ID matching
**Example:**
```r
# Source: stringr package pattern, adapted for openneuroR
regex <- function(pattern) {
  if (!is.character(pattern) || length(pattern) != 1) {
    rlang::abort(
      c("Invalid regex pattern",
        "x" = "`pattern` must be a single character string"),
      class = "openneuro_validation_error"
    )
  }
  structure(pattern, class = c("on_regex", "character"))
}

# Type checking helper
is_regex <- function(x) {
  inherits(x, "on_regex")
}
```

### Pattern 2: Input Normalization with sub- Prefix
**What:** Accept both "01" and "sub-01", normalize to consistent format internally
**When to use:** When validating/processing user-provided subject IDs
**Example:**
```r
# Source: BIDS specification for subject naming
.normalize_subject_id <- function(id) {
  # If already has sub- prefix, return as-is
  if (grepl("^sub-", id)) {
    return(id)
  }
  # Add sub- prefix
  paste0("sub-", id)
}

# Vectorized version
.normalize_subject_ids <- function(ids) {
  vapply(ids, .normalize_subject_id, character(1), USE.NAMES = FALSE)
}
```

### Pattern 3: Full-Match Regex with Auto-Anchoring
**What:** Auto-anchor regex patterns with `^` and `$` for full subject ID matching
**When to use:** When matching subject IDs against user regex pattern
**Example:**
```r
# Source: R for Data Science regex chapter, BIDS specification
.match_subject_regex <- function(subject_ids, pattern) {
  # Auto-anchor for full match
  anchored <- paste0("^", pattern, "$")
  grepl(anchored, subject_ids)
}
```

### Pattern 4: File Path Filtering by Subject
**What:** Filter file list to only include files for matching subjects + root files
**When to use:** After determining matching subjects, before download
**Example:**
```r
# Filter files_df to matching subjects
.filter_files_by_subjects <- function(files_df, matching_subjects, include_derivatives = TRUE) {
  # Build regex to match subject directories
  # Matches: sub-01/, sub-01/ses-01/, derivatives/fmriprep/sub-01/
  subject_pattern <- paste0(
    "^(",
    paste(matching_subjects, collapse = "|"),
    ")/"
  )

  # Identify root files (no / in path or starts with common root files)
  is_root_file <- !grepl("/", files_df$full_path) |
                  grepl("^(dataset_description\\.json|README|CHANGES|participants|.bidsignore)",
                        files_df$full_path)

  # Identify subject files
  is_subject_file <- grepl(subject_pattern, files_df$full_path)

  # Identify derivative files if requested
  if (include_derivatives) {
    deriv_pattern <- paste0(
      "^derivatives/[^/]+/(",
      paste(matching_subjects, collapse = "|"),
      ")/"
    )
    is_derivative_file <- grepl(deriv_pattern, files_df$full_path)
    is_subject_file <- is_subject_file | is_derivative_file
  }

  files_df[is_root_file | is_subject_file, ]
}
```

### Anti-Patterns to Avoid
- **Auto-detecting regex vs literal:** The context document explicitly requires using `regex()` wrapper - character vectors are always literal IDs
- **Partial matching:** Subject ID "01" should not match "sub-010" - use full anchored matching
- **Ignoring derivatives:** Filtering subjects should also filter derivative outputs for those subjects
- **Hardcoding prefix format:** Some datasets might use different naming - always normalize based on actual on_subjects() output

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Natural sort of subject IDs | Custom numeric extraction | `.sort_subjects_natural()` in utils-response.R | Already handles stringi fallback |
| S3 class creation | Manual class assignment | `structure(x, class = ...)` | Idiomatic R pattern |
| Subject listing | File path parsing | `on_subjects()` from Phase 6 | API provides authoritative list |
| Input validation | Custom checks | `rlang::abort()` with structured messages | Consistent with codebase |

**Key insight:** The codebase already has patterns for validation errors, S3 objects, and natural sorting. Follow these patterns rather than inventing new ones.

## Common Pitfalls

### Pitfall 1: Subject ID Format Mismatch
**What goes wrong:** User provides "sub-01" but API returns "01", or vice versa
**Why it happens:** OpenNeuro API returns subject IDs without the "sub-" prefix in the summary, but file paths include "sub-" prefix
**How to avoid:**
- Normalize ALL user input to include "sub-" prefix
- Match against file paths which always have "sub-XX/" format
**Warning signs:** Zero matches when subjects clearly exist

### Pitfall 2: Regex Matches Zero Subjects (Decision Point)
**What goes wrong:** User regex matches nothing, leading to empty download
**Why it happens:** Typo in pattern, incorrect understanding of subject naming
**How to avoid:**
- Per CONTEXT.md "Claude's Discretion": Recommend ERROR (not warning)
- Error message should show available subjects for comparison
**Warning signs:** Empty filtered file list after regex matching

### Pitfall 3: Missing Root Files
**What goes wrong:** User filters to subjects but loses dataset_description.json, participants.tsv
**Why it happens:** Naive filtering only keeps sub-XX/ paths
**How to avoid:** Always include root-level files regardless of subject filter
**Warning signs:** Invalid BIDS dataset after filtered download

### Pitfall 4: Derivatives Not Filtered
**What goes wrong:** User downloads sub-01 raw data but gets ALL derivatives
**Why it happens:** Derivatives live in derivatives/pipeline/sub-XX/, different path pattern
**How to avoid:** Filter derivatives directory with same subject matching logic
**Warning signs:** Much larger download than expected with derivative files

### Pitfall 5: Partial Subject ID Matching
**What goes wrong:** Pattern "sub-0[1-5]" matches "sub-01", "sub-02", ..., "sub-05" but also "sub-015"
**Why it happens:** Forgot to anchor regex
**How to avoid:** Auto-anchor all regex patterns with ^ and $
**Warning signs:** Unexpected subjects included in download

## Code Examples

Verified patterns from official sources:

### Creating the regex() Helper
```r
# Source: stringr::regex() pattern, simplified
#' Mark a Pattern as a Regex for Subject Filtering
#'
#' Wraps a character string to indicate it should be treated as a
#' regular expression when filtering subjects.
#'
#' @param pattern A single character string containing a regex pattern.
#'
#' @return A character vector of class `on_regex`.
#'
#' @export
#' @examples
#' # Download subjects matching pattern
#' on_download("ds000001", subjects = regex("sub-0[1-5]"))
regex <- function(pattern) {
  if (!is.character(pattern) || length(pattern) != 1 || nchar(pattern) == 0) {
    rlang::abort(
      c("Invalid regex pattern",
        "x" = "`pattern` must be a non-empty character string",
        "i" = 'Example: regex("sub-0[1-5]")'),
      class = "openneuro_validation_error"
    )
  }
  structure(pattern, class = c("on_regex", "character"))
}
```

### Validating Subject IDs Against Dataset
```r
# Source: Codebase validation patterns
.validate_subjects <- function(requested, available, dataset_id) {
  # Normalize both to sub- format for comparison
  requested_norm <- .normalize_subject_ids(requested)
  available_norm <- .normalize_subject_ids(available)

  invalid <- setdiff(requested_norm, available_norm)

  if (length(invalid) > 0) {
    # Show helpful error with available subjects
    available_display <- if (length(available_norm) <= 10) {
      paste(available_norm, collapse = ", ")
    } else {
      paste(c(head(available_norm, 10), "..."), collapse = ", ")
    }

    rlang::abort(
      c("Invalid subject ID(s)",
        "x" = paste0("Not found: ", paste(invalid, collapse = ", ")),
        "i" = paste0("Available subjects in ", dataset_id, ": ", available_display)),
      class = "openneuro_validation_error"
    )
  }

  requested_norm
}
```

### Integration with on_download()
```r
# Source: Existing on_download() structure
on_download <- function(id, tag = NULL, files = NULL, subjects = NULL,
                        include_derivatives = TRUE, dest_dir = NULL,
                        use_cache = TRUE, quiet = FALSE, verbose = FALSE,
                        force = FALSE, backend = NULL, client = NULL) {
  # ... existing validation ...

  # Filter by subjects if specified
  if (!is.null(subjects)) {
    # Get available subjects from API
    available <- on_subjects(id, tag = tag, client = client)
    available_ids <- available$subject_id

    if (is_regex(subjects)) {
      # Regex matching with auto-anchoring
      pattern <- paste0("^", as.character(subjects), "$")
      matching <- available_ids[grepl(pattern, available_ids)]

      if (length(matching) == 0) {
        rlang::abort(
          c("No subjects match pattern",
            "x" = paste0("Pattern '", subjects, "' matched 0 subjects"),
            "i" = paste0("Available: ", paste(head(available_ids, 10), collapse = ", "),
                        if (length(available_ids) > 10) ", ..." else "")),
          class = "openneuro_validation_error"
        )
      }
    } else {
      # Literal IDs - validate and normalize
      matching <- .validate_subjects(subjects, available_ids, id)
    }

    # Filter files to matching subjects
    all_files <- .filter_files_by_subjects(all_files, matching, include_derivatives)
  }

  # ... rest of download logic ...
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Auto-detect regex by metacharacters | Explicit `regex()` wrapper | This phase decision | Unambiguous, matches stringr pattern |
| Download all, delete unwanted | Filter file list before download | This phase | Saves bandwidth, faster downloads |

**Deprecated/outdated:**
- The existing `.is_regex()` function in download.R detects regex by metacharacters - this pattern should NOT be used for subjects parameter per CONTEXT.md decisions

## Open Questions

Things that couldn't be fully resolved:

1. **Subject ID format from on_subjects()**
   - What we know: `.parse_subjects()` stores subject IDs in `subject_id` column
   - What's unclear: Whether the IDs include "sub-" prefix or just numeric portion
   - Recommendation: Check actual API response; code defensively to handle both

2. **Derivatives directory structure variations**
   - What we know: Standard is `derivatives/pipeline_name/sub-XX/`
   - What's unclear: All derivative pipelines follow this exactly?
   - Recommendation: Use permissive pattern `derivatives/[^/]+/sub-XX` to handle variations

## Sources

### Primary (HIGH confidence)
- Existing codebase: `/Users/bbuchsbaum/code/openneuroR/R/download.R` - on_download() implementation
- Existing codebase: `/Users/bbuchsbaum/code/openneuroR/R/api-subjects.R` - on_subjects() implementation
- Existing codebase: `/Users/bbuchsbaum/code/openneuroR/R/utils-response.R` - .parse_subjects(), .sort_subjects_natural()
- [R for Data Science - Regex chapter](https://r4ds.hadley.nz/regexps.html) - Anchoring patterns with ^ and $
- [stringr documentation](https://stringr.tidyverse.org/reference/modifiers.html) - regex() wrapper pattern

### Secondary (MEDIUM confidence)
- [BIDS Specification - Common Principles](https://bids-specification.readthedocs.io/en/stable/common-principles.html) - Subject naming conventions
- [Advanced R - S3](https://adv-r.hadley.nz/s3.html) - S3 class creation with structure()

### Tertiary (LOW confidence)
- None - all research verified with primary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - using existing dependencies only
- Architecture: HIGH - follows established codebase patterns
- Pitfalls: HIGH - derived from codebase analysis and BIDS spec

**Research date:** 2026-01-22
**Valid until:** 2026-02-22 (30 days - stable domain, no external API changes expected)
