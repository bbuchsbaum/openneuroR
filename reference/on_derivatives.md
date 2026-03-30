# Discover Derivative Datasets

Finds derivative datasets (fMRIPrep, MRIQC, etc.) available for an
OpenNeuro dataset. Searches both embedded derivatives within the dataset
and external derivatives from the OpenNeuroDerivatives GitHub
organization.

## Usage

``` r
on_derivatives(
  dataset_id,
  sources = c("embedded", "openneuro-derivatives"),
  refresh = FALSE,
  client = NULL
)
```

## Arguments

- dataset_id:

  Dataset identifier (e.g., "ds000102").

- sources:

  Character vector specifying which sources to check. Default is
  `c("embedded", "openneuro-derivatives")` to check both. Use
  `"embedded"` for derivatives stored within the dataset, or
  `"openneuro-derivatives"` for external derivatives from GitHub.

- refresh:

  If `TRUE`, bypass cache and fetch fresh data from APIs. Default is
  `FALSE` to use cached results when available.

- client:

  An `openneuro_client` object for embedded derivative checks. If `NULL`
  (default), creates a default client.

## Value

A tibble with one row per available derivative, containing:

- dataset_id:

  The dataset identifier

- pipeline:

  Pipeline name (e.g., "fmriprep", "mriqc")

- source:

  Where the derivative is from: "embedded" or "openneuro-derivatives"

- version:

  Pipeline version (NA if not available)

- n_subjects:

  Number of subjects processed (NA if not available)

- n_files:

  Number of derivative files (NA if not available)

- total_size:

  Human-readable size (e.g., "2.3 GB", NA if not available)

- last_modified:

  Last modification time (POSIXct, NA if not available)

- s3_url:

  S3 URL for OpenNeuroDerivatives sources (NA for embedded)

Returns an empty tibble with the same structure if no derivatives are
found.

## Details

### Derivative Sources

**Embedded derivatives** are stored directly within the dataset's BIDS
structure in a `derivatives/` subdirectory. These are typically provided
by the dataset authors.

**OpenNeuroDerivatives** are externally processed derivatives maintained
by the OpenNeuro team, available from the [OpenNeuroDerivatives GitHub
organization](https://github.com/OpenNeuroDerivatives). These are stored
on S3 and can be downloaded separately.

### Source Preference

When the same pipeline exists in both sources, embedded derivatives are
preferred and the OpenNeuroDerivatives entry is removed from results.
This follows the principle that author-provided derivatives should take
precedence.

### Caching

Results are cached per-session to minimize API calls. Use
`refresh = TRUE` to bypass the cache and fetch fresh data.

## See also

[`on_files()`](https://bbuchsbaum.github.io/openneuroR/reference/on_files.md)
for listing files within datasets

## Examples

``` r
if (FALSE) { # \dontrun{
# Find all derivatives for a dataset
derivs <- on_derivatives("ds000102")
print(derivs)

# Check only OpenNeuroDerivatives (GitHub)
github_derivs <- on_derivatives("ds000102", sources = "openneuro-derivatives")

# Check only embedded derivatives
embedded_derivs <- on_derivatives("ds000102", sources = "embedded")

# Force refresh of cached data
fresh_derivs <- on_derivatives("ds000102", refresh = TRUE)

# Filter for fMRIPrep derivatives
fmriprep <- derivs[derivs$pipeline == "fmriprep", ]
} # }
```
