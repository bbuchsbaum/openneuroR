# Detect Embedded Derivatives

Checks if a dataset has derivatives embedded directly in its BIDS
structure. Embedded derivatives are stored in a `derivatives/`
subdirectory within the dataset itself.

## Usage

``` r
.detect_embedded_derivatives(dataset_id, tag = NULL, client = NULL)
```

## Arguments

- dataset_id:

  Dataset identifier (e.g., "ds000001").

- tag:

  Snapshot version tag. If `NULL`, uses latest snapshot.

- client:

  An `openneuro_client` object. If `NULL`, creates a default client.

## Value

A tibble with derivative information, or empty tibble if no embedded
derivatives found.
