# Update Manifest with New File

Reads existing manifest (or creates new), adds/updates a file entry, and
writes back atomically.

## Usage

``` r
.update_manifest(
  dataset_dir,
  new_file_info,
  dataset_id,
  snapshot_tag,
  backend = "https",
  type = "raw"
)
```

## Arguments

- dataset_dir:

  Path to the dataset cache directory.

- new_file_info:

  List with file information (path, size).

- dataset_id:

  Dataset identifier (used if creating new manifest).

- snapshot_tag:

  Snapshot tag (used if creating new manifest).

- backend:

  Backend used for download (e.g., "https").

- type:

  Type of cached data: "raw" for raw dataset files, "derivative" for
  fMRIPrep/MRIQC derivative outputs. Defaults to "raw". Existing
  manifest entries without a type field are treated as "raw" for
  backward compatibility.

## Value

Invisibly returns the updated manifest.
