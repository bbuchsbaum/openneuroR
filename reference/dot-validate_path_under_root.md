# Validate Path is Under Expected Root

Verifies that a resolved path does not escape the expected parent
directory (prevents path traversal attacks via ".." segments).

## Usage

``` r
.validate_path_under_root(path, root)
```

## Arguments

- path:

  The path to validate.

- root:

  The expected parent directory.

## Value

`TRUE` invisibly if safe; aborts if path escapes root.
