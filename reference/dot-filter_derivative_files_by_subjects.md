# Filter Derivative Files by Subject IDs (Literal)

Filters derivative files to include only those belonging to specified
subjects.

## Usage

``` r
.filter_derivative_files_by_subjects(files_df, subjects)
```

## Arguments

- files_df:

  A tibble with `full_path` column.

- subjects:

  Character vector of normalized subject IDs (with "sub-" prefix).

## Value

Filtered tibble.
