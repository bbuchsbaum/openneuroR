# List Cached Datasets

Returns a tibble of all datasets currently in the openneuroR cache.

## Usage

``` r
on_cache_list()
```

## Value

A tibble with columns:

- dataset_id:

  Dataset identifier (e.g., "ds000001")

- snapshot_tag:

  Cached snapshot version (may be NA if unknown)

- n_files:

  Number of cached files

- total_size:

  Total size in bytes

- size_formatted:

  Human-readable size (e.g., "1.2 GB")

- cached_at:

  When first cached (ISO 8601 timestamp)

- type:

  Type of cached data: "raw" for raw dataset files, "derivative" for
  fMRIPrep/MRIQC outputs, or "raw+derivative" if both are cached

## Examples

``` r
if (FALSE) { # \dontrun{
# List all cached datasets
on_cache_list()

# Check total cache usage
cached <- on_cache_list()
sum(cached$total_size)  # total bytes

# Filter to only derivatives
cached[grepl("derivative", cached$type), ]
} # }
```
