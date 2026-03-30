# Recursively List Directory Contents

Helper to recursively traverse a directory tree via API.

## Usage

``` r
.list_directory_recursive(dataset_id, tag, key, parent_path, client)
```

## Arguments

- dataset_id:

  Dataset identifier.

- tag:

  Snapshot tag (can be NULL).

- key:

  Directory key for API call.

- parent_path:

  Path prefix for building full paths.

- client:

  An `openneuro_client` object.

## Value

A tibble with filename, full_path, and size columns.
