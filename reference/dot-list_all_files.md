# List All Files in a Dataset Recursively

Recursively traverses the directory structure of a dataset and returns
all files with their full paths from the dataset root.

## Usage

``` r
.list_all_files(dataset_id, tag = NULL, client = NULL)
```

## Arguments

- dataset_id:

  Dataset identifier (e.g., "ds000001").

- tag:

  Snapshot version tag. If `NULL`, uses the most recent snapshot.

- client:

  An `openneuro_client` object. If `NULL`, creates a default client.

## Value

A tibble with columns:

- filename:

  Name of the file (basename only)

- full_path:

  Full path from dataset root (e.g., "sub-01/anat/T1w.nii.gz")

- size:

  File size in bytes (numeric)

- annexed:

  TRUE if file is stored in git-annex (logical)

## Details

This function makes multiple API calls (one per directory) to build the
complete file listing. For large datasets with many directories, this
may take some time. A progress indicator is shown in interactive
sessions.
