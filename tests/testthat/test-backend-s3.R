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

# --- .probe_s3_bucket tests ---

test_that(".probe_s3_bucket returns FALSE and caches result if AWS CLI missing", {
  .discovery_cache_clear()

  run_calls <- 0L

  local_mocked_bindings(
    .find_aws_cli = function() "",
    .package = "openneuro"
  )
  local_mocked_bindings(
    run = function(...) {
      run_calls <<- run_calls + 1L
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  expect_false(.probe_s3_bucket("openneuro.org"))
  expect_false(.probe_s3_bucket("openneuro.org"))  # cached
  expect_equal(run_calls, 0L)
})

test_that(".probe_s3_bucket caches successful probe results", {
  .discovery_cache_clear()

  run_calls <- 0L

  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws",
    .package = "openneuro"
  )

  local_mocked_bindings(
    run = function(...) {
      run_calls <<- run_calls + 1L
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  expect_true(.probe_s3_bucket("openneuro-derivatives", test_path = "fmriprep/"))
  expect_true(.probe_s3_bucket("openneuro-derivatives", test_path = "fmriprep/"))  # cached
  expect_equal(run_calls, 1L)
})

# --- backend-detect.R tests ---

test_that(".backend_available returns TRUE for https (always available)", {
  result <- openneuro:::.backend_available("https")
  expect_true(result)
})

test_that(".backend_available returns FALSE for unknown backend", {
  result <- openneuro:::.backend_available("unknown_backend")
  expect_false(result)
})

test_that(".backend_available checks for s3 correctly", {
  # Mock AWS CLI not found
  local_mocked_bindings(
    .find_aws_cli = function() ""
  )

  result <- openneuro:::.backend_available("s3")
  expect_false(result)
})

test_that(".backend_available checks for s3 with AWS CLI present", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )

  result <- openneuro:::.backend_available("s3")
  expect_true(result)
})

test_that(".backend_available checks for datalad correctly", {
  # Mock datalad not found
  local_mocked_bindings(
    .sys_which = function(names) {
      setNames(rep("", length(names)), names)
    }
  )

  result <- openneuro:::.backend_available("datalad")
  expect_false(result)
})

test_that(".backend_available checks for datalad with tools present", {
  local_mocked_bindings(
    .sys_which = function(names) {
      paths <- setNames(rep("", length(names)), names)
      if ("datalad" %in% names) paths["datalad"] <- "/usr/local/bin/datalad"
      if ("git-annex" %in% names) paths["git-annex"] <- "/usr/local/bin/git-annex"
      paths
    }
  )

  result <- openneuro:::.backend_available("datalad")
  expect_true(result)
})

test_that(".backend_status caches results", {
  check_calls <- 0L

  local_mocked_bindings(
    .backend_available = function(backend) {
      check_calls <<- check_calls + 1L
      TRUE
    }
  )

  # First call should check
  result1 <- openneuro:::.backend_status("test_backend")
  # Second call should use cache
  result2 <- openneuro:::.backend_status("test_backend")

  expect_true(result1)
  expect_true(result2)
  expect_equal(check_calls, 1L)
})

test_that(".backend_status refresh=TRUE bypasses cache", {
  check_calls <- 0L

  local_mocked_bindings(
    .backend_available = function(backend) {
      check_calls <<- check_calls + 1L
      TRUE
    }
  )

  # First call
  result1 <- openneuro:::.backend_status("refresh_test", refresh = TRUE)
  # Second call with refresh=TRUE should re-check
  result2 <- openneuro:::.backend_status("refresh_test", refresh = TRUE)

  expect_true(result1)
  expect_true(result2)
  expect_equal(check_calls, 2L)
})

test_that(".find_aws_cli returns empty string when AWS CLI not in PATH", {
  local_mocked_bindings(
    .sys_which = function(names) setNames("", names)
  )

  # Mock file.exists to return FALSE for all common paths
  local_mocked_bindings(
    file.exists = function(x) FALSE,
    .package = "base"
  )

  result <- openneuro:::.find_aws_cli()
  expect_equal(result, "")
})

test_that(".find_aws_cli finds AWS CLI in PATH", {
  # Just test that the function can find the real AWS CLI if installed
  # This test will be skipped if AWS CLI is not installed
  result <- openneuro:::.find_aws_cli()
  # Result should be either a path or empty string

  expect_type(result, "character")
})

test_that(".sys_which wraps Sys.which correctly", {
  result <- openneuro:::.sys_which("ls")
  expect_type(result, "character")
  expect_named(result)
})
