# Raise Rate Limit Error with Details

Creates an informative error when GitHub rate limit is exceeded,
including reset time and suggestions for authentication.

## Usage

``` r
.github_rate_limit_error(resp)
```

## Arguments

- resp:

  An httr2 response object.

## Value

Does not return; raises an error with class
`openneuro_rate_limit_error`.
