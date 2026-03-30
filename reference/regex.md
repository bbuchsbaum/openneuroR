# Mark String as Regex Pattern for Subject Filtering

Creates a regex pattern object for use with the `subjects` parameter in
[`on_download()`](https://bbuchsbaum.github.io/openneuroR/reference/on_download.md).
Patterns are auto-anchored to match complete subject IDs.

## Usage

``` r
regex(pattern)
```

## Arguments

- pattern:

  A single non-empty character string containing a regex pattern.

## Value

A character vector with class `c("on_regex", "character")`.

## See also

[`on_download()`](https://bbuchsbaum.github.io/openneuroR/reference/on_download.md)
for downloading with subject filters

## Examples

``` r
# Match subjects sub-01 through sub-05
regex("sub-0[1-5]")
#> [1] "sub-0[1-5]"
#> attr(,"class")
#> [1] "on_regex"  "character"

# Match any subject starting with sub-1
regex("sub-1.*")
#> [1] "sub-1.*"
#> attr(,"class")
#> [1] "on_regex"  "character"

if (FALSE) { # \dontrun{
# Use in on_download()
on_download("ds000001", subjects = regex("sub-0[1-5]"))
} # }
```
