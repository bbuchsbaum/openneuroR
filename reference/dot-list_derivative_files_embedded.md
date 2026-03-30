# List Derivative Files for Embedded Sources

Lists files from an embedded derivative dataset using the OpenNeuro API.
Samples files from the first few subjects to efficiently determine
available spaces without exhaustive listing.

## Usage

``` r
.list_derivative_files_embedded(
  dataset_id,
  pipeline,
  tag = NULL,
  client = NULL
)
```

## Arguments

- dataset_id:

  Character string: Dataset identifier (e.g., "ds000102").

- pipeline:

  Character string: Pipeline name (e.g., "fmriprep").

- tag:

  Character string or NULL: Snapshot version tag.

- client:

  An `openneuro_client` object, or NULL to use default.

## Value

Character vector: Filenames found in the derivative dataset.

## Details

This function navigates the `derivatives/<pipeline>/` tree and samples
files from the first 2-3 subjects. It looks in both `func/` and `anat/`
subdirectories for each subject.
