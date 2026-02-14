# Tests for download-file.R helper functions
# Uses local_mocked_bindings and withr for isolation

# --- .get_file_size tests ---

test_that(".get_file_size returns 0 for non-existent file", {
  fake_path <- file.path(withr::local_tempdir(), "does_not_exist.txt")
  result <- .get_file_size(fake_path)
  expect_equal(result, 0)
})

test_that(".get_file_size returns correct size for existing file", {
  tmp <- withr::local_tempfile()
  # Write exactly 26 bytes (known content)
  writeBin(charToRaw("abcdefghijklmnopqrstuvwxyz"), tmp)

  result <- .get_file_size(tmp)
  expect_equal(result, 26)
})

test_that(".get_file_size handles empty files", {
  tmp <- withr::local_tempfile()
  file.create(tmp)

  result <- .get_file_size(tmp)
  expect_equal(result, 0)
})

test_that(".get_file_size returns numeric type", {
  tmp <- withr::local_tempfile()
  writeLines("test content", tmp)

  result <- .get_file_size(tmp)
  expect_type(result, "double")
})

# --- .download_single_file error handling tests ---

test_that(".download_single_file throws openneuro_download_error on failure", {
  tmp_dir <- withr::local_tempdir()
  dest_path <- file.path(tmp_dir, "test.txt")

  # Mock httr2::req_perform to throw an error

  local_mocked_bindings(
    req_perform = function(...) {
      stop("Simulated network error")
    },
    .package = "httr2"
  )

  expect_error(
    .download_single_file(
      url = "http://fake.url/file.txt",
      dest_path = dest_path,
      expected_size = 100,
      quiet = TRUE
    ),
    class = "openneuro_download_error"
  )
})

test_that(".download_single_file cleans up partial files on error", {
  tmp_dir <- withr::local_tempdir()
  dest_path <- file.path(tmp_dir, "test.txt")

  # Create a "partial" file to simulate failed download
  writeLines("partial content", dest_path)
  expect_true(file.exists(dest_path))

  # Mock httr2::req_perform to throw an error
  local_mocked_bindings(
    req_perform = function(...) {
      stop("Simulated network error")
    },
    .package = "httr2"
  )

  suppressMessages({
    tryCatch(
      .download_single_file(
        url = "http://fake.url/file.txt",
        dest_path = dest_path,
        expected_size = 100,
        quiet = TRUE
      ),
      error = function(e) NULL
    )
  })

  # File should be cleaned up
  expect_false(file.exists(dest_path))
})

test_that(".download_single_file error message includes filename", {
  tmp_dir <- withr::local_tempdir()
  dest_path <- file.path(tmp_dir, "my_special_file.txt")

  local_mocked_bindings(
    req_perform = function(...) {
      stop("Connection refused")
    },
    .package = "httr2"
  )

  error <- tryCatch(
    .download_single_file(
      url = "http://fake.url/file.txt",
      dest_path = dest_path,
      quiet = TRUE
    ),
    error = function(e) e
  )

  expect_true(grepl("my_special_file.txt", conditionMessage(error)))
})

test_that(".download_single_file fails on size mismatch", {
  tmp_dir <- withr::local_tempdir()
  dest_path <- file.path(tmp_dir, "size_mismatch.bin")

  local_mocked_bindings(
    req_perform = function(req, path = NULL) {
      if (!is.null(path)) {
        writeBin(as.raw(1:5), path)
      }
      structure(list(status_code = 200L), class = "httr2_response")
    },
    .package = "httr2"
  )

  expect_error(
    .download_single_file(
      url = "http://fake.url/file.bin",
      dest_path = dest_path,
      expected_size = 10,
      resume = FALSE,
      quiet = TRUE
    ),
    class = "openneuro_download_error"
  )
  expect_false(file.exists(dest_path))
})

# --- .download_resumable status handling tests ---

test_that(".download_resumable handles HTTP 200 (full file response)", {
  tmp_dir <- withr::local_tempdir()
  dest_path <- file.path(tmp_dir, "test.txt")
  # Create "partial" existing file
  writeLines("partial", dest_path)

  # Create mock response for HTTP 200
  mock_response <- structure(
    list(status_code = 200L),
    class = "httr2_response"
  )

  temp_content <- NULL

  local_mocked_bindings(
    req_perform = function(req, path = NULL) {
      # Write "full file content" to the path
      if (!is.null(path)) {
        writeLines("full file content", path)
        temp_content <<- path
      }
      mock_response
    },
    resp_status = function(resp) 200L,
    .package = "httr2"
  )

  # Should complete without error
  result <- .download_resumable(
    url = "http://fake.url/file.txt",
    dest_path = dest_path,
    existing_bytes = 10,
    show_progress = FALSE
  )

  expect_true(result)
})

test_that(".download_resumable handles HTTP 206 (partial content)", {
  tmp_dir <- withr::local_tempdir()
  dest_path <- file.path(tmp_dir, "test.txt")
  # Create "partial" existing file with known content
  writeBin(charToRaw("partial"), dest_path)

  # Create mock response for HTTP 206
  mock_response <- structure(
    list(status_code = 206L),
    class = "httr2_response"
  )

  local_mocked_bindings(
    req_perform = function(req, path = NULL) {
      # Write remaining content to temp path
      if (!is.null(path)) {
        writeBin(charToRaw("_remaining"), path)
      }
      mock_response
    },
    resp_status = function(resp) 206L,
    .package = "httr2"
  )

  result <- .download_resumable(
    url = "http://fake.url/file.txt",
    dest_path = dest_path,
    existing_bytes = 7,
    show_progress = FALSE
  )

  expect_true(result)
  # Should have appended content
  final_content <- readBin(dest_path, "raw", n = 1000)
  expect_true(length(final_content) > 7)  # More than original
})
