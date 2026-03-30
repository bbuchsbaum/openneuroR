# Check if Specific Backend is Available

Checks if the required CLI tools for a backend are installed and
accessible in the system PATH.

## Usage

``` r
.backend_available(backend)
```

## Arguments

- backend:

  Character string: "s3", "datalad", or "https".

## Value

Logical: TRUE if backend is available, FALSE otherwise.
