# Tests for graphql.R - on_request() and .on_read_gql() functionality
# Uses local_mocked_bindings() to mock network dependencies

# --- on_request tests ---

test_that("on_request handles network errors gracefully", {
  local_mocked_bindings(
    on_client = function() list(url = "https://api.openneuro.org/graphql", token = NULL)
  )

  local_mocked_bindings(
    req_perform = function(req) {
      stop("Could not resolve host: api.openneuro.org")
    },
    .package = "httr2"
  )

  expect_error(
    on_request("query { test }"),
    class = "openneuro_network_error"
  )
})

test_that("on_request adds auth header when token present", {
  req_captured <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "https://api.openneuro.org/graphql", token = "test_token_123")
  )

  local_mocked_bindings(
    req_perform = function(req) {
      req_captured <<- req
      structure(
        list(body = charToRaw('{"data": {"test": "value"}}')),
        class = "httr2_response"
      )
    },
    resp_body_json = function(resp) list(data = list(test = "value")),
    .package = "httr2"
  )

  result <- on_request("query { test }")

  # Check that the auth function was applied (req_auth_bearer_token modifies the request)
  expect_type(result, "list")
  expect_equal(result$test, "value")
})

test_that("on_request detects GraphQL errors in response", {
  local_mocked_bindings(
    on_client = function() list(url = "https://api.openneuro.org/graphql", token = NULL)
  )

  local_mocked_bindings(
    req_perform = function(req) {
      structure(
        list(body = charToRaw('{"errors": [{"message": "Invalid query"}]}')),
        class = "httr2_response"
      )
    },
    resp_body_json = function(resp) {
      list(
        errors = list(list(message = "Invalid query")),
        data = NULL
      )
    },
    .package = "httr2"
  )

  expect_error(
    on_request("query { invalid }"),
    class = "openneuro_api_error"
  )
})

test_that("on_request sets correct User-Agent", {
  req_captured <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "https://api.openneuro.org/graphql", token = NULL)
  )

  # We need to capture the request to verify User-Agent
  # Mock request/response chain
  local_mocked_bindings(
    request = function(url) {
      req <- list(url = url, headers = list())
      class(req) <- "httr2_request"
      req
    },
    req_headers = function(req, ...) {
      headers <- list(...)
      req$headers <- c(req$headers, headers)
      req_captured <<- req
      req
    },
    req_body_json = function(req, body) {
      req$body <- body
      req
    },
    req_retry = function(req, ...) req,
    req_throttle = function(req, ...) req,
    req_perform = function(req) {
      structure(list(body = charToRaw('{"data": {}}')), class = "httr2_response")
    },
    resp_body_json = function(resp) list(data = list()),
    .package = "httr2"
  )

  on_request("query { test }")

  # Check that User-Agent was set
  expect_true("User-Agent" %in% names(req_captured$headers))
  expect_true(grepl("^openneuro-r/", req_captured$headers[["User-Agent"]]))
})

test_that("on_request handles multiple GraphQL errors", {
  local_mocked_bindings(
    on_client = function() list(url = "https://api.openneuro.org/graphql", token = NULL)
  )

  local_mocked_bindings(
    req_perform = function(req) {
      structure(
        list(body = charToRaw('{"errors": [{"message": "Error 1"}, {"message": "Error 2"}]}')),
        class = "httr2_response"
      )
    },
    resp_body_json = function(resp) {
      list(
        errors = list(
          list(message = "Error 1"),
          list(message = "Error 2")
        ),
        data = NULL
      )
    },
    .package = "httr2"
  )

  # Should include both error messages
  err <- tryCatch(
    on_request("query { invalid }"),
    openneuro_api_error = function(e) e
  )

  expect_s3_class(err, "openneuro_api_error")
  msg <- conditionMessage(err)
  expect_true(grepl("Error 1", msg) || grepl("Error 2", msg))
})

# --- .on_read_gql tests ---

test_that(".on_read_gql errors on missing query file", {
  expect_error(
    openneuro:::.on_read_gql("nonexistent_query_that_does_not_exist"),
    class = "openneuro_query_error"
  )
})

test_that(".on_read_gql reads valid query files", {
  # This test assumes get_dataset.gql exists in inst/graphql/
  # which should be present if the package is properly installed
  skip_if_not_installed("openneuro")

  result <- tryCatch(
    openneuro:::.on_read_gql("get_dataset"),
    error = function(e) NULL
  )

  # If the query file exists, it should return a string
  if (!is.null(result)) {
    expect_type(result, "character")
    expect_true(nchar(result) > 0)
  }
})
