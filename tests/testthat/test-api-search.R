# Tests for api-search.R - on_search() functionality

test_that("on_search returns tibble with expected columns", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_search(limit = 3)
    expect_s3_class(result, "tbl_df")
    expect_named(result, c("id", "name", "created", "public", "modalities", "n_subjects", "tasks"))
    expect_true(nrow(result) >= 1)
  })
})

test_that("on_search returns datasets with valid data types", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_search(limit = 3)

    expect_type(result$id, "character")
    expect_type(result$name, "character")
    expect_s3_class(result$created, "POSIXct")
    expect_type(result$public, "logical")
    expect_type(result$modalities, "list")
    expect_type(result$n_subjects, "integer")
    expect_type(result$tasks, "list")
  })
})

test_that("on_search respects limit parameter", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_search(limit = 3)
    # We can't guarantee exact count (API may return fewer), but should not exceed limit
    expect_true(nrow(result) <= 3)
  })
})

test_that("on_search dataset IDs start with 'ds'", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_search(limit = 3)
    expect_true(all(grepl("^ds", result$id)))
  })
})
