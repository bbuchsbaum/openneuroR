# Determine DataLad Action for Directory

Checks whether a destination directory needs to be cloned or can be
updated.

## Usage

``` r
.datalad_action(dest_dir)
```

## Arguments

- dest_dir:

  Path to the destination directory.

## Value

Character string: "clone" if directory doesn't exist or is empty,
"update" if directory is already a DataLad dataset. Aborts if directory
exists but is not a DataLad dataset.
