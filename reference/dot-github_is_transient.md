# Check if GitHub Error is Transient (Rate Limited)

Determines if a GitHub API response represents a transient rate limit
error that should be retried.

## Usage

``` r
.github_is_transient(resp)
```

## Arguments

- resp:

  An httr2 response object.

## Value

`TRUE` if the error is a transient rate limit error, `FALSE` otherwise.
