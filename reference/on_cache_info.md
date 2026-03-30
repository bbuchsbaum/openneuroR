# Get Cache Information

Returns information about the openneuroR cache location and total size.

## Usage

``` r
on_cache_info()
```

## Value

A list with:

- cache_path:

  Path to cache directory

- n_datasets:

  Number of cached datasets

- total_size:

  Total size in bytes

- size_formatted:

  Human-readable total size (e.g., "5.3 GB")

## Examples

``` r
if (FALSE) { # \dontrun{
# Get cache info
info <- on_cache_info()
info$cache_path    # Where cache is stored
info$n_datasets    # How many datasets
info$size_formatted  # Human-readable size
} # }
```
