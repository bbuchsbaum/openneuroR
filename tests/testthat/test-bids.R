# Tests for on_bids() BIDS bridge functionality
# Tests handle-to-bids_project conversion with mocking for optional dependency

# Helper: Create a mock ready handle pointing to a path
mock_ready_handle <- function(path, dataset_id = "ds000001") {
  handle <- on_handle(dataset_id)
  handle$state <- "ready"
  handle$path <- path
  handle$fetch_time <- Sys.time()
  handle
}

# Helper: Create minimal valid BIDS structure in a temp directory
# Uses parent.frame() to tie tempdir lifetime to calling test
create_temp_bids <- function(envir = parent.frame()) {
  tmp <- withr::local_tempdir(.local_envir = envir)
  writeLines(
    '{"Name": "Test Dataset", "BIDSVersion": "1.0.0"}',
    fs::path(tmp, "dataset_description.json")
  )
  tmp
}

# Helper: Create BIDS structure with derivatives
create_temp_bids_with_derivatives <- function(deriv_name = "fmriprep", envir = parent.frame()) {
  tmp <- create_temp_bids(envir = envir)
  deriv_path <- fs::path(tmp, "derivatives", deriv_name)
  fs::dir_create(deriv_path, recurse = TRUE)
  tmp
}


# ==============================================================================
# Input Validation Tests (no bidser needed)
# ==============================================================================

test_that("on_bids rejects non-handle input - string", {
  # Mock check_installed to avoid bidser check
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  expect_error(
    on_bids("not-a-handle"),
    class = "openneuro_validation_error"
  )
})

test_that("on_bids rejects non-handle input - list", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  expect_error(
    on_bids(list(dataset_id = "ds000001")),
    class = "openneuro_validation_error"
  )
})

test_that("on_bids rejects non-handle input - NULL", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  expect_error(
    on_bids(NULL),
    class = "openneuro_validation_error"
  )
})

test_that("on_bids suggests on_handle() in error message", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  err <- tryCatch(
    on_bids("not-a-handle"),
    error = function(e) e
  )

  expect_match(conditionMessage(err), "on_handle", fixed = TRUE)
})

test_that("on_bids error message includes actual class", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  err <- tryCatch(
    on_bids(data.frame(x = 1)),
    error = function(e) e
  )

  expect_match(conditionMessage(err), "data.frame", fixed = TRUE)
})


# ==============================================================================
# BIDS Structure Validation Tests
# ==============================================================================

test_that("on_bids errors when dataset_description.json missing", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  # Create temp dir without dataset_description.json
  tmp <- withr::local_tempdir()
  handle <- mock_ready_handle(tmp)

  expect_error(
    on_bids(handle),
    class = "openneuro_bids_error"
  )
})

test_that("on_bids bids_error message mentions dataset_description.json", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  tmp <- withr::local_tempdir()
  handle <- mock_ready_handle(tmp)

  err <- tryCatch(
    on_bids(handle),
    error = function(e) e
  )

  expect_match(conditionMessage(err), "dataset_description.json", fixed = TRUE)
})

test_that("on_bids error mentions checked path", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  tmp <- withr::local_tempdir()
  handle <- mock_ready_handle(tmp)

  err <- tryCatch(
    on_bids(handle),
    error = function(e) e
  )

  expect_match(conditionMessage(err), tmp, fixed = TRUE)
})


# ==============================================================================
# Derivatives Warning Tests
# ==============================================================================

test_that("on_bids warns when fmriprep=TRUE but derivatives missing", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  # Create valid BIDS structure without derivatives
  tmp <- create_temp_bids()
  handle <- mock_ready_handle(tmp)

  # Mock bidser::bids_project to avoid needing the actual package
  mock_bids_project <- function(...) {
    structure(list(...), class = "bids_project")
  }

  local_mocked_bindings(
    bids_project = mock_bids_project,
    .package = "bidser"
  )

  expect_warning(
    on_bids(handle, fmriprep = TRUE),
    "Derivatives path does not exist"
  )
})

test_that("on_bids warns when custom prep_dir missing", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  tmp <- create_temp_bids()
  handle <- mock_ready_handle(tmp)

  mock_bids_project <- function(...) {
    structure(list(...), class = "bids_project")
  }

  local_mocked_bindings(
    bids_project = mock_bids_project,
    .package = "bidser"
  )

  expect_warning(
    on_bids(handle, prep_dir = "derivatives/custom-pipeline"),
    "Derivatives path does not exist"
  )
})

test_that("on_bids does not warn when derivatives exist", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  # Create BIDS structure WITH derivatives
  tmp <- create_temp_bids_with_derivatives()
  handle <- mock_ready_handle(tmp)

  mock_bids_project <- function(...) {
    structure(list(...), class = "bids_project")
  }

  local_mocked_bindings(
    bids_project = mock_bids_project,
    .package = "bidser"
  )

  # Should not warn
  expect_no_warning(
    on_bids(handle, fmriprep = TRUE)
  )
})

test_that("on_bids does not warn when not requesting derivatives", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  # Create valid BIDS without derivatives
  tmp <- create_temp_bids()
  handle <- mock_ready_handle(tmp)

  mock_bids_project <- function(...) {
    structure(list(...), class = "bids_project")
  }

  local_mocked_bindings(
    bids_project = mock_bids_project,
    .package = "bidser"
  )

  # Default fmriprep=FALSE, default prep_dir -> no warning
  expect_no_warning(
    on_bids(handle)
  )
})


# ==============================================================================
# Auto-fetch Tests
# ==============================================================================

test_that("on_bids auto-fetches pending handle", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  # Create valid BIDS structure
  tmp <- create_temp_bids()

  # Create pending handle
  handle <- on_handle("ds000001")
  expect_equal(handle$state, "pending")

  # Mock on_fetch to return a ready handle pointing to our temp dir
  fetch_called <- FALSE
  local_mocked_bindings(
    on_fetch.openneuro_handle = function(h, ...) {
      fetch_called <<- TRUE
      h$state <- "ready"
      h$path <- tmp
      h$fetch_time <- Sys.time()
      h
    }
  )

  mock_bids_project <- function(...) {
    structure(list(...), class = "bids_project")
  }

  local_mocked_bindings(
    bids_project = mock_bids_project,
    .package = "bidser"
  )

  result <- on_bids(handle)

  expect_true(fetch_called)
  expect_s3_class(result, "bids_project")
})


# ==============================================================================
# Mocked Successful Creation Tests
# ==============================================================================

test_that("on_bids creates bids_project with correct path", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  tmp <- create_temp_bids()
  handle <- mock_ready_handle(tmp)

  captured_args <- NULL
  mock_bids_project <- function(...) {
    captured_args <<- list(...)
    structure(list(...), class = "bids_project")
  }

  local_mocked_bindings(
    bids_project = mock_bids_project,
    .package = "bidser"
  )

  on_bids(handle)

  expect_equal(captured_args$path, tmp)
})

test_that("on_bids passes fmriprep=TRUE correctly", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  tmp <- create_temp_bids_with_derivatives()
  handle <- mock_ready_handle(tmp)

  captured_args <- NULL
  mock_bids_project <- function(...) {
    captured_args <<- list(...)
    structure(list(...), class = "bids_project")
  }

  local_mocked_bindings(
    bids_project = mock_bids_project,
    .package = "bidser"
  )

  on_bids(handle, fmriprep = TRUE)

  expect_true(captured_args$fmriprep)
})

test_that("on_bids passes custom prep_dir correctly", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  tmp <- create_temp_bids()
  # Create custom derivatives path
  fs::dir_create(fs::path(tmp, "derivatives", "my-pipeline"), recurse = TRUE)
  handle <- mock_ready_handle(tmp)

  captured_args <- NULL
  mock_bids_project <- function(...) {
    captured_args <<- list(...)
    structure(list(...), class = "bids_project")
  }

  local_mocked_bindings(
    bids_project = mock_bids_project,
    .package = "bidser"
  )

  on_bids(handle, prep_dir = "derivatives/my-pipeline")

  expect_equal(captured_args$prep_dir, "derivatives/my-pipeline")
  # When custom prep_dir is used, fmriprep should be FALSE
  expect_false(captured_args$fmriprep)
})

test_that("on_bids prep_dir overrides fmriprep=TRUE", {
  local_mocked_bindings(
    check_installed = function(...) invisible(NULL),
    .package = "rlang"
  )

  tmp <- create_temp_bids()
  fs::dir_create(fs::path(tmp, "derivatives", "custom"), recurse = TRUE)
  handle <- mock_ready_handle(tmp)

  captured_args <- NULL
  mock_bids_project <- function(...) {
    captured_args <<- list(...)
    structure(list(...), class = "bids_project")
  }

  local_mocked_bindings(
    bids_project = mock_bids_project,
    .package = "bidser"
  )

  # Both specified: prep_dir should win
  on_bids(handle, fmriprep = TRUE, prep_dir = "derivatives/custom")

  # fmriprep should be FALSE when custom prep_dir is used
  expect_false(captured_args$fmriprep)
  expect_equal(captured_args$prep_dir, "derivatives/custom")
})


# ==============================================================================
# Dependency Check Tests
# ==============================================================================

test_that("on_bids calls check_installed for bidser", {
  check_installed_called <- FALSE
  local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if (pkg == "bidser") {
        check_installed_called <<- TRUE
      }
      invisible(NULL)
    },
    .package = "rlang"
  )

  tmp <- create_temp_bids()
  handle <- mock_ready_handle(tmp)

  mock_bids_project <- function(...) {
    structure(list(...), class = "bids_project")
  }

  local_mocked_bindings(
    bids_project = mock_bids_project,
    .package = "bidser"
  )

  on_bids(handle)

  expect_true(check_installed_called)
})


# ==============================================================================
# Integration Tests (skip if bidser not installed)
# ==============================================================================

test_that("on_bids creates bids_project from ready handle (integration)", {
  skip_if_not_installed("bidser")

  tmp <- create_temp_bids()
  # Add minimal BIDS subject structure for bidser
  subj_dir <- fs::path(tmp, "sub-01", "anat")
  fs::dir_create(subj_dir, recurse = TRUE)
  writeLines("", fs::path(subj_dir, "sub-01_T1w.nii.gz"))
  # bidser requires participants.tsv
  writeLines("participant_id\nsub-01", fs::path(tmp, "participants.tsv"))

  handle <- mock_ready_handle(tmp)

  result <- on_bids(handle)

  expect_s3_class(result, "bids_project")
})

test_that("on_bids with fmriprep=TRUE works (integration)", {
  skip_if_not_installed("bidser")

  tmp <- create_temp_bids_with_derivatives()
  # Add minimal BIDS subject structure
  subj_dir <- fs::path(tmp, "sub-01", "anat")
  fs::dir_create(subj_dir, recurse = TRUE)
  writeLines("", fs::path(subj_dir, "sub-01_T1w.nii.gz"))
  # bidser requires participants.tsv
  writeLines("participant_id\nsub-01", fs::path(tmp, "participants.tsv"))

  handle <- mock_ready_handle(tmp)

  result <- on_bids(handle, fmriprep = TRUE)

  expect_s3_class(result, "bids_project")
})
