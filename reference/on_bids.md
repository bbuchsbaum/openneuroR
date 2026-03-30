# Create BIDS Project from OpenNeuro Handle

Converts a fetched OpenNeuro dataset handle into a bidser `bids_project`
object, enabling BIDS-aware data access to subjects, sessions, files,
and derivatives.

## Usage

``` r
on_bids(handle, fmriprep = FALSE, prep_dir = "derivatives/fmriprep")
```

## Arguments

- handle:

  An `openneuro_handle` object, typically created with
  [`on_handle()`](https://bbuchsbaum.github.io/openneuroR/reference/on_handle.md)
  and fetched with
  [`on_fetch()`](https://bbuchsbaum.github.io/openneuroR/reference/on_fetch.md).
  If the handle is in "pending" state, it will be automatically fetched
  first.

- fmriprep:

  Logical. If `TRUE`, include fMRIPrep derivatives from the default
  `derivatives/fmriprep` path. Ignored if `prep_dir` is specified.
  Default is `FALSE`.

- prep_dir:

  Character. Path to derivatives directory relative to the dataset root.
  If specified, takes precedence over `fmriprep`. Default is
  `"derivatives/fmriprep"`.

## Value

A `bids_project` object from the bidser package.

## Details

This function provides a bridge between OpenNeuro's download system and
bidser's BIDS-aware data structures. The resulting `bids_project` object
exposes:

- Subject and session information

- BIDS file listings by modality

- Derivatives access (if available)

The bidser package is required but listed as an optional dependency
(Suggests). If not installed, a helpful message guides installation.

## Derivatives Handling

When `fmriprep = TRUE`, the function looks for derivatives at
`derivatives/fmriprep` within the dataset. You can specify a custom
derivatives path with `prep_dir`.

If `prep_dir` is set to a non-default value, it takes precedence over
`fmriprep = TRUE`. A warning is issued if the requested derivatives path
does not exist.

## See also

[`on_handle()`](https://bbuchsbaum.github.io/openneuroR/reference/on_handle.md)
to create a handle,
[`on_fetch()`](https://bbuchsbaum.github.io/openneuroR/reference/on_fetch.md)
to download data.

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic usage
handle <- on_handle("ds000001")
handle <- on_fetch(handle)
bids <- on_bids(handle)

# Auto-fetch if needed
handle <- on_handle("ds000002")
bids <- on_bids(handle)  # Fetches automatically

# Include fMRIPrep derivatives
bids <- on_bids(handle, fmriprep = TRUE)

# Custom derivatives path
bids <- on_bids(handle, prep_dir = "derivatives/custom-pipeline")
} # }
```
