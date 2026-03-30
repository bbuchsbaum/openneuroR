# Get Cache Root Directory

Returns the root directory for openneuroR cache storage, using
CRAN-compliant location via
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html). Creates
the directory if it doesn't exist.

## Usage

``` r
.on_cache_root()
```

## Value

Path to the cache root directory.

## Details

Platform-appropriate paths:

- Mac: ~/Library/Caches/R/openneuroR

- Linux: ~/.cache/R/openneuroR

- Windows: ~/AppData/Local/R/cache/openneuroR

## Options

The cache root can be overridden by setting the `openneuro.cache_root`
option:

    options(openneuro.cache_root = "/custom/path")
