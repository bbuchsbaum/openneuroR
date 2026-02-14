# Tests for download-progress.R helper functions
# Pure functions - no mocking needed

# --- .format_bytes tests ---

test_that(".format_bytes returns B for small values", {
  expect_equal(.format_bytes(0), "0 B")
  expect_equal(.format_bytes(1), "1 B")
  expect_equal(.format_bytes(500), "500 B")
  expect_equal(.format_bytes(1023), "1023 B")
})

test_that(".format_bytes returns KB for kilobyte range", {
  expect_equal(.format_bytes(1024), "1 KB")
  expect_equal(.format_bytes(1024 * 10), "10 KB")
  expect_equal(.format_bytes(1024 * 500), "500 KB")
})

test_that(".format_bytes returns MB for megabyte range", {
  expect_equal(.format_bytes(1024^2), "1 MB")
  expect_equal(.format_bytes(1024^2 * 100), "100 MB")
  expect_equal(.format_bytes(1024^2 * 512), "512 MB")
})

test_that(".format_bytes returns GB for gigabyte range", {
  expect_equal(.format_bytes(1024^3), "1 GB")
  expect_equal(.format_bytes(1024^3 * 2), "2 GB")
  expect_equal(.format_bytes(1024^3 * 10.5), "10.5 GB")
})

test_that(".format_bytes handles boundary values correctly", {
  # Just under 1 KB
  expect_equal(.format_bytes(1023), "1023 B")
  # Exactly 1 KB
  expect_equal(.format_bytes(1024), "1 KB")

  # Just under 1 MB
  result_under_mb <- .format_bytes(1024^2 - 1)
  expect_true(grepl("KB$", result_under_mb))
  # Exactly 1 MB
  expect_equal(.format_bytes(1024^2), "1 MB")

  # Just under 1 GB
  result_under_gb <- .format_bytes(1024^3 - 1)
  expect_true(grepl("MB$", result_under_gb))
  # Exactly 1 GB
  expect_equal(.format_bytes(1024^3), "1 GB")
})

test_that(".format_bytes rounds correctly", {
  # Check that fractional values are rounded to 1 decimal
  result <- .format_bytes(1024 * 1.5)  # 1.5 KB
  expect_equal(result, "1.5 KB")

  result <- .format_bytes(1024^2 * 1.25)  # 1.25 MB -> rounds to 1.2
  expect_true(grepl("^1\\.[23] MB$", result))
})

# --- .print_completion_summary tests ---

test_that(".print_completion_summary returns invisibly NULL when quiet=TRUE", {
  result_list <- list(
    downloaded = 5,
    skipped = 2,
    failed = character(),
    total_bytes = 1024 * 100,
    dest_dir = "/tmp/test"
  )

  result <- .print_completion_summary(result_list, quiet = TRUE)
  expect_null(result)
})

test_that(".print_completion_summary handles empty failed list", {
  result_list <- list(
    downloaded = 3,
    skipped = 0,
    failed = character(),
    total_bytes = 1024,
    dest_dir = "/tmp/test"
  )

  # Should not error
  expect_no_error(
    capture.output(
      .print_completion_summary(result_list, quiet = FALSE),
      type = "message"
    )
  )
})

test_that(".print_completion_summary handles non-empty failed list", {
  result_list <- list(
    downloaded = 2,
    skipped = 0,
    failed = c("file1.txt", "file2.txt"),
    total_bytes = 512,
    dest_dir = "/tmp/test"
  )

  # Should not error and should mention failed files
  expect_no_error(
    capture.output(
      .print_completion_summary(result_list, quiet = FALSE),
      type = "message"
    )
  )
})

test_that(".print_completion_summary handles skipped files", {
  result_list <- list(
    downloaded = 1,
    skipped = 5,
    failed = character(),
    total_bytes = 256,
    dest_dir = "/tmp/test"
  )

  # Should not error
  expect_no_error(
    capture.output(
      .print_completion_summary(result_list, quiet = FALSE),
      type = "message"
    )
  )
})

test_that(".print_completion_summary handles zero downloads", {
  result_list <- list(
    downloaded = 0,
    skipped = 10,
    failed = character(),
    total_bytes = 0,
    dest_dir = "/tmp/test"
  )

  expect_no_error(
    capture.output(
      .print_completion_summary(result_list, quiet = FALSE),
      type = "message"
    )
  )
})

test_that(".print_completion_summary uses format_bytes for size", {
  result_list <- list(
    downloaded = 1,
    skipped = 0,
    failed = character(),
    total_bytes = 1024^2 * 5,  # 5 MB
    dest_dir = "/tmp/test"
  )

  expect_match(.format_bytes(result_list$total_bytes), "MB")
  expect_no_error(.print_completion_summary(result_list, quiet = FALSE))
})

# --- .download_with_progress tests ---

test_that(".download_with_progress updates manifest with provided type", {
  tmp <- withr::local_tempdir()

  files_df <- tibble::tibble(
    filename = "a.txt",
    full_path = "a.txt",
    size = 3,
    annexed = FALSE
  )

  update_calls <- list()

  local_mocked_bindings(
    .read_manifest = function(...) NULL,
    .validate_existing_file = function(...) FALSE,
    .construct_download_url = function(...) "https://example.org/a.txt",
    .download_atomic = function(url, final_path, download_fn) {
      writeBin(as.raw(c(1, 2, 3)), final_path)
      invisible(NULL)
    },
    .download_single_file = function(...) invisible(NULL),
    .batch_update_manifest = function(dataset_dir, file_entries, dataset_id,
                                       snapshot_tag, backend = "https",
                                       type = "raw", ...) {
      for (fi in file_entries) {
        update_calls <<- c(update_calls, list(list(
          dataset_dir = dataset_dir,
          path = fi$path,
          type = type,
          snapshot_tag = snapshot_tag,
          backend = backend
        )))
      }
      invisible(NULL)
    },
    .print_completion_summary = function(...) invisible(NULL),
    .package = "openneuro"
  )

  result <- .download_with_progress(
    files_df = files_df,
    dest_dir = tmp,
    dataset_id = "ds000001",
    tag = "1.0.0",
    quiet = TRUE,
    use_cache = TRUE,
    type = "derivative"
  )

  expect_equal(result$downloaded, 1L)
  expect_length(update_calls, 1L)
  expect_equal(update_calls[[1]]$type, "derivative")
  expect_equal(update_calls[[1]]$path, "a.txt")
})

test_that(".download_with_progress skips cached files when manifest + file match", {
  tmp <- withr::local_tempdir()

  files_df <- tibble::tibble(
    filename = "a.txt",
    full_path = "a.txt",
    size = 3,
    annexed = FALSE
  )

  download_calls <- 0L

  local_mocked_bindings(
    .read_manifest = function(...) list(
      snapshot_tag = "1.0.0",
      files = list(list(path = "a.txt", size = 3, backend = "https", type = "raw"))
    ),
    .validate_existing_file = function(...) TRUE,
    .download_atomic = function(...) {
      download_calls <<- download_calls + 1L
      invisible(NULL)
    },
    .update_manifest = function(...) stop("should not update"),
    .print_completion_summary = function(...) invisible(NULL),
    .construct_download_url = function(...) stop("should not download"),
    .package = "openneuro"
  )

  result <- .download_with_progress(
    files_df = files_df,
    dest_dir = tmp,
    dataset_id = "ds000001",
    tag = "1.0.0",
    quiet = TRUE,
    use_cache = TRUE
  )

  expect_equal(result$downloaded, 0L)
  expect_equal(result$skipped, 1L)
  expect_equal(download_calls, 0L)
})

test_that(".download_with_progress records failures when download errors", {
  tmp <- withr::local_tempdir()

  files_df <- tibble::tibble(
    filename = "a.txt",
    full_path = "a.txt",
    size = 3,
    annexed = FALSE
  )

  local_mocked_bindings(
    .read_manifest = function(...) NULL,
    .validate_existing_file = function(...) FALSE,
    .construct_download_url = function(...) "https://example.org/a.txt",
    .download_atomic = function(...) stop("network fail"),
    .update_manifest = function(...) stop("should not update"),
    .print_completion_summary = function(...) invisible(NULL),
    .package = "openneuro"
  )

  result <- .download_with_progress(
    files_df = files_df,
    dest_dir = tmp,
    dataset_id = "ds000001",
    tag = "1.0.0",
    quiet = TRUE,
    use_cache = TRUE
  )

  expect_equal(result$downloaded, 0L)
  expect_equal(length(result$failed), 1L)
  expect_equal(result$failed[[1]], "a.txt")
})
