# Filter Files by BIDS Suffix

Filters a file tibble to include only files matching the specified BIDS
suffixes. Files without a clear suffix (metadata files, etc.) are always
included.

## Usage

``` r
.filter_files_by_suffix(files_df, suffix)
```

## Arguments

- files_df:

  A tibble with `full_path` column.

- suffix:

  Character vector: BIDS suffixes to filter by.

## Value

Filtered tibble.
