# Create OpenNeuro API Client

Creates a client object for accessing the OpenNeuro GraphQL API. The
client stores configuration including the API endpoint URL and optional
authentication token.

## Usage

``` r
on_client(url = "https://openneuro.org/crn/graphql", token = NULL)
```

## Arguments

- url:

  API endpoint URL. Defaults to the OpenNeuro GraphQL endpoint.

- token:

  API token for authentication. Defaults to the value of the
  `OPENNEURO_API_KEY` environment variable, or `NULL` if not set.
  Authentication is optional for read-only access to public datasets.

## Value

An `openneuro_client` object (S3 class) containing:

- url:

  The API endpoint URL

- token:

  The authentication token (or NULL)

## See also

[`on_request()`](https://bbuchsbaum.github.io/openneuroR/reference/on_request.md)
for executing queries with the client

## Examples

``` r
# Create client with default settings
client <- on_client()
print(client)
#> <openneuro_client>
#> URL: <https://openneuro.org/crn/graphql>
#> Authenticated: FALSE

# Create client with custom endpoint
client <- on_client(url = "https://staging.openneuro.org/crn/graphql")
```
