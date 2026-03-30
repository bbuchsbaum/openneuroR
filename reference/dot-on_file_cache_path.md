# Get File Cache Path

Returns the full cache path for a specific file within a dataset. Does
NOT auto-create the directory.

## Usage

``` r
.on_file_cache_path(dataset_id, file_path)
```

## Arguments

- dataset_id:

  Dataset identifier (e.g., "ds000001").

- file_path:

  Path to file within the dataset (e.g., "sub-01/anat/T1w.nii.gz").

## Value

Full path to the cached file location.
