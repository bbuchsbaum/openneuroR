# List Subjects in a Dataset

Returns the subject IDs present in a dataset snapshot without
downloading any data. This is a metadata-only query using the OpenNeuro
GraphQL API.

## Usage

``` r
on_subjects(id, tag = NULL, client = NULL)
```

## Arguments

- id:

  Dataset identifier (e.g., "ds000001").

- tag:

  Snapshot version tag (e.g., "1.0.0"). If `NULL` (default), uses the
  most recent snapshot.

- client:

  An `openneuro_client` object. If `NULL`, creates a default client.

## Value

A tibble with columns:

- dataset_id:

  The dataset identifier

- subject_id:

  Subject identifier (e.g., "sub-01")

- n_sessions:

  Number of sessions in the dataset (same for all rows)

- n_files:

  Estimated files per subject (same for all rows)

Returns an empty tibble with the same column structure if the dataset
has no BIDS subjects (e.g., non-BIDS datasets).

## Details

Subject IDs are returned in natural sort order, so "sub-10" comes after
"sub-9" rather than after "sub-1".

The n_sessions and n_files columns provide dataset-level context.
Per-subject session and file counts are not available from the OpenNeuro
API.

## See also

[`on_files()`](https://bbuchsbaum.github.io/openneuroR/reference/on_files.md)
to list files,
[`on_download()`](https://bbuchsbaum.github.io/openneuroR/reference/on_download.md)
to download data

## Examples

``` r
if (FALSE) { # \dontrun{
# List subjects in a dataset
subjects <- on_subjects("ds000001")
print(subjects)

# List subjects in a specific snapshot
subjects <- on_subjects("ds000001", tag = "1.0.0")

# Get subject count
nrow(subjects)
} # }
```
