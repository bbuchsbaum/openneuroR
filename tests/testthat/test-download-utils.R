# Tests for download-utils.R helper functions
# Uses withr for temp file/directory isolation

# --- .construct_download_url tests ---

test_that(".construct_download_url builds basic URL correctly", {
  result <- .construct_download_url("ds000001", "README.md")
  expect_equal(result, "https://s3.amazonaws.com/openneuro.org/ds000001/README.md")
})

test_that(".construct_download_url handles nested directory paths", {
  result <- .construct_download_url("ds000001", "sub-01/anat/T1w.nii.gz")
  expect_equal(result, "https://s3.amazonaws.com/openneuro.org/ds000001/sub-01/anat/T1w.nii.gz")
})

test_that(".construct_download_url encodes special characters", {
  # Spaces should be encoded
  result <- .construct_download_url("ds000001", "sub-01/file with spaces.txt")
  expect_true(grepl("file%20with%20spaces.txt", result))

  # Verify forward slashes are preserved
  expect_true(grepl("sub-01/", result))
})

test_that(".construct_download_url encodes reserved characters", {
  # Plus signs and other reserved chars should be encoded
  result <- .construct_download_url("ds000001", "data+file.txt")
  expect_true(grepl("%2B", result))  # + encodes to %2B
})

# --- .validate_existing_file tests ---

test_that(".validate_existing_file returns FALSE for non-existent file", {
  fake_path <- file.path(withr::local_tempdir(), "does_not_exist.txt")
  result <- .validate_existing_file(fake_path, expected_size = 100)
  expect_false(result)
})

test_that(".validate_existing_file returns TRUE for correct size", {
  tmp <- withr::local_tempfile()
  writeLines("hello", tmp)  # Creates file with specific content
  actual_size <- file.info(tmp)$size

  result <- .validate_existing_file(tmp, expected_size = actual_size)
  expect_true(result)
})

test_that(".validate_existing_file returns FALSE for wrong size", {
  tmp <- withr::local_tempfile()
  writeLines("hello", tmp)
  actual_size <- file.info(tmp)$size

  # Pass wrong expected size
  result <- .validate_existing_file(tmp, expected_size = actual_size + 100)
  expect_false(result)
})

test_that(".validate_existing_file handles zero-byte files", {
  tmp <- withr::local_tempfile()
  file.create(tmp)  # Creates empty file

  result <- .validate_existing_file(tmp, expected_size = 0)
  expect_true(result)
})

# --- .ensure_dest_dir tests ---

test_that(".ensure_dest_dir creates directory when it doesn't exist", {
  tmp <- withr::local_tempdir()
  new_dir <- file.path(tmp, "new_subdir")
  expect_false(dir.exists(new_dir))

  result <- .ensure_dest_dir(new_dir, dataset_id = "ds000001")
  expect_true(dir.exists(result))
})

test_that(".ensure_dest_dir uses dataset_id when dest_dir is NULL", {
  # Mock getwd() to return a temp directory
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)

  result <- .ensure_dest_dir(NULL, dataset_id = "ds000001")
  expect_true(grepl("ds000001$", result))
  expect_true(dir.exists(result))
})

test_that(".ensure_dest_dir returns absolute path", {
  tmp <- withr::local_tempdir()
  result <- .ensure_dest_dir(tmp, dataset_id = "ds000001")

  # fs::path_abs returns absolute path - should not start with ./ or ../
  expect_false(grepl("^\\.\\.?/", result))
  # On Unix systems, absolute paths start with /
  # On Windows, they start with drive letter (C:) or UNC path
  expect_true(grepl("^(/|[A-Za-z]:)", result))
})

test_that(".ensure_dest_dir handles existing directory", {
  tmp <- withr::local_tempdir()
  existing_dir <- file.path(tmp, "existing")
  dir.create(existing_dir)

  # Create a file inside to verify directory isn't recreated
  test_file <- file.path(existing_dir, "test.txt")
  writeLines("content", test_file)

  result <- .ensure_dest_dir(existing_dir, dataset_id = "ds000001")
  expect_true(dir.exists(result))
  expect_true(file.exists(test_file))  # Original content preserved
})
