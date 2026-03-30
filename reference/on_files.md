# List Files in a Snapshot

Lists all files in a dataset snapshot. Can list the root directory or
drill into subdirectories using the `tree` parameter.

## Usage

``` r
on_files(id, tag = NULL, tree = NULL, client = NULL)
```

## Arguments

- id:

  Dataset identifier (e.g., "ds000001").

- tag:

  Snapshot version tag (e.g., "1.0.0"). If `NULL` (default), uses the
  most recent snapshot.

- tree:

  Subdirectory key for listing nested files. Use the `key` column from a
  previous call to explore subdirectories. Default `NULL` lists the root
  directory.

- client:

  An `openneuro_client` object. If `NULL`, creates a default client.

## Value

A tibble with columns:

- filename:

  Name of the file or directory

- size:

  File size in bytes (numeric), may be NA for directories

- directory:

  TRUE if this entry is a directory (logical)

- annexed:

  TRUE if file is stored in git-annex (logical). Annexed files are
  typically larger and require special download handling.

- key:

  Unique key for this entry. Use with `tree` parameter to explore
  subdirectories.

Returns an empty tibble with the same column structure if the snapshot
has no files.

## Details

OpenNeuro stores datasets using git-annex, where large files are stored
separately from the git repository. The `annexed` column indicates which
files use this storage method.

To explore a directory structure:

1.  Call `on_files()` to get the root listing

2.  Filter for `directory == TRUE` entries

3.  Use the `key` from a directory to call `on_files(tree = key)`

## See also

[`on_snapshots()`](https://bbuchsbaum.github.io/openneuroR/reference/on_snapshots.md)
to list available snapshots

## Examples

``` r
if (FALSE) { # \dontrun{
# List root files using latest snapshot
files <- on_files("ds000001")
print(files)

# List files in a specific snapshot
files <- on_files("ds000001", tag = "1.0.0")

# Explore a subdirectory
dirs <- files[files$directory, ]
if (nrow(dirs) > 0) {
  subfiles <- on_files("ds000001", tree = dirs$key[1])
  print(subfiles)
}

# Find all annexed (large) files
annexed_files <- files[files$annexed & !files$directory, ]
} # }
```
