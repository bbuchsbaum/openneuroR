# Tests for backend detection and dispatch
# Uses local_mocked_bindings() to avoid CLI invocations

test_that(".backend_available detects missing AWS CLI", {
  local_mocked_bindings(
    .find_aws_cli = function() ""
  )
  expect_false(.backend_available("s3"))
})

test_that(".backend_available detects present AWS CLI", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )
  expect_true(.backend_available("s3"))
})

test_that(".backend_available detects missing DataLad", {
  local_mocked_bindings(
    .sys_which = function(names) {
      setNames("", names)
    }
  )
  expect_false(.backend_available("datalad"))
})

test_that(".backend_available detects present DataLad", {
  local_mocked_bindings(
    .sys_which = function(names) {
      if (names == "datalad") return(setNames("/usr/bin/datalad", names))
      if (names == "git-annex") return(setNames("/usr/bin/git-annex", names))
      setNames("", names)
    }
  )
  expect_true(.backend_available("datalad"))
})

test_that(".backend_available requires both datalad and git-annex", {
  # DataLad without git-annex should fail
  local_mocked_bindings(
    .sys_which = function(names) {
      if (names == "datalad") return(setNames("/usr/bin/datalad", names))
      setNames("", names)  # git-annex missing
    }
  )
  expect_false(.backend_available("datalad"))
})

test_that(".backend_available always returns TRUE for https", {
  expect_true(.backend_available("https"))
})

test_that(".backend_available returns FALSE for unknown backend", {
  expect_false(.backend_available("unknown"))
})

test_that(".select_backend returns https when nothing else available", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) backend == "https"
  )
  expect_equal(.select_backend(), "https")
})

test_that(".select_backend respects priority when all available", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) TRUE
  )
  expect_equal(.select_backend(), "datalad")  # Highest priority
})

test_that(".select_backend returns s3 when datalad unavailable", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) {
      backend %in% c("s3", "https")
    }
  )
  expect_equal(.select_backend(), "s3")
})

test_that(".select_backend returns preferred backend if available", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) TRUE
  )
  expect_equal(.select_backend(preferred = "s3"), "s3")
  expect_equal(.select_backend(preferred = "https"), "https")
})

test_that(".select_backend falls back when preferred unavailable", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) {
      backend %in% c("s3", "https")
    }
  )
  # Request datalad but it's unavailable - should fall back
  expect_warning(
    result <- .select_backend(preferred = "datalad"),
    "not available"
  )
  expect_equal(result, "s3")
})

test_that(".select_backend warns on unknown backend", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) backend == "https"
  )
  expect_warning(
    result <- .select_backend(preferred = "invalid"),
    "not recognized"
  )
  expect_equal(result, "https")
})

# --- .backend_status tests (cache mechanism) ---

test_that(".backend_status caches result on first call", {
  call_count <- 0
  local_mocked_bindings(
    .backend_available = function(backend) {
      call_count <<- call_count + 1
      TRUE
    }
  )

  # Reset cache by creating fresh closure via refresh
  .backend_status("s3", refresh = TRUE)

  # First call after refresh
  result1 <- .backend_status("s3", refresh = TRUE)
  calls_after_first <- call_count

  # Second call should use cache

  result2 <- .backend_status("s3", refresh = FALSE)
  calls_after_second <- call_count

  expect_equal(result1, result2)
  # Second call should not have incremented
  expect_equal(calls_after_first, calls_after_second)
})

test_that(".backend_status refresh=TRUE bypasses cache", {
  call_count <- 0
  local_mocked_bindings(
    .backend_available = function(backend) {
      call_count <<- call_count + 1
      TRUE
    }
  )

  .backend_status("datalad", refresh = TRUE)
  calls_after_first <- call_count

  .backend_status("datalad", refresh = TRUE)
  calls_after_second <- call_count

  # Each refresh=TRUE should call .backend_available
  expect_equal(calls_after_second, calls_after_first + 1)
})

# --- .find_aws_cli tests ---

test_that(".find_aws_cli returns empty string when aws not in PATH and not in common paths", {
  local_mocked_bindings(
    Sys.which = function(names) setNames("", names),
    file.exists = function(path) FALSE,
    .package = "base"
  )
  result <- .find_aws_cli()
  expect_equal(result, "")
})

test_that(".find_aws_cli returns PATH result when aws is in PATH", {
  local_mocked_bindings(
    Sys.which = function(names) setNames("/usr/local/bin/aws", names),
    .package = "base"
  )
  result <- .find_aws_cli()
  expect_equal(result, "/usr/local/bin/aws")
})

test_that(".find_aws_cli falls back to common paths when not in PATH", {
  local_mocked_bindings(
    Sys.which = function(names) setNames("", names),
    file.exists = function(path) {
      path == "/usr/local/bin/aws"
    },
    .package = "base"
  )
  result <- .find_aws_cli()
  expect_equal(result, "/usr/local/bin/aws")
})

test_that(".find_aws_cli checks homebrew path", {
  local_mocked_bindings(
    Sys.which = function(names) setNames("", names),
    file.exists = function(path) {
      path == "/opt/homebrew/bin/aws"
    },
    .package = "base"
  )
  result <- .find_aws_cli()
  expect_equal(result, "/opt/homebrew/bin/aws")
})

# --- .download_with_backend tests ---

test_that(".download_with_backend returns NULL when https selected", {
  local_mocked_bindings(
    .select_backend = function(preferred = NULL) "https"
  )

  result <- .download_with_backend(
    dataset_id = "ds000001",
    dest_dir = tempdir(),
    quiet = TRUE
  )

  expect_null(result)
})

test_that(".download_with_backend quiet=TRUE suppresses cli output", {
  local_mocked_bindings(
    .select_backend = function(preferred = NULL) "https"
  )

  # Capture output
  output <- capture.output({
    result <- .download_with_backend(
      dataset_id = "ds000001",
      dest_dir = tempdir(),
      quiet = TRUE
    )
  }, type = "message")

  # quiet=TRUE should suppress "Using https backend" message
  expect_equal(length(output), 0)
})

test_that(".download_with_backend falls back on openneuro_backend_error", {
  fallback_called <- FALSE

  local_mocked_bindings(
    .select_backend = function(preferred = NULL) {
      if (is.null(preferred)) "datalad"
      else if (preferred == "s3") "s3"
      else if (preferred == "https") "https"
      else "datalad"
    },
    .backend_status = function(backend, refresh = FALSE) TRUE,
    .download_datalad = function(...) {
      rlang::abort("DataLad failed", class = "openneuro_backend_error")
    },
    .download_s3 = function(...) {
      fallback_called <<- TRUE
      list(success = TRUE, backend = "s3")
    }
  )

  result <- .download_with_backend(
    dataset_id = "ds000001",
    dest_dir = tempdir(),
    quiet = TRUE
  )

  expect_true(fallback_called)
  expect_equal(result$backend, "s3")
})

test_that(".download_with_backend falls back to https when s3 fails", {
  local_mocked_bindings(
    .select_backend = function(preferred = NULL) {
      if (is.null(preferred)) "s3"
      else if (preferred == "https") "https"
      else "s3"
    },
    .backend_status = function(backend, refresh = FALSE) TRUE,
    .download_s3 = function(...) {
      rlang::abort("S3 failed", class = "openneuro_backend_error")
    }
  )

  result <- .download_with_backend(
    dataset_id = "ds000001",
    dest_dir = tempdir(),
    quiet = TRUE
  )

  # Should return NULL, signaling HTTPS fallback to caller
  expect_null(result)
})
