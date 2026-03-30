# Get Derivative Cache Path

Returns the cache path for a derivative dataset. Structure:
`{cache_root}/{dataset_id}/derivatives/{pipeline}/`

## Usage

``` r
.on_derivative_cache_path(dataset_id, pipeline)
```

## Arguments

- dataset_id:

  Dataset identifier (e.g., "ds000001").

- pipeline:

  Pipeline name (e.g., "fmriprep").

## Value

Character string: path to derivative cache directory.
