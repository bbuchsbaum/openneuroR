# Calculate Retry Delay for Rate Limited Response

Calculates how many seconds to wait before retrying a rate-limited
GitHub API request.

## Usage

``` r
.github_after(resp)
```

## Arguments

- resp:

  An httr2 response object.

## Value

Number of seconds to wait before retry (minimum 0).
