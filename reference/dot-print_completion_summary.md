# Print Download Completion Summary

Prints a summary message after batch download completes.

## Usage

``` r
.print_completion_summary(result, quiet = FALSE)
```

## Arguments

- result:

  A list with download results (downloaded, skipped, failed,
  total_bytes, dest_dir).

- quiet:

  If `TRUE`, suppress all output.

## Value

Invisibly returns `NULL`.
