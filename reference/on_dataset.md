# Get Dataset Metadata

Retrieves detailed metadata for a single OpenNeuro dataset.

## Usage

``` r
on_dataset(id, client = NULL)
```

## Arguments

- id:

  Dataset identifier (e.g., "ds000001").

- client:

  An `openneuro_client` object. If `NULL`, creates a default client.

## Value

A tibble with one row containing:

- id:

  Dataset identifier

- name:

  Dataset title

- created:

  Timestamp when dataset was created (POSIXct)

- public:

  Whether the dataset is publicly accessible (logical)

- latest_snapshot:

  Tag of the most recent snapshot (if any)

## See also

[`on_search()`](https://bbuchsbaum.github.io/openneuroR/reference/on_search.md)
to find datasets,
[`on_snapshots()`](https://bbuchsbaum.github.io/openneuroR/reference/on_snapshots.md)
for version history

## Examples

``` r
if (FALSE) { # \dontrun{
# Get metadata for a specific dataset
ds <- on_dataset("ds000001")
print(ds)

# Access fields
ds$name
ds$created
} # }
```
