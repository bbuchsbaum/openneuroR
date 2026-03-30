# Download OpenNeuro Dataset

Downloads files from an OpenNeuro dataset to local disk. Supports
downloading the full dataset, specific files, files matching a regex
pattern, or specific subjects.

## Usage

``` r
on_download(
  id,
  tag = NULL,
  files = NULL,
  subjects = NULL,
  include_derivatives = TRUE,
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

- id:

  Dataset identifier (e.g., "ds000001").

- tag:

  Snapshot version tag. If NULL (default), uses latest snapshot.

- files:

  Character vector of specific files to download, or a single regex
  pattern (detected by presence of regex metacharacters). If NULL
  (default), downloads all files.

- subjects:

  Character vector of subject IDs (e.g., `c("sub-01", "sub-02")`) or a
  regex pattern wrapped in
  [`regex()`](https://bbuchsbaum.github.io/openneuroR/reference/regex.md)
  (e.g., `regex("sub-0[1-5]")`). Subject IDs can be specified with or
  without the "sub-" prefix. If NULL (default), downloads all subjects.

- include_derivatives:

  If TRUE (default) and `subjects` is specified, also include derivative
  outputs for matching subjects from the `derivatives/` directory.

- dest_dir:

  Destination directory. If NULL (default) and `use_cache` is TRUE,
  downloads to cache location. If NULL and `use_cache` is FALSE, creates
  `./dataset_id/` in the current working directory.

- use_cache:

  If TRUE (default) and dest_dir is NULL, downloads to CRAN-compliant
  cache location. Set FALSE to use current working directory. Ignored
  when dest_dir is explicitly provided.

- quiet:

  If TRUE, suppress all progress output. Default FALSE.

- verbose:

  If TRUE, show per-file progress in addition to overall progress.
  Default FALSE.

- force:

  If TRUE, re-download files even if they exist with correct size.
  Default FALSE.

- backend:

  Backend to use for downloading: "datalad", "s3", or "https". If NULL
  (default), auto-selects best available backend with priority: DataLad
  \> S3 \> HTTPS. DataLad provides git-annex integrity verification, S3
  uses AWS CLI for fast parallel sync, HTTPS is the universal fallback.

- client:

  An openneuro_client object. If NULL, creates default client.

## Value

Invisibly returns a list with:

- downloaded:

  Number of files downloaded

- skipped:

  Number of files skipped (already cached or existed)

- failed:

  Character vector of failed file names

- total_bytes:

  Total bytes downloaded

- dest_dir:

  Path to destination directory

- backend:

  Backend used for download (if S3 or DataLad)

## Details

By default, files are downloaded to a CRAN-compliant cache location
(platform-specific, see Details). Repeat downloads of the same files are
skipped automatically based on manifest tracking.

Cache locations by platform:

- Mac: ~/Library/Caches/R/openneuroR

- Linux: ~/.cache/R/openneuroR

- Windows: ~/AppData/Local/R/cache/openneuroR

Each dataset is stored in a subdirectory by dataset ID. A manifest.json
file tracks downloaded files, enabling automatic skip of already-cached
files on repeat downloads.

Backend selection:

- **DataLad**: Clones from OpenNeuroDatasets GitHub with git-annex.
  Provides cryptographic integrity verification. Requires `datalad` and
  `git-annex` CLI tools.

- **S3**: Uses AWS CLI `s3 sync` for fast parallel downloads. Requires
  `aws` CLI tool.

- **HTTPS**: Direct file downloads via httr2. Always available, no
  external dependencies.

Subject filtering:

When `subjects` is specified, only files belonging to those subjects are
downloaded, plus root-level files (e.g., `dataset_description.json`,
`participants.tsv`). Subject IDs can be provided with or without the
"sub-" prefix - both `"01"` and `"sub-01"` work.

For pattern matching, wrap the pattern in
[`regex()`](https://bbuchsbaum.github.io/openneuroR/reference/regex.md).
Patterns are auto-anchored for full subject ID matching, so
`regex("sub-01")` will match "sub-01" but not "sub-010".

## Examples

``` r
if (FALSE) { # \dontrun{
# Download to cache (default - auto-selects best backend)
on_download("ds000001", files = "participants.tsv")

# Repeat download skips cached files
result <- on_download("ds000001", files = "participants.tsv")
result$skipped  # >= 1 (files already in cache)

# Download to specific directory (bypasses cache)
on_download("ds000001", dest_dir = "~/data/openneuro")

# Download to current working directory
on_download("ds000001", use_cache = FALSE)

# Force re-download of cached files
on_download("ds000001", force = TRUE)

# Use specific backend
on_download("ds000001", backend = "s3")
on_download("ds000001", backend = "https")  # Force HTTPS

# Download specific subjects
on_download("ds000001", subjects = c("sub-01", "sub-02"))

# Download subjects matching pattern
on_download("ds000001", subjects = regex("sub-0[1-5]"))

# Download subjects without derivatives
on_download("ds000001", subjects = c("01", "02"), include_derivatives = FALSE)
} # }
```
