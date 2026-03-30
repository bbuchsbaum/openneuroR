# Filter Files by Space

Filters a file tibble to include only files matching the specified space
or files without a `_space-` entity (native space per BIDS convention).

## Usage

``` r
.filter_files_by_space(files_df, space)
```

## Arguments

- files_df:

  A tibble with `full_path` column.

- space:

  Character string: space name to filter by (exact match).

## Value

Filtered tibble.
