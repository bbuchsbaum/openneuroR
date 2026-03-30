# List Dataset Snapshots

Retrieves all snapshots (versioned releases) for a dataset. Snapshots
are immutable versions of the dataset that can be referenced by tag.

## Usage

``` r
on_snapshots(id, client = NULL)
```

## Arguments

- id:

  Dataset identifier (e.g., "ds000001").

- client:

  An `openneuro_client` object. If `NULL`, creates a default client.

## Value

A tibble with columns:

- tag:

  Snapshot version tag (e.g., "1.0.0")

- created:

  Timestamp when snapshot was created (POSIXct)

- size:

  Total size of the snapshot in bytes (numeric)

Rows are ordered with most recent snapshot first. Returns an empty
tibble with the same column structure if the dataset has no snapshots.

## See also

[`on_files()`](https://bbuchsbaum.github.io/openneuroR/reference/on_files.md)
to list files in a snapshot,
[`on_dataset()`](https://bbuchsbaum.github.io/openneuroR/reference/on_dataset.md)
for metadata

## Examples

``` r
if (FALSE) { # \dontrun{
# List all snapshots for a dataset
snaps <- on_snapshots("ds000001")
print(snaps)

# Get the latest snapshot tag
latest_tag <- snaps$tag[1]

# Calculate total size in GB
snaps$size_gb <- snaps$size / (1024^3)
} # }
```
