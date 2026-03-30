# List Embedded Derivative Files (Full)

Recursively lists all files in an embedded derivative using the
OpenNeuro API.

## Usage

``` r
.list_derivative_files_embedded_full(dataset_id, pipeline, client = NULL)
```

## Arguments

- dataset_id:

  Dataset identifier.

- pipeline:

  Pipeline name.

- client:

  An `openneuro_client` object.

## Value

A tibble with filename, full_path, and size columns.
