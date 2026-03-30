# Download with Resume Support

Downloads a file using HTTP Range headers to resume from a partial
download. Only used for files \>= 10 MB with existing partial content.

## Usage

``` r
.download_resumable(url, dest_path, existing_bytes, show_progress = FALSE)
```

## Arguments

- url:

  URL to download from.

- dest_path:

  Destination path (existing partial file).

- existing_bytes:

  Number of bytes already downloaded.

- show_progress:

  Logical. If `TRUE`, show progress bar.

## Value

Invisibly returns `TRUE` on success.

## Details

The function handles two server responses:

- HTTP 206 (Partial Content): Server supports Range, appends remaining
  bytes

- HTTP 200 (OK): Server ignored Range, replaces file with full download
