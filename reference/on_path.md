# Get Path from Handle

Returns the filesystem path for a fetched handle. Raises an error if the
handle has not been fetched yet.

## Usage

``` r
on_path(handle)

# S3 method for class 'openneuro_handle'
on_path(handle)
```

## Arguments

- handle:

  An object to get the path from. For `openneuro_handle` objects,
  returns the download location.

## Value

Character string with the filesystem path.

## See also

[`on_handle()`](https://bbuchsbaum.github.io/openneuroR/reference/on_handle.md)
to create a handle,
[`on_fetch()`](https://bbuchsbaum.github.io/openneuroR/reference/on_fetch.md)
to materialize.

## Examples

``` r
if (FALSE) { # \dontrun{
handle <- on_handle("ds000001")
handle <- on_fetch(handle)
path <- on_path(handle)
list.files(path)
} # }
```
