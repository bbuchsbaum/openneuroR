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
