# Find Derivatives in GitHub

Searches the OpenNeuroDerivatives GitHub organization for repositories
matching the specified dataset.

## Usage

``` r
.find_derivatives_in_github(dataset_id, refresh = FALSE)
```

## Arguments

- dataset_id:

  Dataset identifier (e.g., "ds000001").

- refresh:

  If `TRUE`, bypass cache and fetch fresh data.

## Value

A tibble with derivative information from GitHub repositories.
