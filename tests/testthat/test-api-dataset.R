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
