# List OpenNeuroDerivatives Repositories

Retrieves all derivative repositories from the OpenNeuroDerivatives
GitHub organization, with pagination and caching.

## Usage

``` r
.list_openneuro_derivatives_repos(refresh = FALSE)
```

## Arguments

- refresh:

  If `TRUE`, bypass cache and fetch fresh data. Default is `FALSE`.

## Value

A list of parsed repository information, each containing `dataset_id`,
`pipeline`, `repo_name`, `pushed_at`, and `size_kb`.

## Details

Results are cached for the session to minimize API calls. GitHub API
rate limits apply (60/hour unauthenticated, 5000/hour with `GITHUB_PAT`
environment variable set).

The OpenNeuroDerivatives organization contains 700+ repositories,
requiring pagination (100 per page) to retrieve all results.
