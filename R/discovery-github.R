#' GitHub API Integration for Discovery
#'
#' Internal functions for querying the GitHub API to discover
#' OpenNeuroDerivatives repositories. Includes rate limit handling
#' and session caching.
#'
#' @name discovery-github
#' @keywords internal
NULL

#' Check if GitHub Error is Transient (Rate Limited)
#'
#' Determines if a GitHub API response represents a transient
#' rate limit error that should be retried.
#'
#' @param resp An httr2 response object.
#'
#' @return `TRUE` if the error is a transient rate limit error,
#'   `FALSE` otherwise.
#'
#' @keywords internal
.github_is_transient <- function(resp) {
  # Rate limit exceeded: 403 with X-RateLimit-Remaining: 0
  if (httr2::resp_status(resp) == 403L) {
    remaining <- httr2::resp_header(resp, "X-RateLimit-Remaining")
    return(!is.null(remaining) && remaining == "0")
  }
  FALSE
}

#' Calculate Retry Delay for Rate Limited Response
#'
#' Calculates how many seconds to wait before retrying a
#' rate-limited GitHub API request.
#'
#' @param resp An httr2 response object.
#'
#' @return Number of seconds to wait before retry (minimum 0).
#'
#' @keywords internal
.github_after <- function(resp) {
  reset_header <- httr2::resp_header(resp, "X-RateLimit-Reset")
  if (is.null(reset_header)) {
    return(60)
  }

  reset_time <- as.numeric(reset_header)
  now <- as.numeric(Sys.time())
  max(0, reset_time - now)
}

#' Raise Rate Limit Error with Details
#'
#' Creates an informative error when GitHub rate limit is exceeded,
#' including reset time and suggestions for authentication.
#'
#' @param resp An httr2 response object.
#'
#' @return Does not return; raises an error with class
#'   `openneuro_rate_limit_error`.
#'
#' @keywords internal
.github_rate_limit_error <- function(resp) {
  reset_header <- httr2::resp_header(resp, "X-RateLimit-Reset")
  if (!is.null(reset_header)) {
    reset_time <- as.POSIXct(as.numeric(reset_header), origin = "1970-01-01", tz = "UTC")
    wait_secs <- max(0, as.numeric(reset_time) - as.numeric(Sys.time()))
    wait_mins <- round(wait_secs / 60, 1)
    reset_str <- format(reset_time, "%H:%M:%S %Z")
  } else {
    reset_str <- "unknown"
    wait_mins <- "unknown"
  }

  rlang::abort(
    c(
      "GitHub API rate limit exceeded",
      "x" = "No remaining requests (60/hour for unauthenticated)",
      "i" = paste0("Rate limit resets at: ", reset_str),
      "i" = paste0("Wait approximately: ", wait_mins, " minutes"),
      "i" = "Set GITHUB_PAT environment variable for higher limits (5000/hr)"
    ),
    class = "openneuro_rate_limit_error"
  )
}

#' Create GitHub API Request
#'
#' Builds an httr2 request to the GitHub API with proper headers,
#' rate limiting, and retry configuration.
#'
#' @param endpoint The API endpoint path (e.g., "/orgs/OpenNeuroDerivatives/repos").
#' @param ... Additional query parameters.
#'
#' @return An httr2 request object ready for execution.
#'
#' @keywords internal
.github_request <- function(endpoint, ...) {
  # Get package version for User-Agent
  pkg_version <- tryCatch(
    as.character(utils::packageVersion("openneuro")),
    error = function(e) "dev"
  )

  # Check for GITHUB_PAT or GITHUB_TOKEN
  token <- Sys.getenv("GITHUB_PAT", unset = "")
  if (token == "") {
    token <- Sys.getenv("GITHUB_TOKEN", unset = "")
  }

  req <- httr2::request("https://api.github.com") |>
    httr2::req_url_path_append(endpoint) |>
    httr2::req_url_query(...) |>
    httr2::req_headers(
      "User-Agent" = paste0("openneuro-r/", pkg_version),
      "Accept" = "application/vnd.github+json"
    ) |>
    httr2::req_retry(
      is_transient = .github_is_transient,
      after = .github_after,
      max_tries = 3
    ) |>
    httr2::req_throttle(rate = 30 / 60)  # 30 per minute to stay under 60/hr

  # Add authentication if token available
if (token != "") {
    req <- httr2::req_auth_bearer_token(req, token)
  }

  req
}

#' Parse Derivative Repository Information
#'
#' Extracts relevant information from a GitHub repository object,
#' filtering for valid derivative repositories (those matching the
#' pattern ds######-pipeline).
#'
#' @param repo A repository object from GitHub API response.
#'
#' @return A list with `dataset_id`, `pipeline`, `repo_name`,
#'   `pushed_at`, and `size_kb`; or `NULL` if the repository
#'   name doesn't match the derivative pattern.
#'
#' @keywords internal
.parse_derivative_repo <- function(repo) {
  name <- repo$name
  if (is.null(name)) {
    return(NULL)
  }

  # Match pattern: ds######-(fmriprep|mriqc|fitlins)
  pattern <- "^(ds\\d{6})-(fmriprep|mriqc|fitlins)$"
  match <- regmatches(name, regexec(pattern, name))[[1]]

  if (length(match) < 3) {
    return(NULL)
  }

  list(
    dataset_id = match[2],
    pipeline = match[3],
    repo_name = name,
    pushed_at = repo$pushed_at %||% NA_character_,
    size_kb = repo$size %||% NA_integer_
  )
}

#' List OpenNeuroDerivatives Repositories
#'
#' Retrieves all derivative repositories from the OpenNeuroDerivatives
#' GitHub organization, with pagination and caching.
#'
#' @param refresh If `TRUE`, bypass cache and fetch fresh data.
#'   Default is `FALSE`.
#'
#' @return A list of parsed repository information, each containing
#'   `dataset_id`, `pipeline`, `repo_name`, `pushed_at`, and `size_kb`.
#'
#' @details
#' Results are cached for the session to minimize API calls. GitHub
#' API rate limits apply (60/hour unauthenticated, 5000/hour with
#' `GITHUB_PAT` environment variable set).
#'
#' The OpenNeuroDerivatives organization contains 700+ repositories,
#' requiring pagination (100 per page) to retrieve all results.
#'
#' @keywords internal
.list_openneuro_derivatives_repos <- function(refresh = FALSE) {
  cache_key <- "openneuro_derivatives_repos"

  # Return cached result if available and refresh not requested
  if (!refresh && .discovery_cache$has(cache_key)) {
    return(.discovery_cache$get(cache_key))
  }

  # Paginate through all repositories
  all_repos <- list()
  page <- 1
  per_page <- 100

  repeat {
    req <- .github_request(
      "/orgs/OpenNeuroDerivatives/repos",
      per_page = per_page,
      page = page,
      sort = "pushed",
      direction = "desc"
    )

    # Execute request with error handling
    resp <- tryCatch(
      httr2::req_perform(req),
      error = function(e) {
        # Check if it's a rate limit error we should report
        if (inherits(e, "httr2_http_403")) {
          .github_rate_limit_error(e$resp)
        }
        rlang::abort(
          c(
            "GitHub API request failed",
            "x" = conditionMessage(e)
          ),
          class = "openneuro_github_error",
          parent = e
        )
      }
    )

    # Parse response
    repos <- httr2::resp_body_json(resp)

    # Empty response means we've reached the end
    if (length(repos) == 0) {
      break
    }

    # Parse each repository
    for (repo in repos) {
      parsed <- .parse_derivative_repo(repo)
      if (!is.null(parsed)) {
        all_repos <- c(all_repos, list(parsed))
      }
    }

    # Check for Link header to see if there are more pages
    link_header <- httr2::resp_header(resp, "Link")
    if (is.null(link_header) || !grepl('rel="next"', link_header)) {
      break
    }

    page <- page + 1
  }

  # Cache the results
  .discovery_cache$set(cache_key, all_repos)

  all_repos
}
