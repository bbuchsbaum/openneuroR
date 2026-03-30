# Select Best Available Backend

Selects the best available download backend based on priority: DataLad
\> S3 \> HTTPS. If a preferred backend is specified, attempts to use it,
falling back with a warning if unavailable.

## Usage

``` r
.select_backend(preferred = NULL)
```

## Arguments

- preferred:

  Character string: Preferred backend ("datalad", "s3", or "https"). If
  NULL (default), auto-selects best available.

## Value

Character string: Selected backend name.
