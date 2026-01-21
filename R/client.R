#' Create OpenNeuro API Client
#'
#' Creates a client object for accessing the OpenNeuro GraphQL API.
#' The client stores configuration including the API endpoint URL and
#' optional authentication token.
#'
#' @param url API endpoint URL. Defaults to the OpenNeuro GraphQL endpoint.
#' @param token API token for authentication. Defaults to the value of the
#'   `OPENNEURO_API_KEY` environment variable, or `NULL` if not set.
#'   Authentication is optional for read-only access to public datasets.
#'
#' @return An `openneuro_client` object (S3 class) containing:
#'   \describe{
#'     \item{url}{The API endpoint URL}
#'     \item{token}{The authentication token (or NULL)}
#'   }
#'
#' @export
#'
#' @examples
#' # Create client with default settings
#' client <- on_client()
#' print(client)
#'
#' # Create client with custom endpoint
#' client <- on_client(url = "https://staging.openneuro.org/crn/graphql")
#'
#' @seealso [on_request()] for executing queries with the client
on_client <- function(url = "https://openneuro.org/crn/graphql",
                      token = NULL) {
  token <- token %||% Sys.getenv("OPENNEURO_API_KEY", unset = NA)
  if (is.na(token) || token == "") token <- NULL

  structure(
    list(url = url, token = token),
    class = "openneuro_client"
  )
}

#' @export
print.openneuro_client <- function(x, ...) {
  cli::cli_text("<openneuro_client>")
  cli::cli_text("URL: {.url {x$url}}")
  cli::cli_text("Authenticated: {.val {!is.null(x$token)}}")
  invisible(x)
}
