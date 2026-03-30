# Download Files with Progress Reporting

Batch downloads files with progress bar and completion summary. When
using cache, checks manifest for already-cached files and updates
manifest after successful downloads.

## Usage

``` r
.download_with_progress(
  files_df,
  dest_dir,
  dataset_id,
  tag = NULL,
  quiet = FALSE,
  verbose = FALSE,
  force = FALSE,
  use_cache = FALSE,
  type = "raw",
  manifest_dir = dest_dir,
  url_prefix = NULL,
  manifest_prefix = NULL
)
```

## Arguments

- files_df:

  A tibble with columns `filename`, `full_path`, `size`, `annexed`.

- dest_dir:

  Destination directory path.

- dataset_id:

  Dataset identifier for URL construction.

- tag:

  Snapshot version tag (can be NULL).

- quiet:

  If `TRUE`, suppress all output.

- verbose:

  If `TRUE`, show per-file progress in addition to overall progress.

- force:

  If `TRUE`, re-download files even if they exist with correct size.

- use_cache:

  If `TRUE`, use manifest for cache tracking and update after downloads.

- type:

  Type of cached data: "raw" for raw dataset files, "derivative" for
  derivative outputs under `derivatives/`.

- manifest_dir:

  Directory that owns `manifest.json`. Defaults to `dest_dir`.

- url_prefix:

  Optional prefix prepended to each file path when constructing download
  URLs.

- manifest_prefix:

  Optional prefix prepended to each file path when writing manifest
  entries and performing cache skip checks.

## Value

A list with components:

- downloaded:

  Number of files downloaded

- skipped:

  Number of files skipped (already existed or cached)

- failed:

  Character vector of failed file names

- total_bytes:

  Total bytes downloaded

- dest_dir:

  Path to destination directory
