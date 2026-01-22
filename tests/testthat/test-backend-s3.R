# Tests for backend-s3.R - S3 backend functions
# Uses local_mocked_bindings() to avoid CLI invocations

# --- .download_s3 tests ---

test_that(".download_s3 aborts when AWS CLI not found", {
  local_mocked_bindings(
    .find_aws_cli = function() ""
  )

  expect_error(
    .download_s3(
      dataset_id = "ds000001",
      dest_dir = "/tmp/ds000001"
    ),
    class = "openneuro_backend_error"
  )
})

test_that(".download_s3 returns success on successful download", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )

  local_mocked_bindings(
    run = function(command, args, ...) {
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  result <- .download_s3(
    dataset_id = "ds000001",
    dest_dir = "/tmp/ds000001"
  )

  expect_true(result$success)
  expect_equal(result$backend, "s3")
})

test_that(".download_s3 builds correct S3 URI", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )

  captured_args <- NULL
  local_mocked_bindings(
    run = function(command, args, ...) {
      captured_args <<- args
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  .download_s3(
    dataset_id = "ds000001",
    dest_dir = "/tmp/ds000001"
  )

  # Should contain correct S3 URI
  expect_true("s3://openneuro.org/ds000001" %in% captured_args)
})

test_that(".download_s3 uses --no-sign-request for anonymous access", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )

  captured_args <- NULL
  local_mocked_bindings(
    run = function(command, args, ...) {
      captured_args <<- args
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  .download_s3(
    dataset_id = "ds000001",
    dest_dir = "/tmp/ds000001"
  )

  expect_true("--no-sign-request" %in% captured_args)
})

test_that(".download_s3 adds no include/exclude patterns when files = NULL", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )

  captured_args <- NULL
  local_mocked_bindings(
    run = function(command, args, ...) {
      captured_args <<- args
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  .download_s3(
    dataset_id = "ds000001",
    dest_dir = "/tmp/ds000001",
    files = NULL
  )

  # No include/exclude when downloading all files
  expect_false("--exclude" %in% captured_args)
  expect_false("--include" %in% captured_args)
})

test_that(".download_s3 adds exclude * then include patterns for specific files", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )

  captured_args <- NULL
  local_mocked_bindings(
    run = function(command, args, ...) {
      captured_args <<- args
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  .download_s3(
    dataset_id = "ds000001",
    dest_dir = "/tmp/ds000001",
    files = c("participants.tsv", "README.md")
  )

  # Should exclude all first
  exclude_idx <- which(captured_args == "--exclude")
  expect_true(length(exclude_idx) > 0)
  expect_equal(captured_args[exclude_idx + 1], "*")

  # Then include each file
  include_indices <- which(captured_args == "--include")
  expect_equal(length(include_indices), 2)
  expect_true("participants.tsv" %in% captured_args)
  expect_true("README.md" %in% captured_args)
})

test_that(".download_s3 adds --only-show-errors when quiet = TRUE", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )

  captured_args <- NULL
  local_mocked_bindings(
    run = function(command, args, ...) {
      captured_args <<- args
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  .download_s3(
    dataset_id = "ds000001",
    dest_dir = "/tmp/ds000001",
    quiet = TRUE
  )

  expect_true("--only-show-errors" %in% captured_args)
})

test_that(".download_s3 does not add --only-show-errors when quiet = FALSE", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )

  captured_args <- NULL
  local_mocked_bindings(
    run = function(command, args, ...) {
      captured_args <<- args
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  .download_s3(
    dataset_id = "ds000001",
    dest_dir = "/tmp/ds000001",
    quiet = FALSE
  )

  expect_false("--only-show-errors" %in% captured_args)
})

test_that(".download_s3 throws error on download failure", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )

  local_mocked_bindings(
    run = function(command, args, ...) {
      list(status = 1, stdout = "", stderr = "fatal: Unable to locate credentials")
    },
    .package = "processx"
  )

  expect_error(
    .download_s3(
      dataset_id = "ds000001",
      dest_dir = "/tmp/ds000001"
    ),
    class = "openneuro_backend_error"
  )
})

test_that(".download_s3 includes stderr in error message", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )

  local_mocked_bindings(
    run = function(command, args, ...) {
      list(status = 1, stdout = "", stderr = "Specific error message here")
    },
    .package = "processx"
  )

  # Capture the error to check its message
  err <- tryCatch(
    .download_s3(
      dataset_id = "ds000001",
      dest_dir = "/tmp/ds000001"
    ),
    openneuro_backend_error = function(e) e
  )

  expect_true(grepl("Specific error message here", conditionMessage(err)))
})

test_that(".download_s3 uses correct command path from .find_aws_cli", {
  local_mocked_bindings(
    .find_aws_cli = function() "/custom/path/to/aws"
  )

  captured_command <- NULL
  local_mocked_bindings(
    run = function(command, args, ...) {
      captured_command <<- command
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  .download_s3(
    dataset_id = "ds000001",
    dest_dir = "/tmp/ds000001"
  )

  expect_equal(captured_command, "/custom/path/to/aws")
})
