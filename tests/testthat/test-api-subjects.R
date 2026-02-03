# Tests for api-subjects.R - on_subjects() functionality

test_that("on_subjects returns tibble with subject information", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_subjects("ds000001")
    expect_s3_class(result, "tbl_df")
    expect_true(nrow(result) >= 1)
    expect_true("subject_id" %in% names(result))
    expect_true("dataset_id" %in% names(result))
    expect_true("n_sessions" %in% names(result))
    expect_true("n_files" %in% names(result))
  })
})

test_that("on_subjects returns valid data types", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_subjects("ds000001")

    expect_type(result$dataset_id, "character")
    expect_type(result$subject_id, "character")
    expect_type(result$n_sessions, "integer")
    expect_type(result$n_files, "integer")
  })
})

test_that("on_subjects returns naturally sorted subjects", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_subjects("ds000001")
    # Extract numeric portions and verify order
    ids <- result$subject_id
    if (length(ids) > 1) {
      nums <- as.integer(gsub("^sub-0*|^0*", "", ids))
      expect_equal(nums, sort(nums))
    }
  })
})

test_that("on_subjects dataset_id matches input", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_subjects("ds000001")
    expect_true(all(result$dataset_id == "ds000001"))
  })
})

test_that("on_subjects throws error for invalid ID", {
  expect_error(on_subjects(""), class = "openneuro_validation_error")
  expect_error(on_subjects(NULL), class = "openneuro_validation_error")
})

test_that("on_subjects returns empty tibble for non-BIDS dataset", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_snapshots = function(id, client) tibble::tibble(tag = "1.0.0", created = Sys.time(), size = 0),
    on_request = function(gql, variables, client) {
      list(snapshot = list(
        summary = list(
          subjects = list(),  # No subjects - non-BIDS
          sessions = list(),
          totalFiles = 5L
        )
      ))
    },
    .on_read_gql = function(name) "query { }"
  )

  result <- on_subjects("ds999999")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_true("subject_id" %in% names(result))
})

# Test natural sorting helper function directly
test_that(".sort_subjects_natural sorts numerically", {
  # Test the natural sorting function
  unsorted <- c("sub-01", "sub-10", "sub-02", "sub-9")
  sorted <- openneuro:::.sort_subjects_natural(unsorted)
  expected <- c("sub-01", "sub-02", "sub-9", "sub-10")
  expect_equal(sorted, expected)
})

test_that(".sort_subjects_natural handles empty input", {
  expect_equal(openneuro:::.sort_subjects_natural(character()), character())
})

# --- Mocked tests for edge cases ---

test_that("on_subjects uses explicit tag parameter", {
  tag_used <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_request = function(gql, variables, client) {
      tag_used <<- variables$tag
      list(snapshot = list(
        summary = list(
          subjects = list("sub-01"),
          sessions = list(),
          totalFiles = 10L
        )
      ))
    },
    .on_read_gql = function(name) "query { }"
  )

  result <- on_subjects("ds000001", tag = "2.0.0")
  expect_equal(tag_used, "2.0.0")
  expect_s3_class(result, "tbl_df")
})

test_that("on_subjects handles API error gracefully", {
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
    on_subjects("ds000001", tag = "nonexistent"),
    class = "openneuro_not_found_error"
  )
})

test_that("on_subjects re-signals non-matching API errors", {
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
    on_subjects("ds000001"),
    class = "openneuro_api_error"
  )
})

test_that("on_subjects handles null snapshot response", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_snapshots = function(id, client) tibble::tibble(tag = "1.0.0", created = Sys.time(), size = 0),
    on_request = function(gql, variables, client) {
      list(snapshot = NULL)
    },
    .on_read_gql = function(name) "query { }"
  )

  expect_error(
    on_subjects("ds000001"),
    class = "openneuro_not_found_error"
  )
})
