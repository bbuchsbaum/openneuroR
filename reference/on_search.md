# Search OpenNeuro Datasets

Searches the OpenNeuro database for datasets. When a text query is
provided, uses the search endpoint if available. Otherwise lists
datasets with optional filtering.

## Usage

``` r
on_search(
  query = NULL,
  modality = NULL,
  limit = 50,
  all = FALSE,
  client = NULL
)
```

## Arguments

- query:

  Text query to search for. Note: The OpenNeuro search API may have
  limited availability. If search returns no results, consider using
  `query = NULL` with `modality` filter instead.

- modality:

  Filter by modality (e.g., "MRI", "EEG", "MEG", "iEEG", "PET").
  Case-insensitive matching is attempted.

- limit:

  Maximum number of results to return per page (default 50).

- all:

  If `TRUE`, paginate through all matching results. If `FALSE`
  (default), return only the first page.

- client:

  An `openneuro_client` object. If `NULL`, creates a default client.

## Value

A tibble with columns:

- id:

  Dataset identifier (e.g., "ds000001")

- name:

  Dataset title

- created:

  Timestamp when dataset was created (POSIXct)

- public:

  Whether the dataset is publicly accessible (logical)

- modalities:

  List of modalities in the dataset

- n_subjects:

  Number of subjects in the dataset

- tasks:

  List of tasks in the dataset

Returns an empty tibble with the same column structure if no matches
found.

## See also

[`on_dataset()`](https://bbuchsbaum.github.io/openneuroR/reference/on_dataset.md)
for detailed metadata on a single dataset

## Examples

``` r
if (FALSE) { # \dontrun{
# List datasets (most reliable)
results <- on_search(limit = 10)

# Filter by modality
mri_datasets <- on_search(modality = "MRI", limit = 25)
eeg_datasets <- on_search(modality = "EEG", limit = 25)

# Text search (may have limited availability)
results <- on_search("visual cortex", limit = 10)

# Get all datasets (may be slow)
all_datasets <- on_search(all = TRUE)
} # }
```
