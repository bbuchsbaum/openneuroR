# Tests for discovery-github.R pagination + cache behavior

test_that(".list_openneuro_derivatives_repos paginates and caches results", {
  .discovery_cache_clear()

  perform_calls <- 0L
  requested_pages <- integer()

  local_mocked_bindings(
    .github_request = function(endpoint, ...) {
      params <- list(...)
      page <- params$page
      if (is.null(page)) page <- 1L
      requested_pages <<- c(requested_pages, as.integer(page))
      list(page = as.integer(page))
    },
    .package = "openneuro"
  )

  local_mocked_bindings(
    req_perform = function(req) {
      perform_calls <<- perform_calls + 1L
      structure(list(page = req$page), class = "mock_resp")
    },
    resp_body_json = function(resp) {
      if (resp$page == 1L) {
        return(list(
          list(name = "ds000001-fmriprep", pushed_at = "2024-01-01T00:00:00Z", size = 1),
          list(name = "not-a-derivative", pushed_at = "2024-01-01T00:00:00Z", size = 1)
        ))
      }
      if (resp$page == 2L) {
        return(list(
          list(name = "ds000001-qsiprep", pushed_at = "2024-01-02T00:00:00Z", size = 2)
        ))
      }
      list()
    },
    resp_header = function(resp, header) {
      if (identical(header, "Link") && resp$page == 1L) {
        return("<https://api.github.com/orgs/OpenNeuroDerivatives/repos?page=2>; rel=\"next\"")
      }
      NULL
    },
    .package = "httr2"
  )

  repos1 <- .list_openneuro_derivatives_repos(refresh = FALSE)
  expect_equal(perform_calls, 2L)
  expect_equal(requested_pages, c(1L, 2L))
  expect_equal(length(repos1), 2L)
  expect_setequal(vapply(repos1, function(x) x$pipeline, character(1)), c("fmriprep", "qsiprep"))

  # Cached: no additional network calls
  repos2 <- .list_openneuro_derivatives_repos(refresh = FALSE)
  expect_equal(perform_calls, 2L)
  expect_equal(length(repos2), 2L)

  # Refresh: re-fetches pages
  repos3 <- .list_openneuro_derivatives_repos(refresh = TRUE)
  expect_equal(perform_calls, 4L)
  expect_equal(length(repos3), 2L)
})

test_that(".list_openneuro_derivatives_repos converts 403 to openneuro_rate_limit_error", {
  .discovery_cache_clear()

  local_mocked_bindings(
    .github_request = function(endpoint, ...) list(),
    .package = "openneuro"
  )

  local_mocked_bindings(
    req_perform = function(req) {
      cond <- structure(
        list(message = "Forbidden", call = NULL, resp = "resp"),
        class = c("httr2_http_403", "error", "condition")
      )
      stop(cond)
    },
    resp_header = function(resp, header) {
      if (identical(header, "X-RateLimit-Reset")) {
        as.character(as.numeric(Sys.time()) + 60)
      } else if (identical(header, "X-RateLimit-Remaining")) {
        "0"
      } else {
        NULL
      }
    },
    .package = "httr2"
  )

  expect_error(
    .list_openneuro_derivatives_repos(refresh = TRUE),
    class = "openneuro_rate_limit_error"
  )
})
