# Tests for discovery-github.R - parsing and helpers

test_that(".parse_derivative_repo parses ds######-pipeline repo names", {
  repo <- list(
    name = "ds000001-qsiprep",
    pushed_at = "2024-01-01T00:00:00Z",
    size = 123
  )

  parsed <- .parse_derivative_repo(repo)

  expect_type(parsed, "list")
  expect_equal(parsed$dataset_id, "ds000001")
  expect_equal(parsed$pipeline, "qsiprep")
  expect_equal(parsed$repo_name, "ds000001-qsiprep")
})

test_that(".parse_derivative_repo allows hyphens, underscores, and dots in pipeline", {
  repo <- list(
    name = "ds000123-fmriprep-long_v1.2",
    pushed_at = NULL,
    size = NULL
  )

  parsed <- .parse_derivative_repo(repo)

  expect_equal(parsed$dataset_id, "ds000123")
  expect_equal(parsed$pipeline, "fmriprep-long_v1.2")
})

test_that(".parse_derivative_repo returns NULL for non-matching repos", {
  expect_null(.parse_derivative_repo(list(name = "README")))
  expect_null(.parse_derivative_repo(list(name = "ds000001")))
  expect_null(.parse_derivative_repo(list(name = "ds000001-")))
  expect_null(.parse_derivative_repo(list(name = "ds000001-!*bad")))
})

test_that(".github_is_transient detects rate limit responses", {
  local_mocked_bindings(
    resp_status = function(...) 403L,
    resp_header = function(resp, header) {
      if (identical(header, "X-RateLimit-Remaining")) "0" else NULL
    },
    .package = "httr2"
  )
  expect_true(.github_is_transient(list()))

  local_mocked_bindings(
    resp_status = function(...) 403L,
    resp_header = function(resp, header) {
      if (identical(header, "X-RateLimit-Remaining")) "1" else NULL
    },
    .package = "httr2"
  )
  expect_false(.github_is_transient(list()))
})

test_that(".github_after returns a non-negative delay", {
  local_mocked_bindings(
    resp_header = function(resp, header) {
      if (identical(header, "X-RateLimit-Reset")) {
        as.character(as.numeric(Sys.time()) + 5)
      } else {
        NULL
      }
    },
    .package = "httr2"
  )
  delay <- .github_after(list())
  expect_true(is.numeric(delay))
  expect_true(delay >= 0)
  expect_true(delay <= 6)

  local_mocked_bindings(
    resp_header = function(resp, header) NULL,
    .package = "httr2"
  )
  expect_equal(.github_after(list()), 60)
})

test_that(".github_rate_limit_error aborts with informative class", {
  local_mocked_bindings(
    resp_header = function(resp, header) {
      if (identical(header, "X-RateLimit-Reset")) {
        as.character(as.numeric(Sys.time()) + 60)
      } else {
        NULL
      }
    },
    .package = "httr2"
  )

  expect_error(.github_rate_limit_error(list()), class = "openneuro_rate_limit_error")
})

test_that(".github_request includes expected headers and optional auth", {
  withr::local_envvar(GITHUB_PAT = NA_character_)
  withr::local_envvar(GITHUB_TOKEN = NA_character_)

  req <- .github_request("/orgs/OpenNeuroDerivatives/repos", per_page = 1, page = 1)
  expect_s3_class(req, "httr2_request")
  expect_true(grepl("api\\.github\\.com", req$url))
  expect_true("User-Agent" %in% names(req$headers))
  expect_true("Accept" %in% names(req$headers))
  expect_false("Authorization" %in% names(req$headers))

  withr::local_envvar(GITHUB_PAT = "abc123")
  req2 <- .github_request("/orgs/OpenNeuroDerivatives/repos", per_page = 1, page = 1)
  expect_true("Authorization" %in% names(req2$headers))
})
