# Parse ISO Timestamp to POSIXct

Parses ISO 8601 timestamps from the OpenNeuro API to POSIXct objects.

## Usage

``` r
.parse_timestamp(x)
```

## Arguments

- x:

  A character string containing an ISO timestamp, or NULL.

## Value

A POSIXct object, or NA if input is NULL or invalid.
