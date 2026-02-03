# Tests for handle creation and lifecycle
# Tests handle functions without triggering actual downloads

test_that("on_handle creates pending handle", {
  handle <- on_handle("ds000001")
  expect_s3_class(handle, "openneuro_handle")
  expect_equal(handle$state, "pending")
  expect_null(handle$path)
})

test_that("on_handle stores dataset_id", {
  handle <- on_handle("ds000001")
  expect_equal(handle$dataset_id, "ds000001")
})

test_that("on_handle stores optional tag", {
  handle <- on_handle("ds000001", tag = "1.0.0")
  expect_equal(handle$tag, "1.0.0")
})

test_that("on_handle stores optional files", {
  handle <- on_handle("ds000001", files = "participants.tsv")
  expect_equal(handle$files, "participants.tsv")

  handle2 <- on_handle("ds000001", files = c("a.txt", "b.txt"))
  expect_equal(handle2$files, c("a.txt", "b.txt"))
})

test_that("on_handle stores optional backend", {
  handle <- on_handle("ds000001", backend = "s3")
  expect_equal(handle$backend, "s3")
})

test_that("on_handle validates dataset_id - missing", {
  expect_error(
    on_handle(),
    class = "openneuro_validation_error"
  )
})

test_that("on_handle validates dataset_id - empty string", {
  expect_error(
    on_handle(""),
    class = "openneuro_validation_error"
  )
})

test_that("on_handle validates dataset_id - wrong type", {
  expect_error(
    on_handle(123),
    class = "openneuro_validation_error"
  )
})

test_that("on_handle validates dataset_id - vector", {
  expect_error(
    on_handle(c("ds000001", "ds000002")),
    class = "openneuro_validation_error"
  )
})

test_that("on_handle validates backend option", {
  expect_error(
    on_handle("ds000001", backend = "invalid"),
    class = "openneuro_validation_error"
  )
})

test_that("on_handle accepts valid backends", {
  # Should not error
  handle1 <- on_handle("ds000001", backend = "datalad")
  expect_equal(handle1$backend, "datalad")

  handle2 <- on_handle("ds000001", backend = "s3")
  expect_equal(handle2$backend, "s3")

  handle3 <- on_handle("ds000001", backend = "https")
  expect_equal(handle3$backend, "https")
})

test_that("on_path errors on unfetched handle", {
  handle <- on_handle("ds000001")
  expect_error(
    on_path(handle),
    class = "openneuro_handle_error"
  )
})

test_that("on_path works on ready handle", {
  # Manually create a ready handle (simulate fetched state)
  handle <- on_handle("ds000001")
  handle$state <- "ready"
  handle$path <- "/tmp/test/ds000001"

  expect_equal(on_path(handle), "/tmp/test/ds000001")
})

test_that("print.openneuro_handle runs without error", {
  handle <- on_handle("ds000001")
  # Just check that print doesn't error
  expect_no_error(print(handle))
})

test_that("print.openneuro_handle runs with files", {
  handle <- on_handle("ds000001", files = "participants.tsv")
  expect_no_error(print(handle))
})

test_that("print.openneuro_handle runs for ready handle", {
  handle <- on_handle("ds000001")
  handle$state <- "ready"
  handle$path <- "/tmp/test/ds000001"
  expect_no_error(print(handle))
})

test_that("print.openneuro_handle returns invisibly", {
  handle <- on_handle("ds000001")
  result <- withVisible(print(handle))
  expect_false(result$visible)
  expect_s3_class(result$value, "openneuro_handle")
})

# --- on_fetch tests with mocks ---

test_that("on_fetch.openneuro_handle quiet=TRUE suppresses message", {
  handle <- on_handle("ds000001")
  handle$state <- "ready"  # Already fetched
  handle$path <- "/tmp/ds000001"

  # quiet=FALSE should emit a message
  expect_message(
    result <- on_fetch(handle, quiet = FALSE),
    "already fetched"
  )
  expect_equal(result$state, "ready")
})

test_that("on_fetch.openneuro_handle quiet=TRUE returns without message when ready", {
  handle <- on_handle("ds000001")
  handle$state <- "ready"
  handle$path <- "/tmp/ds000001"

  # quiet=TRUE should not emit a message
  expect_no_message(
    result <- on_fetch(handle, quiet = TRUE)
  )
  expect_equal(result$state, "ready")
})

test_that("on_fetch.openneuro_handle force=TRUE re-downloads ready handle", {
  download_called <- FALSE

  local_mocked_bindings(
    on_download = function(id, tag, files, backend, quiet, force) {
      download_called <<- TRUE
      list(dest_dir = "/tmp/ds000001_redownloaded")
    }
  )

  handle <- on_handle("ds000001")
  handle$state <- "ready"
  handle$path <- "/tmp/ds000001_old"

  result <- on_fetch(handle, force = TRUE, quiet = TRUE)

  expect_true(download_called)
  expect_equal(result$path, "/tmp/ds000001_redownloaded")
})

test_that("on_fetch.openneuro_handle passes parameters to on_download", {
  captured_args <- list()

  local_mocked_bindings(
    on_download = function(id, tag, files, backend, quiet, force) {
      captured_args <<- list(
        id = id,
        tag = tag,
        files = files,
        backend = backend,
        quiet = quiet,
        force = force
      )
      list(dest_dir = "/tmp/test")
    }
  )

  handle <- on_handle("ds000001", tag = "1.0.0", files = "participants.tsv", backend = "s3")

  result <- on_fetch(handle, quiet = TRUE, force = FALSE)

  expect_equal(captured_args$id, "ds000001")
  expect_equal(captured_args$tag, "1.0.0")
  expect_equal(captured_args$files, "participants.tsv")
  expect_equal(captured_args$backend, "s3")
  expect_true(captured_args$quiet)
  expect_false(captured_args$force)
})

test_that("on_fetch.openneuro_handle sets fetch_time on download", {
  local_mocked_bindings(
    on_download = function(...) {
      list(dest_dir = "/tmp/ds000001")
    }
  )

  handle <- on_handle("ds000001")
  before <- Sys.time()

  result <- on_fetch(handle, quiet = TRUE)

  expect_s3_class(result$fetch_time, "POSIXct")
  expect_true(result$fetch_time >= before)
})
