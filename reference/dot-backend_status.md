# Session-Cached Backend Status

Caches backend availability detection results for the session to avoid
repeated Sys.which() calls.

## Usage

``` r
.backend_status(backend, refresh = FALSE)
```

## Arguments

- backend:

  Character string: "s3", "datalad", or "https".

- refresh:

  Logical: If TRUE, re-check availability even if cached.

## Value

Logical: TRUE if backend is available, FALSE otherwise.
