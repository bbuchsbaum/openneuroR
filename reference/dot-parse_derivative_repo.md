# Parse Derivative Repository Information

Extracts relevant information from a GitHub repository object, filtering
for valid derivative repositories (those matching the pattern
ds######-pipeline).

## Usage

``` r
.parse_derivative_repo(repo)
```

## Arguments

- repo:

  A repository object from GitHub API response.

## Value

A list with `dataset_id`, `pipeline`, `repo_name`, `pushed_at`, and
`size_kb`; or `NULL` if the repository name doesn't match the derivative
pattern.
