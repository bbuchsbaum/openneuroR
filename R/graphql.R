#' Execute GraphQL Query
#'
#' Executes a GraphQL query against the OpenNeuro API. Handles authentication,
#' retry logic, rate limiting, and error handling.
#'
#' @param query A GraphQL query string.
#' @param variables A named list of variables to pass to the query.
#' @param client An `openneuro_client` object. If `NULL`, creates a default client.
#'
#' @return The `data` field from the GraphQL response.
#'
#' @details
#' The function implements several reliability features:
#' - Automatic retry on transient errors (429, 500, 502, 503)
#' - Rate limiting (10 requests per minute)
#' - User-Agent header for API identification
#' - Bearer token authentication when available
#'
#' GraphQL errors (returned with HTTP 200 status) are detected and raised

#' as R errors with class `openneuro_api_error`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Execute a simple query
#' query <- "query { datasets(first: 1) { edges { node { id } } } }"
#' result <- on_request(query)
#' }
#'
#' @seealso [on_client()] for creating client objects
on_request <- function(query, variables = NULL, client = NULL) {
  client <- client %||% on_client()

  body <- list(query = query)
  if (!is.null(variables)) {
    body$variables <- variables
  }

  # Get package version for User-Agent
  pkg_version <- tryCatch(
    as.character(utils::packageVersion("openneuro")),
    error = function(e) "0.1.0"
  )

  timeout <- getOption("openneuro.timeout", default = 60)

  req <- httr2::request(client$url) |>
    httr2::req_headers(
      "Content-Type" = "application/json",
      "User-Agent" = paste0("openneuro-r/", pkg_version)
    ) |>
    httr2::req_body_json(body) |>
    httr2::req_timeout(seconds = timeout) |>
    httr2::req_retry(
      max_tries = 3,
      is_transient = function(resp) httr2::resp_status(resp) %in% c(429L, 500L, 502L, 503L)
    ) |>
    httr2::req_throttle(rate = 10 / 60)  # 10 requests per minute

  # Add auth if available
  if (!is.null(client$token)) {
    req <- httr2::req_auth_bearer_token(req, client$token)
  }

  # Perform request with graceful network error handling
  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) {
      rlang::abort(
        c("Network error connecting to OpenNeuro",
          "i" = "Check your internet connection",
          "x" = conditionMessage(e)),
        class = "openneuro_network_error",
        parent = e
      )
    }
  )

  data <- httr2::resp_body_json(resp)

  # Check for GraphQL errors in response body (may come with HTTP 200)
  if (!is.null(data$errors)) {
    error_messages <- vapply(
      data$errors,
      function(e) e$message %||% "Unknown error",
      character(1)
    )
    rlang::abort(
      c("OpenNeuro API error",
        "i" = error_messages),
      class = "openneuro_api_error"
    )
  }

  data$data
}


#' Read GraphQL Query from File
#'
#' Internal function to load GraphQL queries from inst/graphql/ directory.
#'
#' @param name The query name (without .gql extension).
#'
#' @return The query string.
#'
#' @keywords internal
.on_read_gql <- function(name) {
  path <- system.file("graphql", paste0(name, ".gql"), package = "openneuro")
  if (path == "") {
    rlang::abort(
      c("Query file not found",
        "x" = paste0("No file found for query: ", name)),
      class = "openneuro_query_error"
    )
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}
