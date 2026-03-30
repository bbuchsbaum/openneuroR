# Filter Files by Subjects

Filters a file tibble to only include files for matching subjects plus
root-level files.

## Usage

``` r
.filter_files_by_subjects(
  files_df,
  matching_subjects,
  include_derivatives = TRUE
)
```

## Arguments

- files_df:

  Tibble from
  [`.list_all_files()`](https://bbuchsbaum.github.io/openneuroR/reference/dot-list_all_files.md)
  with `full_path` column.

- matching_subjects:

  Character vector of subject IDs (with "sub-" prefix).

- include_derivatives:

  If TRUE, include derivatives/\*/sub-XX/ files.

## Value

Filtered tibble.
