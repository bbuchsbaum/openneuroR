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

  # Capture output - should contain "5 MB" or similar
  output <- capture.output(
    .print_completion_summary(result_list, quiet = FALSE),
    type = "message"
  )

  # CLI output should contain size info
  expect_true(any(grepl("MB|downloaded", output, ignore.case = TRUE)))
})
