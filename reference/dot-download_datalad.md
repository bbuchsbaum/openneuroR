# Download Dataset via DataLad

Downloads a dataset using the DataLad CLI with git-annex integrity
verification. Clones the dataset from the OpenNeuroDatasets GitHub
repository and retrieves file content with checksums.

## Usage

``` r
.download_datalad(
  dataset_id,
  dest_dir,
  files = NULL,
  quiet = FALSE,
  timeout = 1800
)
```

## Arguments

- dataset_id:

  Dataset identifier (e.g., "ds000001").

- dest_dir:

  Destination directory for the dataset.

- files:

  Character vector of specific files to retrieve. If `NULL` (default),
  retrieves all files.

- quiet:

  Logical. If `TRUE`, suppress progress output. Default is `FALSE`.

- timeout:

  Timeout in seconds for the get operation. Default is 1800 (30 minutes)
  to accommodate large datasets.

## Value

A list with components:

- success:

  Logical indicating success (`TRUE`)

- backend:

  Character string `"datalad"`

## Details

The function performs two operations:

1.  **Clone** (if needed): Clones the dataset from
    `https://github.com/OpenNeuroDatasets/{dataset_id}.git`

2.  **Get**: Retrieves file content with integrity verification via
    git-annex

If the destination is already a DataLad dataset (has `.datalad/`
directory), the clone step is skipped and only the get operation runs.
