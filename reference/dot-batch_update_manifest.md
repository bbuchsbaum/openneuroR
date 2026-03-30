# Batch Update Manifest with Multiple Files

Updates a manifest with multiple file entries in a single read-write
cycle, avoiding the O(n^2) cost of calling
[`.update_manifest()`](https://bbuchsbaum.github.io/openneuroR/reference/dot-update_manifest.md)
per file.

## Usage

``` r
.batch_update_manifest(
  dataset_dir,
  file_entries,
  dataset_id,
  snapshot_tag,
  backend = "https",
  type = "raw"
)
```

## Arguments

- dataset_dir:

  Path to the dataset cache directory.

- file_entries:

  A list of lists, each with `path` and `size` fields.

- dataset_id:

  Dataset identifier (used if creating new manifest).

- snapshot_tag:

  Snapshot tag (used if creating new manifest).

- backend:

  Backend used for download (e.g., "https").

- type:

  Type of cached data: "raw" or "derivative".

## Value

Invisibly returns the updated manifest.
