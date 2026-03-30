## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Use of \dontrun{} in examples

All exported function examples use `\dontrun{}` because every example
requires either a live connection to the OpenNeuro GraphQL API
(<https://openneuro.org>) or interaction with the local file cache.
Neither resource is available during CRAN checks. There are no examples
that can run offline without side effects.

## Package purpose

'openneuro' provides programmatic access to the OpenNeuro neuroimaging
data repository (<https://openneuro.org>) from R. It queries the
OpenNeuro GraphQL API to search datasets, inspect metadata, and download
full datasets or selected subsets via HTTPS, S3, or DataLad backends.
