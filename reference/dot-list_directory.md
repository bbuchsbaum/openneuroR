# List Files in a Directory (Helper)

Recursively lists files in a subdirectory, building full paths.

## Usage

``` r
.list_directory(dataset_id, tag, key, parent_path, client)
```

## Arguments

- dataset_id:

  Dataset identifier.

- tag:

  Snapshot version tag.

- key:

  Directory key for the API call.

- parent_path:

  Path prefix for building full paths.

- client:

  An `openneuro_client` object.

## Value

A tibble with the same structure as
[`.list_all_files()`](https://bbuchsbaum.github.io/openneuroR/reference/dot-list_all_files.md).
