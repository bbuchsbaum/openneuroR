# Download Derivative Dataset

Downloads fMRIPrep, MRIQC, or other derivative outputs from OpenNeuro
datasets. Supports filtering by subject, output space, and BIDS suffix.
Uses S3 backend (openneuro-derivatives bucket) with HTTPS fallback.

## Usage

``` r
on_download_derivatives(
  dataset_id,
  pipeline,
  subjects = NULL,
  space = NULL,
  suffix = NULL,
  dry_run = FALSE,
  dest_dir = NULL,
  use_cache = TRUE,
  quiet = FALSE,
  verbose = FALSE,
  force = FALSE,
  backend = NULL,
  client = NULL
)
```

## Arguments

- dataset_id:

  Dataset identifier (e.g., "ds000001").

- pipeline:

  Pipeline name (e.g., "fmriprep", "mriqc").

- subjects:

  Character vector of subject IDs (e.g., `c("sub-01", "sub-02")`) or a
  regex pattern wrapped in
  [`regex()`](https://bbuchsbaum.github.io/openneuroR/reference/regex.md)
  (e.g., `regex("sub-0[1-5]")`). Subject IDs can be specified with or
  without the "sub-" prefix. If `NULL` (default), downloads all
  subjects.

- space:

  Character string: output space to filter by (e.g.,
  "MNI152NLin2009cAsym", "fsaverage", "T1w"). If `NULL` (default),
  downloads all spaces. Matching is exact (specify full space name).
  Files without a `_space-` entity (native space) are always included.

- suffix:

  Character vector of BIDS suffixes to filter by (e.g.,
  `c("bold", "T1w", "mask")`). If `NULL` (default), downloads all
  suffixes. Files without a clear suffix (metadata files) are always
  included.

- dry_run:

  If `TRUE`, returns a tibble of files that would be downloaded without
  actually downloading them. Default is `FALSE`.

- dest_dir:

  Destination directory. If `NULL` (default) and `use_cache` is `TRUE`,
  downloads to BIDS-compliant cache location:
  `{cache}/{dataset_id}/derivatives/{pipeline}/`.

- use_cache:

  If `TRUE` (default) and `dest_dir` is `NULL`, downloads to
  CRAN-compliant cache location. Set `FALSE` to use current working
  directory.

- quiet:

  If `TRUE`, suppress all progress output. Default `FALSE`.

- verbose:

  If `TRUE`, show per-file progress in addition to overall progress.
  Default `FALSE`.

- force:

  If `TRUE`, re-download files even if they exist with correct size.
  Default `FALSE`.

- backend:

  Backend to use for downloading: "s3" or "https". If `NULL` (default),
  auto-selects S3 for openneuro-derivatives bucket.

- client:

  An `openneuro_client` object. If `NULL`, creates default client.

## Value

If `dry_run = TRUE`, returns a tibble with columns:

- path:

  Relative path within derivative

- size:

  File size in bytes

- size_formatted:

  Human-readable size (e.g., "1.2 GB")

- dest_path:

  Full destination path where file would be downloaded

If `dry_run = FALSE`, invisibly returns a list with:

- downloaded:

  Number of files downloaded

- skipped:

  Number of files skipped (already cached)

- failed:

  Character vector of failed file names

- total_bytes:

  Total bytes downloaded

- dest_dir:

  Path to destination directory

- backend:

  Backend used for download

## Details

### Filter Logic

All filters combine with AND logic - a file must match ALL specified
filters to be included. For example,
`subjects = "sub-01", space = "MNI152NLin2009cAsym"` downloads only
sub-01's MNI-space files.

### Cache Structure

Derivatives are cached in BIDS-compliant structure:
`{cache_root}/{dataset_id}/derivatives/{pipeline}/`

This keeps derivatives organized alongside raw data while maintaining
clear separation by pipeline.

### Backend Selection

S3 backend is preferred for the openneuro-derivatives bucket as it
provides fast parallel sync. HTTPS fallback is used if S3 is
unavailable.

### Space Matching

Space matching is exact - specify the full space name (e.g.,
"MNI152NLin2009cAsym", not "MNI"). Files without a `_space-` entity
(native/T1w space per BIDS convention) are always included when
filtering by space.

## See also

[`on_derivatives()`](https://bbuchsbaum.github.io/openneuroR/reference/on_derivatives.md)
to discover available derivatives,
[`on_spaces()`](https://bbuchsbaum.github.io/openneuroR/reference/on_spaces.md)
to discover available output spaces,
[`on_download()`](https://bbuchsbaum.github.io/openneuroR/reference/on_download.md)
to download raw datasets

## Examples

``` r
if (FALSE) { # \dontrun{
# Download all fMRIPrep derivatives for a dataset
on_download_derivatives("ds000001", "fmriprep")

# Download specific subjects
on_download_derivatives("ds000001", "fmriprep",
                        subjects = c("sub-01", "sub-02"))

# Download only MNI-space outputs
on_download_derivatives("ds000001", "fmriprep",
                        space = "MNI152NLin2009cAsym")

# Download only BOLD and mask files
on_download_derivatives("ds000001", "fmriprep",
                        suffix = c("bold", "mask"))

# Preview files without downloading
files <- on_download_derivatives("ds000001", "fmriprep",
                                  subjects = "sub-01",
                                  space = "MNI152NLin2009cAsym",
                                  dry_run = TRUE)
print(files)

# Combine all filters
on_download_derivatives("ds000001", "fmriprep",
                        subjects = regex("sub-0[1-5]"),
                        space = "MNI152NLin2009cAsym",
                        suffix = c("bold", "T1w"))
} # }
```
