# Tests for api-dataset.R - on_dataset() and on_snapshots() functionality

test_that("on_dataset returns tibble with dataset metadata", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_dataset("ds000001")
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 1)
    expect_true("id" %in% names(result))
    expect_true("name" %in% names(result))
    expect_true("created" %in% names(result))
    expect_true("public" %in% names(result))
    expect_true("latest_snapshot" %in% names(result))
  })
})

test_that("on_dataset returns correct dataset ID", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_dataset("ds000001")
    expect_equal(result$id, "ds000001")
  })
})

test_that("on_dataset returns valid data types", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_dataset("ds000001")

    expect_type(result$id, "character")
    expect_type(result$name, "character")
    expect_s3_class(result$created, "POSIXct")
    expect_type(result$public, "logical")
    expect_type(result$latest_snapshot, "character")
  })
})

test_that("on_dataset throws error for invalid ID (empty)", {
  expect_error(on_dataset(""), class = "openneuro_validation_error")
})

test_that("on_dataset throws error for invalid ID (NULL)", {
  expect_error(on_dataset(NULL), class = "openneuro_validation_error")
})

test_that("on_snapshots returns tibble with snapshot information", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_snapshots("ds000001")
    expect_s3_class(result, "tbl_df")
    expect_true(nrow(result) >= 1)
    expect_true("tag" %in% names(result))
    expect_true("created" %in% names(result))
    expect_true("size" %in% names(result))
  })
})

test_that("on_snapshots returns valid data types", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_snapshots("ds000001")

    expect_type(result$tag, "character")
    expect_s3_class(result$created, "POSIXct")
    expect_type(result$size, "double")
  })
})

test_that("on_snapshots throws error for invalid ID", {
  expect_error(on_snapshots(""), class = "openneuro_validation_error")
})

# --- Mocked tests for on_dataset edge cases ---

test_that("on_dataset re-signals non-matching API errors", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_request = function(gql, variables, client) {
      rlang::abort(
        "Internal server error",
        class = "openneuro_api_error"
      )
    },
    .on_read_gql = function(name) "query { }"
  )

  expect_error(
    on_dataset("ds000001"),
    class = "openneuro_api_error"
  )
})

test_that("on_dataset handles null dataset response", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_request = function(gql, variables, client) {
      list(dataset = NULL)
    },
    .on_read_gql = function(name) "query { }"
  )

  expect_error(
    on_dataset("ds000001"),
    class = "openneuro_not_found_error"
  )
})

test_that("on_dataset handles missing latest snapshot", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_request = function(gql, variables, client) {
      list(dataset = list(
        id = "ds000001",
        name = "Test Dataset",
        created = "2024-01-15T12:00:00Z",
        public = TRUE,
        latestSnapshot = NULL  # No latest snapshot
      ))
    },
    .on_read_gql = function(name) "query { }"
  )

  result <- on_dataset("ds000001")
  expect_s3_class(result, "tbl_df")
  expect_true(is.na(result$latest_snapshot) || is.null(result$latest_snapshot))
})

# --- Mocked tests for on_snapshots edge cases ---

test_that("on_snapshots handles API error for dataset not found", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_request = function(gql, variables, client) {
      rlang::abort(
        "Dataset does not exist",
        class = "openneuro_api_error"
      )
    },
    .on_read_gql = function(name) "query { }"
  )

  expect_error(
    on_snapshots("ds999999"),
    class = "openneuro_not_found_error"
  )
})

test_that("on_snapshots re-signals non-matching API errors", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_request = function(gql, variables, client) {
      rlang::abort(
        "Internal server error",
        class = "openneuro_api_error"
      )
    },
    .on_read_gql = function(name) "query { }"
  )

  expect_error(
    on_snapshots("ds000001"),
    class = "openneuro_api_error"
  )
})

test_that("on_snapshots handles null dataset response", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_request = function(gql, variables, client) {
      list(dataset = NULL)
    },
    .on_read_gql = function(name) "query { }"
  )

  expect_error(
    on_snapshots("ds000001"),
    class = "openneuro_not_found_error"
  )
})

test_that("on_snapshots returns empty tibble for no snapshots", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_request = function(gql, variables, client) {
      list(dataset = list(
        id = "ds000001",
        snapshots = list()  # No snapshots
      ))
    },
    .on_read_gql = function(name) "query { }"
  )

  result <- on_snapshots("ds000001")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_true("tag" %in% names(result))
})

test_that("on_snapshots preserves API order for snapshots", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_request = function(gql, variables, client) {
      # API returns snapshots in most-recent-first order
      list(dataset = list(
        id = "ds000001",
        snapshots = list(
          list(tag = "2.0.0", created = "2024-06-01T00:00:00Z", size = 150),
          list(tag = "1.5.0", created = "2024-03-01T00:00:00Z", size = 120),
          list(tag = "1.0.0", created = "2024-01-01T00:00:00Z", size = 100)
        )
      ))
    },
    .on_read_gql = function(name) "query { }"
  )

  result <- on_snapshots("ds000001")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 3)
  # Snapshots should be in API order (most recent first from API)
  expect_equal(result$tag[1], "2.0.0")
  expect_equal(result$tag[2], "1.5.0")
  expect_equal(result$tag[3], "1.0.0")
})
