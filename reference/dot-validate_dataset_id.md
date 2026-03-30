# Validate Dataset ID Format

Checks that a dataset ID matches the expected OpenNeuro format (ds
followed by 6 digits, e.g., "ds000001"). Used at public API entry points
to prevent path traversal and malformed requests.

## Usage

``` r
.validate_dataset_id(id)
```

## Arguments

- id:

  A string to validate as a dataset ID.

## Value

`TRUE` invisibly if valid; aborts with an error if invalid.
