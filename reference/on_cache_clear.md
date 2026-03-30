# Clear Cache

Removes cached datasets. Can clear a specific dataset or all cached
data.

## Usage

``` r
on_cache_clear(dataset_id = NULL, confirm = interactive())
```

## Arguments

- dataset_id:

  Dataset identifier to clear (e.g., "ds000001"), or NULL to clear all
  cached datasets.

- confirm:

  If TRUE (default in interactive sessions), asks for confirmation
  before clearing. Set FALSE to skip confirmation.

## Value

Invisibly returns the number of datasets cleared.

## Examples

``` r
if (FALSE) { # \dontrun{
# Clear specific dataset (with confirmation)
on_cache_clear("ds000001")

# Clear specific dataset without confirmation
on_cache_clear("ds000001", confirm = FALSE)

# Clear all cached datasets
on_cache_clear()
} # }
```
