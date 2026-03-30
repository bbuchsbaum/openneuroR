# openneuroR

`openneuroR` is the GitHub repository for the R package `openneuro`, a
tibble-first client for discovering and downloading public
[OpenNeuro](https://openneuro.org) datasets from R.

The package is built for practical data access workflows:

- search the OpenNeuro catalogue
- inspect dataset metadata, snapshots, files, and subjects
- download full datasets, selected files, or selected subjects
- discover derivative outputs such as fMRIPrep and MRIQC
- reuse a local cache instead of re-downloading the same data
- bridge downloaded datasets into BIDS-aware tooling

## Installation

The package is not currently on CRAN. Install it from GitHub:

``` r
install.packages("pak")
pak::pak("bbuchsbaum/openneuroR")

# or
install.packages("remotes")
remotes::install_github("bbuchsbaum/openneuroR")
```

Then load the package:

``` r
library(openneuro)
```

## Optional system tools

Basic usage works with the built-in HTTPS backend. For faster or more
robust downloads, `openneuro` can also use external tools when they are
available:

- `aws` CLI for fast S3-based downloads
- `datalad` plus `git-annex` for verified, resumable dataset fetches

Check which backends are available on your machine:

``` r
on_doctor()
```

Backend selection is automatic by default:

- `datalad` if available
- otherwise `s3` if AWS CLI is available
- otherwise `https`

## Quick Start

### Search and inspect datasets

``` r
library(openneuro)

results <- on_search(modality = "MRI", limit = 10)
results[, c("id", "name", "n_subjects")]

meta <- on_dataset("ds000001")
snaps <- on_snapshots("ds000001")
files <- on_files("ds000001")
subjects <- on_subjects("ds000001")
```

### Download only what you need

Download a few files:

``` r
on_download(
  id = "ds000001",
  files = c("dataset_description.json", "participants.tsv")
)
```

Download specific subjects without derivatives:

``` r
on_download(
  id = "ds000001",
  subjects = c("01", "02"),
  include_derivatives = FALSE
)
```

Use the
[`regex()`](https://bbuchsbaum.github.io/openneuroR/reference/regex.md)
helper for subject selection:

``` r
on_download(
  id = "ds000001",
  subjects = regex("sub-0[1-5]")
)
```

### Discover and download derivatives

``` r
derivs <- on_derivatives("ds000001")
derivs[, c("dataset_id", "pipeline", "source")]

spaces <- on_spaces(derivs[1, ])
spaces
```

Download fMRIPrep outputs for selected subjects in a specific space:

``` r
on_download_derivatives(
  dataset_id = "ds000001",
  pipeline = "fmriprep",
  subjects = c("01", "02"),
  space = "MNI152NLin2009cAsym"
)
```

### Work lazily with handles

If you want to define a dataset reference first and fetch it later, use
a handle:

``` r
handle <- on_handle("ds000001", files = "participants.tsv")
handle <- on_fetch(handle)
path <- on_path(handle)
```

This pattern is useful in pipelines where data should only be downloaded
when it is actually needed.

### Bridge into BIDS-aware workflows

If you use [`bidser`](https://cran.r-project.org/package=bidser), a
fetched handle can be converted into a BIDS project:

``` r
handle <- on_handle("ds000001")
handle <- on_fetch(handle)
bids <- on_bids(handle)
```

## Core Functions

| Function                                                                                                                                                                                                                                                                      | Purpose                                               |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| [`on_search()`](https://bbuchsbaum.github.io/openneuroR/reference/on_search.md)                                                                                                                                                                                               | Search or list datasets                               |
| [`on_dataset()`](https://bbuchsbaum.github.io/openneuroR/reference/on_dataset.md)                                                                                                                                                                                             | Retrieve dataset metadata                             |
| [`on_snapshots()`](https://bbuchsbaum.github.io/openneuroR/reference/on_snapshots.md)                                                                                                                                                                                         | List versioned dataset snapshots                      |
| [`on_files()`](https://bbuchsbaum.github.io/openneuroR/reference/on_files.md)                                                                                                                                                                                                 | List files within a dataset                           |
| [`on_subjects()`](https://bbuchsbaum.github.io/openneuroR/reference/on_subjects.md)                                                                                                                                                                                           | List subjects in a dataset                            |
| [`on_download()`](https://bbuchsbaum.github.io/openneuroR/reference/on_download.md)                                                                                                                                                                                           | Download raw data, specific files, or subject subsets |
| [`on_derivatives()`](https://bbuchsbaum.github.io/openneuroR/reference/on_derivatives.md)                                                                                                                                                                                     | Discover available derivative datasets                |
| [`on_spaces()`](https://bbuchsbaum.github.io/openneuroR/reference/on_spaces.md)                                                                                                                                                                                               | Inspect output spaces for derivatives                 |
| [`on_download_derivatives()`](https://bbuchsbaum.github.io/openneuroR/reference/on_download_derivatives.md)                                                                                                                                                                   | Download derivative outputs                           |
| [`on_handle()`](https://bbuchsbaum.github.io/openneuroR/reference/on_handle.md) / [`on_fetch()`](https://bbuchsbaum.github.io/openneuroR/reference/on_fetch.md)                                                                                                               | Create and materialize lazy dataset handles           |
| [`on_cache_info()`](https://bbuchsbaum.github.io/openneuroR/reference/on_cache_info.md) / [`on_cache_list()`](https://bbuchsbaum.github.io/openneuroR/reference/on_cache_list.md) / [`on_cache_clear()`](https://bbuchsbaum.github.io/openneuroR/reference/on_cache_clear.md) | Inspect and manage the local cache                    |
| [`on_bids()`](https://bbuchsbaum.github.io/openneuroR/reference/on_bids.md)                                                                                                                                                                                                   | Convert a fetched dataset to a `bidser` BIDS project  |

## Cache And Download Behavior

By default, downloads go into a local cache. Repeated downloads skip
files that are already present and tracked in the manifest, which makes
it practical to:

- pull just a few files for exploration
- expand a partial download later
- revisit the same dataset without starting from scratch

Use the cache helpers to inspect or clean up local state:

``` r
on_cache_info()
on_cache_list()
on_cache_clear("ds000001", confirm = FALSE)
```

## Learn More

- [Getting started
  vignette](https://bbuchsbaum.github.io/openneuroR/articles/getting-started.html)
- [End-to-end OpenNeuro + fMRIPrepper
  workflow](https://bbuchsbaum.github.io/openneuroR/articles/openneuro-fmriprepper-e2e.html)
- [Package news](https://bbuchsbaum.github.io/openneuroR/NEWS.md)

## License

MIT
