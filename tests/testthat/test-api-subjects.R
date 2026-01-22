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
  # Test with a mock that returns empty subjects array
  skip("Requires mock for non-BIDS dataset")
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
