# Convert NULL to NA

Safely converts NULL values to NA for use in tibble columns.

## Usage

``` r
.null_to_na(x, type = "character")
```

## Arguments

- x:

  A value that may be NULL.

- type:

  The NA type to return. One of "character", "real", "integer",
  "logical".

## Value

The original value, or NA of the appropriate type if NULL.
