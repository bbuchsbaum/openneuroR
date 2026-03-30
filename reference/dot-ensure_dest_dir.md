# Ensure Destination Directory Exists

Sets up the destination directory for downloads. If no directory is
specified, uses the current working directory with the dataset ID as a
subdirectory.

## Usage

``` r
.ensure_dest_dir(dest_dir, dataset_id)
```

## Arguments

- dest_dir:

  Destination directory path, or `NULL` to use default.

- dataset_id:

  Dataset identifier for default directory naming.

## Value

Absolute path to the destination directory.
