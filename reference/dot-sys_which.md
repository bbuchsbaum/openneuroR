# Wrapper for Sys.which

Wraps Sys.which to enable mocking in tests.

## Usage

``` r
.sys_which(names)
```

## Arguments

- names:

  Character vector of command names to find.

## Value

Named character vector with paths (or empty strings).
