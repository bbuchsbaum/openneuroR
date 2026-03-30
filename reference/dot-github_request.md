# Create GitHub API Request

Builds an httr2 request to the GitHub API with proper headers, rate
limiting, and retry configuration.

## Usage

``` r
.github_request(endpoint, ...)
```

## Arguments

- endpoint:

  The API endpoint path (e.g., "/orgs/OpenNeuroDerivatives/repos").

- ...:

  Additional query parameters.

## Value

An httr2 request object ready for execution.
