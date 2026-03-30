# List Datasets (Internal)

Lists datasets without a search query, supporting modality filter.

## Usage

``` r
.on_list_datasets(modality = NULL, limit = 50, all = FALSE, client = NULL)
```

## Arguments

- modality:

  Filter by modality.

- limit:

  Maximum results per page.

- all:

  Paginate through all results.

- client:

  OpenNeuro client.

## Value

A tibble of datasets.
