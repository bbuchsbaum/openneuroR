# Phase 10: Spaces and S3 Backend - Research

**Researched:** 2026-01-23
**Domain:** fMRIPrep/BIDS output space discovery and S3 derivatives bucket access
**Confidence:** HIGH

## Summary

This phase implements two related features: (1) an `on_spaces()` function that extracts available output spaces from derivative datasets by parsing fMRIPrep-style BIDS filenames, and (2) extending the S3 backend to support the `s3://openneuro-derivatives/` bucket for downloading pre-computed derivatives.

The space detection approach relies on BIDS filename conventions where spaces are encoded using the `space-<label>` entity (e.g., `sub-01_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz`). The key spaces to detect include volumetric spaces (MNI152NLin2009cAsym, MNI152NLin6Asym, T1w) and surface spaces (fsaverage, fsaverage5, fsaverage6, fsnative, fsLR).

For S3 access, the openneuro-derivatives bucket uses the path pattern `s3://openneuro-derivatives/{pipeline}/{dataset_id}-{pipeline}/`. Unlike the main openneuro.org bucket, the derivatives bucket has had intermittent access issues, so the implementation should handle failures gracefully and fall back to DataLad or HTTPS alternatives.

**Primary recommendation:** Extract spaces by parsing filenames with regex `_space-([A-Za-z0-9]+)` from the derivative file listing. For S3, parameterize the bucket name in `.download_s3()` and probe accessibility lazily on first use.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | >= 1.2.1 | HTTP requests for HTTPS fallback | Already in package |
| tibble | >= 3.2.0 | Output format | Already in package |
| rlang | >= 1.1.0 | Error handling | Already in package |
| cli | >= 3.6.0 | User messaging | Already in package |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| processx | >= 3.8.0 | AWS CLI execution | Already in package for S3 backend |
| fs | >= 1.6.0 | Path manipulation | Already in package |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Filename regex parsing | BIDS layout library | R lacks mature BIDS parser; regex is simple and sufficient |
| AWS CLI | paws (R AWS SDK) | AWS CLI already supported; paws adds large dependency |

**Installation:**
```bash
# No new packages needed - all dependencies already in DESCRIPTION
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── discovery.R           # Existing: on_derivatives()
├── discovery-spaces.R    # NEW: on_spaces() and space detection helpers
├── backend-s3.R          # MODIFY: Add bucket parameter, derivatives bucket support
├── backend-dispatch.R    # MODIFY: Add bucket-aware fallback chain
```

### Pattern 1: Space Entity Extraction via Regex
**What:** Parse BIDS `_space-<label>` entity from filenames to detect available spaces
**When to use:** Extracting spaces from derivative file listings
**Example:**
```r
# Source: BIDS Specification - Entities Appendix
# https://bids-specification.readthedocs.io/en/stable/appendices/entities.html

.extract_space_from_filename <- function(filename) {
  # Match _space-<label>_ or _space-<label>. patterns
  # Label can contain alphanumeric characters
  pattern <- "_space-([A-Za-z0-9]+)"
  match <- regmatches(filename, regexec(pattern, filename))[[1]]
  if (length(match) >= 2) {
    return(match[2])  # Return the captured group (space label)
  }
  NA_character_
}

# Extract unique spaces from a list of filenames
.extract_spaces_from_files <- function(filenames) {
  spaces <- vapply(filenames, .extract_space_from_filename, character(1))
  spaces <- unique(spaces[!is.na(spaces)])
  sort(spaces)  # Alphabetically sorted per CONTEXT.md
}
```

### Pattern 2: Lazy Bucket Accessibility Probe
**What:** Check if S3 bucket is accessible only when first needed, cache result for session
**When to use:** First access to derivatives bucket
**Example:**
```r
# Lazy probe pattern using closure cache (matches existing discovery-cache.R)

.probe_s3_bucket <- function(bucket, refresh = FALSE) {
  cache_key <- paste0("s3_bucket_probe_", bucket)

  if (!refresh && .discovery_cache$has(cache_key)) {
    return(.discovery_cache$get(cache_key))
  }

  # Try to list a single object to verify access
  aws_path <- .find_aws_cli()
  if (!nzchar(aws_path)) {
    .discovery_cache$set(cache_key, FALSE)
    return(FALSE)
  }

  # Use ls with max-items=1 to minimize request
  result <- processx::run(
    command = aws_path,
    args = c("s3", "ls", "--no-sign-request", paste0("s3://", bucket, "/"),
             "--max-items", "1"),
    error_on_status = FALSE,
    timeout = 10
  )

  accessible <- result$status == 0
  .discovery_cache$set(cache_key, accessible)
  accessible
}
```

### Pattern 3: Parameterized S3 Backend
**What:** Extend `.download_s3()` to accept bucket parameter
**When to use:** Downloading from openneuro-derivatives vs openneuro.org bucket
**Example:**
```r
# Modified .download_s3 signature
.download_s3 <- function(dataset_id, dest_dir, files = NULL, quiet = FALSE,
                          timeout = 1800, bucket = "openneuro.org") {
  # Construct S3 URI with parameterized bucket
  s3_uri <- paste0("s3://", bucket, "/", dataset_id)

  # Rest of implementation unchanged...
}

# For derivatives, construct the full path:
# s3://openneuro-derivatives/fmriprep/ds000102-fmriprep/
```

### Pattern 4: Input Interface - Derivative Row Pattern
**What:** Accept derivative tibble row as input to `on_spaces()`
**When to use:** When user chains from `on_derivatives()` result
**Example:**
```r
# Consistent with package API patterns (see on_files, on_dataset)
on_spaces <- function(derivative, refresh = FALSE, client = NULL) {
  # Accept a single row from on_derivatives() tibble
  # OR dataset_id + pipeline as fallback

  if (is.data.frame(derivative) && nrow(derivative) == 1) {
    dataset_id <- derivative$dataset_id
    pipeline <- derivative$pipeline
    source <- derivative$source
  } else if (is.character(derivative)) {
    # Fallback: assume it's dataset_id, require pipeline arg
    rlang::abort(
      c("Invalid input",
        "x" = "Pass a single row from on_derivatives() or specify dataset_id and pipeline"),
      class = "openneuro_validation_error"
    )
  }
  # ...
}
```

### Anti-Patterns to Avoid
- **Parsing all derivative files at once:** Space detection only needs representative sample, not full file tree
- **Hardcoding bucket URLs:** Use parameterized approach for flexibility
- **Blocking silently on bucket probe:** Always report what's happening via verbose logging
- **Assuming T1w means space-T1w:** Files in native space often omit the space entity entirely

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| File listing for space detection | Custom S3 calls | `on_files()` | Already handles pagination, auth, caching |
| Derivative discovery | Manual GitHub scraping | `on_derivatives()` | Already implemented in Phase 9 |
| Session caching | New cache system | `.discovery_cache` | Closure-based cache already in discovery-cache.R |
| AWS CLI detection | New detection logic | `.find_aws_cli()` | Already in backend-detect.R |
| Size formatting | Custom formatting | `.format_bytes()` | Already in download-progress.R |
| Empty result tibble | Manual tibble() | `.empty_*_tibble()` | Pattern established in utils-response.R |

**Key insight:** The existing codebase has utilities for file listing, caching, AWS detection, and formatting. This phase should compose existing functions rather than duplicating logic.

## Common Pitfalls

### Pitfall 1: Files Without Space Entity
**What goes wrong:** Some derivative files don't include `_space-` in filename (native T1w space omits it)
**Why it happens:** BIDS convention: "derivatives in the original T1w space omit the space- keyword"
**How to avoid:**
- Only parse files that contain `_space-`
- Do NOT infer "T1w" space from files lacking space entity
- Return only explicitly labeled spaces
**Warning signs:** Returning "T1w" for every derivative

### Pitfall 2: OpenNeuro-Derivatives Bucket Access Denied
**What goes wrong:** `aws s3 ls s3://openneuro-derivatives/` returns AccessDenied
**Why it happens:** Bucket permissions have been inconsistent; ListObjects may be restricted even when GetObject works
**How to avoid:**
- Probe with a known file path rather than bucket root
- Use `aws s3 ls s3://openneuro-derivatives/fmriprep/ds000102-fmriprep/` instead of root
- Gracefully fall back to DataLad when S3 fails
**Warning signs:** Works for some datasets but not listing the full bucket

### Pitfall 3: Surface Space vs Volumetric Space Confusion
**What goes wrong:** Treating fsaverage/fsnative same as MNI spaces
**Why it happens:** Surface and volumetric spaces have different output formats (GIFTI vs NIfTI)
**How to avoid:**
- Return all detected spaces without categorization (per CONTEXT.md)
- Let user decide how to handle surface vs volumetric
- Document in function help that both types may be returned
**Warning signs:** User confusion about incompatible spaces

### Pitfall 4: Embedded vs OpenNeuroDerivatives Path Differences
**What goes wrong:** Code assumes same file structure for both derivative sources
**Why it happens:** Embedded derivatives are in `derivatives/{pipeline}/` while OpenNeuroDerivatives are in separate repos
**How to avoid:**
- Use different code paths as allowed by CONTEXT.md
- For embedded: use `on_files()` with tree navigation
- For OpenNeuroDerivatives: construct S3 path from repo name pattern
**Warning signs:** 404 errors for file listings

### Pitfall 5: Missing Verbose Logging in Fallback Chain
**What goes wrong:** User doesn't know why download is slow or failing
**Why it happens:** Silently falling back without notification
**How to avoid:**
- Log "S3 failed, trying DataLad..." per CONTEXT.md requirement
- Include reason for failure if available (timeout, access denied, etc.)
**Warning signs:** User reports "it just hangs" without knowing what's happening

## Code Examples

Verified patterns from official sources and existing codebase:

### Space Regex Pattern
```r
# Source: BIDS Specification and fMRIPrep documentation
# https://bids-specification.readthedocs.io/en/stable/appendices/entities.html
# https://fmriprep.org/en/stable/outputs.html

# Known fMRIPrep output spaces
FMRIPREP_SPACES <- c(
  # Volumetric
  "MNI152NLin2009cAsym",  # Default fMRIPrep standard space
  "MNI152NLin6Asym",
  "MNI152NLin6Sym",
  "MNI152Lin",
  "MNIPediatricAsym",
  "OASIS30ANTs",
  "T1w",                   # Native anatomical space (sometimes explicit)


  # Surface
  "fsaverage",             # FreeSurfer standard
  "fsaverage6",            # 41k vertices
  "fsaverage5",            # 10k vertices (default)
  "fsnative",              # Subject-specific mesh
  "fsLR"                   # HCP standard
)

# Regex for extracting space from BIDS filename
SPACE_REGEX <- "_space-([A-Za-z0-9]+)(?:_|$)"
```

### S3 Derivatives Path Construction
```r
# Source: OpenNeuroDerivatives GitHub documentation
# https://github.com/OpenNeuroDerivatives

.construct_derivatives_s3_path <- function(dataset_id, pipeline) {
  # Pattern: s3://openneuro-derivatives/{pipeline}/{dataset_id}-{pipeline}/
  paste0("s3://openneuro-derivatives/", pipeline, "/",
         dataset_id, "-", pipeline, "/")
}

# Example: ds000102 fmriprep
# -> s3://openneuro-derivatives/fmriprep/ds000102-fmriprep/
```

### Fallback Chain with Verbose Logging
```r
# Pattern from CONTEXT.md: S3 -> DataLad -> HTTPS with logging

.download_derivatives_with_fallback <- function(deriv_row, dest_dir, quiet = FALSE) {
  pipeline <- deriv_row$pipeline
  dataset_id <- deriv_row$dataset_id
  source <- deriv_row$source

  # Try S3 first for OpenNeuroDerivatives
  if (source == "openneuro-derivatives") {
    s3_path <- .construct_derivatives_s3_path(dataset_id, pipeline)

    tryCatch({
      if (!quiet) cli::cli_alert_info("Trying S3 backend...")
      result <- .download_s3(
        dataset_id = paste0(pipeline, "/", dataset_id, "-", pipeline),
        dest_dir = dest_dir,
        bucket = "openneuro-derivatives"
      )
      return(result)
    }, error = function(e) {
      if (!quiet) cli::cli_alert_warning("S3 failed, trying DataLad...")
    })

    # DataLad fallback
    tryCatch({
      if (!quiet) cli::cli_alert_info("Trying DataLad backend...")
      # Clone from OpenNeuroDerivatives GitHub
      repo_url <- paste0("https://github.com/OpenNeuroDerivatives/",
                         dataset_id, "-", pipeline, ".git")
      result <- .download_datalad_from_url(repo_url, dest_dir)
      return(result)
    }, error = function(e) {
      if (!quiet) cli::cli_alert_warning("DataLad failed, trying HTTPS...")
    })

    # HTTPS would require individual file URLs - may not be practical
    rlang::abort(
      c("All download methods failed",
        "x" = "Could not download derivatives via S3 or DataLad",
        "i" = "Check network connectivity and try again"),
      class = "openneuro_download_error"
    )
  }

  # For embedded derivatives, use standard download path
  # ...
}
```

### Empty Spaces Result
```r
# Following pattern from utils-response.R

.empty_spaces_vector <- function() {
  character(0)  # Simple character vector, alphabetically sorted (empty)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual space discovery | BIDS `_space-` entity in filenames | BIDS 1.4.0+ | Standardized, parseable |
| Single OpenNeuro bucket | Separate derivatives bucket | 2022 | `s3://openneuro-derivatives/` for fMRIPrep/MRIQC |
| Always use DataLad | S3 as primary, DataLad fallback | 2023 | Faster downloads without git-annex |

**Deprecated/outdated:**
- Assuming all spaces are MNI-based (surface spaces like fsLR now common)
- Expecting `_space-T1w` in native space files (BIDS omits it)

## Open Questions

Things that couldn't be fully resolved:

1. **OpenNeuro-Derivatives bucket reliability**
   - What we know: Users have reported AccessDenied errors sporadically
   - What's unclear: Whether bucket is fully public or requires specific access patterns
   - Recommendation: Probe a known file path (not bucket root), implement robust fallback to DataLad

2. **Embedded derivatives file tree depth**
   - What we know: Spaces may appear at various depths (anat/, func/, subject-level)
   - What's unclear: How deep to traverse for representative sample
   - Recommendation: Sample first few subjects, first few files per modality (anat, func) - don't need exhaustive listing

3. **Distinguishing anat-only vs func-only spaces**
   - What we know: Some spaces only appear in anat (MNI T1w), others in func (fsLR for CIFTI)
   - What's unclear: Whether users need this distinction
   - Recommendation: Per CONTEXT.md "Claude's discretion" - return unified list for simplicity, document that some spaces may only have certain modalities

## Sources

### Primary (HIGH confidence)
- fMRIPrep Outputs Documentation: https://fmriprep.org/en/stable/outputs.html - Space entity in filenames
- fMRIPrep Spaces Documentation: https://fmriprep.org/en/stable/spaces.html - Valid space identifiers
- BIDS Specification Entities: https://bids-specification.readthedocs.io/en/stable/appendices/entities.html - Space entity format
- BIDS Derivatives Imaging: https://bids-specification.readthedocs.io/en/stable/derivatives/imaging.html - Space usage in derivatives
- OpenNeuroDerivatives GitHub: https://github.com/OpenNeuroDerivatives - Repo naming, S3 path structure

### Secondary (MEDIUM confidence)
- Neurostars Discussion on Derivatives Bucket: https://neurostars.org/t/openneuro-derivatives-bucket/26531 - Access issues, path structure
- Neurostars S3 Download Issues: https://neurostars.org/t/fail-to-download-ds003007-derivatives-from-openneuro-using-aws-or-datalad/25966 - Workarounds

### Tertiary (LOW confidence)
- None - all critical claims verified with primary/secondary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in package, no new dependencies
- Space detection: HIGH - BIDS specification is well-documented, regex pattern verified
- S3 derivatives bucket: MEDIUM - Access patterns reported inconsistent, requires runtime probing
- Architecture: HIGH - Follows established patterns from Phase 9 and existing codebase

**Research date:** 2026-01-23
**Valid until:** 2026-03-23 (60 days - BIDS spec stable, S3 access may need monitoring)
