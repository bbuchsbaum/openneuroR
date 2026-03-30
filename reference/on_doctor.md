# OpenNeuro Backend Diagnostics

Reports the status of all available download backends, showing which are
installed, their versions, and readiness for use.

## Usage

``` r
on_doctor()
```

## Value

Invisibly returns an object of class `openneuro_doctor` containing:

- https:

  List with available (always TRUE), version (NA)

- s3:

  List with available (logical), version (character or NA)

- datalad:

  List with available (logical), version (character or NA)

## Examples

``` r
on_doctor()
#> 
#> ── OpenNeuro Backend Status ────────────────────────────────────────────────────
#> 
#> Required:
#> ✔ HTTPS (always available)
#> 
#> Optional:
#> ✔ AWS CLI "2.34.15"
#> ✖ DataLad not installed
#> Install: `pip install datalad`
```
