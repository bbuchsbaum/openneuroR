# Tests for backend-datalad.R - DataLad backend functions
# Uses local_mocked_bindings() to avoid CLI invocations

# --- .datalad_action tests ---

test_that(".datalad_action returns 'clone' when directory doesn't exist", {
  local_mocked_bindings(
    dir_exists = function(path) FALSE,
    .package = "fs"
  )
  expect_equal(.datalad_action("/fake/path/ds000001"), "clone")
})

test_that(".datalad_action returns 'update' when .datalad/ exists", {
  local_mocked_bindings(
    dir_exists = function(path) {
      # Return TRUE for .datalad directory
      grepl("\\.datalad$", path)
    },
    .package = "fs"
  )
  expect_equal(.datalad_action("/fake/path/ds000001"), "update")
})

test_that(".datalad_action aborts when directory exists but isn't DataLad dataset", {
  local_mocked_bindings(
    dir_exists = function(path) {
      # Directory exists but .datalad/ doesn't
      !grepl("\\.datalad$", path)
    },
    dir_ls = function(path) c("README.md", "participants.tsv"),
    .package = "fs"
  )

  expect_error(
    .datalad_action("/fake/path/ds000001"),
    class = "openneuro_backend_error"
  )
})

test_that(".datalad_action returns 'clone' for empty directory", {
  local_mocked_bindings(
    dir_exists = function(path) {
      # Directory exists but .datalad/ doesn't
      !grepl("\\.datalad$", path)
    },
    dir_ls = function(path) character(0),  # Empty directory
    .package = "fs"
  )
  expect_equal(.datalad_action("/fake/path/ds000001"), "clone")
})


# --- .download_datalad tests ---

test_that(".download_datalad succeeds on clone + get flow", {
  local_mocked_bindings(
    .datalad_action = function(dest_dir) "clone"
  )

  # Track calls to processx::run
  run_calls <- list()
  local_mocked_bindings(
    run = function(command, args, ...) {
      run_calls <<- c(run_calls, list(list(command = command, args = args)))
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  result <- .download_datalad(
    dataset_id = "ds000001",
    dest_dir = "/tmp/ds000001",
    files = NULL,
    quiet = FALSE
  )

  expect_true(result$success)
  expect_equal(result$backend, "datalad")

  # Should have called datalad clone then datalad get
  expect_length(run_calls, 2)
  expect_equal(run_calls[[1]]$command, "datalad")
  expect_true("clone" %in% run_calls[[1]]$args)
  expect_equal(run_calls[[2]]$command, "datalad")
  expect_true("get" %in% run_calls[[2]]$args)
})

test_that(".download_datalad skips clone for update action", {
  local_mocked_bindings(
    .datalad_action = function(dest_dir) "update"
  )

  # Track calls to processx::run
  run_calls <- list()
  local_mocked_bindings(
    run = function(command, args, ...) {
      run_calls <<- c(run_calls, list(list(command = command, args = args)))
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  result <- .download_datalad(
    dataset_id = "ds000001",
    dest_dir = "/tmp/ds000001",
    files = NULL,
    quiet = FALSE
  )

  expect_true(result$success)
  expect_equal(result$backend, "datalad")

  # Should only have called datalad get (no clone)
  expect_length(run_calls, 1)
  expect_equal(run_calls[[1]]$command, "datalad")
  expect_true("get" %in% run_calls[[1]]$args)
  expect_false("clone" %in% run_calls[[1]]$args)
})

test_that(".download_datalad throws error on clone failure", {
  local_mocked_bindings(
    .datalad_action = function(dest_dir) "clone"
  )

  local_mocked_bindings(
    run = function(command, args, ...) {
      if ("clone" %in% args) {
        list(status = 1, stdout = "", stderr = "fatal: repository not found")
      } else {
        list(status = 0, stdout = "", stderr = "")
      }
    },
    .package = "processx"
  )

  expect_error(
    .download_datalad(
      dataset_id = "ds000001",
      dest_dir = "/tmp/ds000001",
      files = NULL,
      quiet = FALSE
    ),
    class = "openneuro_backend_error"
  )
})

test_that(".download_datalad throws error on get failure", {
  local_mocked_bindings(
    .datalad_action = function(dest_dir) "clone"
  )

  local_mocked_bindings(
    run = function(command, args, ...) {
      if ("get" %in% args) {
        list(status = 1, stdout = "", stderr = "git-annex: permission denied")
      } else {
        list(status = 0, stdout = "", stderr = "")
      }
    },
    .package = "processx"
  )

  expect_error(
    .download_datalad(
      dataset_id = "ds000001",
      dest_dir = "/tmp/ds000001",
      files = NULL,
      quiet = FALSE
    ),
    class = "openneuro_backend_error"
  )
})

test_that(".download_datalad gets all files when files = NULL", {
  local_mocked_bindings(
    .datalad_action = function(dest_dir) "update"
  )

  captured_args <- NULL
  local_mocked_bindings(
    run = function(command, args, ...) {
      captured_args <<- args
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  .download_datalad(
    dataset_id = "ds000001",
    dest_dir = "/tmp/ds000001",
    files = NULL,
    quiet = FALSE
  )

  # Should get "." (all files)
  expect_true("." %in% captured_args)
})

test_that(".download_datalad gets specific files when files provided", {
  local_mocked_bindings(
    .datalad_action = function(dest_dir) "update"
  )

  captured_args <- NULL
  local_mocked_bindings(
    run = function(command, args, ...) {
      captured_args <<- args
      list(status = 0, stdout = "", stderr = "")
    },
    .package = "processx"
  )

  .download_datalad(
    dataset_id = "ds000001",
    dest_dir = "/tmp/ds000001",
    files = c("participants.tsv", "README.md"),
    quiet = FALSE
  )

  # Should include specific files, not "."
  expect_false("." %in% captured_args)
  expect_true("participants.tsv" %in% captured_args)
  expect_true("README.md" %in% captured_args)
})
