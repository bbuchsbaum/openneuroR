# List S3 Derivative Files (Full)

Lists all files from the openneuro-derivatives S3 bucket using AWS CLI.
Paginates through the entire listing without limits.

## Usage

``` r
.list_derivative_files_s3_full(dataset_id, pipeline)
```

## Arguments

- dataset_id:

  Dataset identifier.

- pipeline:

  Pipeline name.

## Value

A tibble with filename, full_path, and size columns.
