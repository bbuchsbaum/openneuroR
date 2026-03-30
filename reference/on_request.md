# Execute GraphQL Query

Executes a GraphQL query against the OpenNeuro API. Handles
authentication, retry logic, rate limiting, and error handling.

## Usage

``` r
on_request(query, variables = NULL, client = NULL)
```

## Arguments

- query:

  A GraphQL query string.

- variables:

  A named list of variables to pass to the query.

- client:

  An `openneuro_client` object. If `NULL`, creates a default client.

## Value

The `data` field from the GraphQL response.

## Details

The function implements several reliability features:

- Automatic retry on transient errors (429, 500, 502, 503)

- Rate limiting (10 requests per minute)

- User-Agent header for API identification

- Bearer token authentication when available

GraphQL errors (returned with HTTP 200 status) are detected and raised
as R errors with class `openneuro_api_error`.

## See also

[`on_client()`](https://bbuchsbaum.github.io/openneuroR/reference/on_client.md)
for creating client objects

## Examples

``` r
if (FALSE) { # \dontrun{
# Execute a simple query
query <- "query { datasets(first: 1) { edges { node { id } } } }"
result <- on_request(query)
} # }
```
