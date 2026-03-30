# Discover Available Output Spaces

Discovers the available output spaces (MNI152NLin2009cAsym, fsaverage,
etc.) for a derivative dataset. Parses BIDS `_space-` entity from
filenames.

## Usage

``` r
on_spaces(derivative, refresh = FALSE, client = NULL)
```

## Arguments

- derivative:

  A single-row tibble from
  [`on_derivatives()`](https://bbuchsbaum.github.io/openneuroR/reference/on_derivatives.md)
  output. Must contain columns: `dataset_id`, `pipeline`, and `source`.

- refresh:

  If `TRUE`, bypass cache and fetch fresh data. Default is `FALSE` to
  use cached results.

- client:

  An `openneuro_client` object for API calls (embedded sources). If
  `NULL` (default), creates a default client.

## Value

A character vector of space names, sorted alphabetically. Common spaces
include:

- Volumetric: MNI152NLin2009cAsym, MNI152NLin6Asym, T1w

- Surface: fsaverage, fsaverage5, fsaverage6, fsnative

Returns `character(0)` with a warning if no spaces are found.

## Details

### Space Discovery

This function samples derivative files and extracts the `_space-<label>`
entity from BIDS-formatted filenames. It does NOT infer T1w from files
without a space entity (per BIDS convention, native space files may omit
the space entity).

### Source Handling

- **embedded**: Uses the OpenNeuro API to list files in the
  `derivatives/{pipeline}/` directory.

- **openneuro-derivatives**: Uses AWS CLI to list files from the
  `s3://openneuro-derivatives/` bucket.

### Caching

Results are cached per-session to minimize API/S3 calls. Use
`refresh = TRUE` to bypass the cache.

## See also

[`on_derivatives()`](https://bbuchsbaum.github.io/openneuroR/reference/on_derivatives.md)
to discover available derivative datasets

## Examples

``` r
if (FALSE) { # \dontrun{
# First, get available derivatives for a dataset
derivs <- on_derivatives("ds000102")
print(derivs)

# Then get spaces for the first derivative
spaces <- on_spaces(derivs[1, ])
print(spaces)
# Example output: c("MNI152NLin2009cAsym", "fsaverage")

# Force refresh of cached spaces
spaces <- on_spaces(derivs[1, ], refresh = TRUE)
} # }
```
