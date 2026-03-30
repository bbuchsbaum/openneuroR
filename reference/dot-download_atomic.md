# Download File Atomically

Downloads a file to a temporary location and moves to final destination
only on success. Ensures no partial/corrupt files remain on failure.

## Usage

``` r
.download_atomic(url, final_path, download_fn = NULL, ...)
```

## Arguments

- url:

  URL to download from.

- final_path:

  Final destination path for the file.

- download_fn:

  Function to perform the actual download. Should accept `url` and
  `dest_path` as arguments. If `NULL`, uses `.download_single_file`.

- ...:

  Additional arguments passed to `download_fn`.

## Value

Invisibly returns the final path on success.
