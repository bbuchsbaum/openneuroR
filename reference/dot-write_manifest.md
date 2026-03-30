# Write Manifest Atomically

Writes a manifest to JSON using atomic pattern: writes to temp file
first, then moves to final location. Creates the dataset directory if
needed.

## Usage

``` r
.write_manifest(manifest, dataset_dir)
```

## Arguments

- manifest:

  Manifest list to write.

- dataset_dir:

  Path to the dataset cache directory.

## Value

Invisibly returns the manifest path on success.
