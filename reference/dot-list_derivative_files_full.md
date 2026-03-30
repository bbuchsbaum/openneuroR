# List All Derivative Files (Full Listing)

Gets a complete file listing for a derivative dataset. For embedded
derivatives, uses the OpenNeuro API recursively. For
openneuro-derivatives S3 bucket, uses AWS CLI with recursive listing.

## Usage

``` r
.list_derivative_files_full(dataset_id, pipeline, source, client = NULL)
```

## Arguments

- dataset_id:

  Dataset identifier (e.g., "ds000001").

- pipeline:

  Pipeline name (e.g., "fmriprep").

- source:

  Source of derivative: "embedded" or "openneuro-derivatives".

- client:

  An `openneuro_client` object (for embedded sources).

## Value

A tibble with columns:

- filename:

  Base filename

- full_path:

  Relative path within derivative

- size:

  File size in bytes
