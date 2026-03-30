# Read Manifest

Reads the manifest.json file from a dataset directory if it exists.
Returns NULL if the manifest doesn't exist. Issues a warning and returns
NULL if the manifest exists but contains corrupt JSON.

## Usage

``` r
.read_manifest(dataset_dir)
```

## Arguments

- dataset_dir:

  Path to the dataset cache directory.

## Value

Manifest as a list, or NULL if not found or corrupt.
