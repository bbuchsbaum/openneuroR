# Tests for api-files.R - on_files() functionality

test_that("on_files returns tibble with file information", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    # on_files will first call on_snapshots to get latest tag, then get files
    result <- on_files("ds000001")
    expect_s3_class(result, "tbl_df")
    expect_true(nrow(result) >= 1)
    expect_true("filename" %in% names(result))
    expect_true("size" %in% names(result))
    expect_true("directory" %in% names(result))
    expect_true("annexed" %in% names(result))
    expect_true("key" %in% names(result))
  })
})

test_that("on_files returns valid data types", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_files("ds000001")

    expect_type(result$filename, "character")
    expect_type(result$size, "double")
    expect_type(result$directory, "logical")
    expect_type(result$annexed, "logical")
    expect_type(result$key, "character")
  })
})

test_that("on_files includes both files and directories", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_files("ds000001")

    # ds000001 has files (like dataset_description.json) and directories (like sub-01)
    files <- result[!result$directory, ]
    dirs <- result[result$directory, ]

    expect_true(nrow(files) >= 1)
    expect_true(nrow(dirs) >= 1)
  })
})

test_that("on_files shows expected root files for ds000001", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_files("ds000001")

    # ds000001 should have standard BIDS files
    expect_true("dataset_description.json" %in% result$filename)
    expect_true("participants.tsv" %in% result$filename)
  })
})

test_that("on_files throws error for invalid ID", {
  expect_error(on_files(""), class = "openneuro_validation_error")
})

# --- Mocked tests for edge cases ---

test_that("on_files uses explicit tag parameter", {
  tag_used <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_request = function(gql, variables, client) {
      tag_used <<- variables$tag
      list(snapshot = list(files = list(
        list(filename = "test.txt", size = 100, directory = FALSE,
             annexed = FALSE, key = "k1")
      )))
    },
    .on_read_gql = function(name) "query { }"
  )

  result <- on_files("ds000001", tag = "1.0.0")
  expect_equal(tag_used, "1.0.0")
  expect_s3_class(result, "tbl_df")
})

test_that("on_files explores subdirectory with tree parameter", {
  tree_used <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_snapshots = function(id, client) tibble::tibble(tag = "1.0.0", created = Sys.time(), size = 0),
    on_request = function(gql, variables, client) {
      tree_used <<- variables$tree
      list(snapshot = list(files = list(
        list(filename = "file_in_subdir.txt", size = 50, directory = FALSE,
             annexed = FALSE, key = "k2")
      )))
    },
    .on_read_gql = function(name) "query { }"
  )

  result <- on_files("ds000001", tree = "sub-01_key")
  expect_equal(tree_used, "sub-01_key")
  expect_s3_class(result, "tbl_df")
})

test_that("on_files handles snapshot not found error", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_snapshots = function(id, client) tibble::tibble(tag = "1.0.0", created = Sys.time(), size = 0),
    on_request = function(gql, variables, client) {
      rlang::abort(
        "Snapshot does not exist",
        class = "openneuro_api_error"
      )
    },
    .on_read_gql = function(name) "query { }"
  )

  expect_error(
    on_files("ds000001", tag = "nonexistent"),
    class = "openneuro_not_found_error"
  )
})

test_that("on_files re-signals non-matching API errors", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_snapshots = function(id, client) tibble::tibble(tag = "1.0.0", created = Sys.time(), size = 0),
    on_request = function(gql, variables, client) {
      rlang::abort(
        "Internal server error",
        class = "openneuro_api_error"
      )
    },
    .on_read_gql = function(name) "query { }"
  )

  expect_error(
    on_files("ds000001"),
    class = "openneuro_api_error"
  )
})

test_that("on_files handles null snapshot response", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_snapshots = function(id, client) tibble::tibble(tag = "1.0.0", created = Sys.time(), size = 0),
    on_request = function(gql, variables, client) {
      list(snapshot = NULL)  # Null response
    },
    .on_read_gql = function(name) "query { }"
  )

  expect_error(
    on_files("ds000001"),
    class = "openneuro_not_found_error"
  )
})
