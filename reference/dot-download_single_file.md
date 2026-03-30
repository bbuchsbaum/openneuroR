# Download a Single File

Downloads a file from a URL to a destination path with progress
reporting, automatic retry on transient failures, and resume support for
large files.

## Usage

``` r
.download_single_file(
  url,
  dest_path,
  expected_size = NULL,
  resume = TRUE,
  quiet = FALSE
)
```

## Arguments

- url:

  URL to download from.

- dest_path:

  Destination path for the downloaded file.

- expected_size:

  Expected file size in bytes for resume logic. If `NULL`, resume is
  disabled.

- resume:

  Logical. If `TRUE` (default), attempt to resume partial downloads for
  files \>= 10 MB.

- quiet:

  Logical. If `TRUE`, suppress progress bar. Default is `FALSE`.

## Value

A list with components:

- success:

  Logical indicating download success

- path:

  Path to the downloaded file

- bytes:

  Size of the downloaded file in bytes
