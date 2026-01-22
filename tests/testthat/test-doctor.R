# Tests for on_doctor() diagnostic function
# Uses local_mocked_bindings() to avoid CLI invocations

test_that("on_doctor returns openneuro_doctor class", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) backend == "https",
    .get_aws_version = function() NA_character_,
    .get_datalad_version = function() NA_character_
  )
  result <- on_doctor()
  expect_s3_class(result, "openneuro_doctor")
})

test_that("on_doctor contains all backends", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) TRUE,
    .get_aws_version = function() "2.15.0",
    .get_datalad_version = function() "0.19.3"
  )
  result <- on_doctor()
  expect_named(result, c("https", "s3", "datalad"))
})

test_that("on_doctor https is always available", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) backend == "https",
    .get_aws_version = function() NA_character_,
    .get_datalad_version = function() NA_character_
  )
  result <- on_doctor()
  expect_true(result$https$available)
  expect_true(is.na(result$https$version))
})

test_that("on_doctor reports available s3 with version", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) TRUE,
    .get_aws_version = function() "2.15.0",
    .get_datalad_version = function() "0.19.3"
  )
  result <- on_doctor()
  expect_true(result$s3$available)
  expect_equal(result$s3$version, "2.15.0")
})

test_that("on_doctor reports unavailable s3", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) backend == "https",
    .get_aws_version = function() NA_character_,
    .get_datalad_version = function() NA_character_
  )
  result <- on_doctor()
  expect_false(result$s3$available)
  expect_true(is.na(result$s3$version))
})

test_that("on_doctor reports available datalad with version", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) TRUE,
    .get_aws_version = function() "2.15.0",
    .get_datalad_version = function() "0.19.3"
  )
  result <- on_doctor()
  expect_true(result$datalad$available)
  expect_equal(result$datalad$version, "0.19.3")
})

test_that("on_doctor reports unavailable datalad", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) backend != "datalad",
    .get_aws_version = function() "2.15.0",
    .get_datalad_version = function() NA_character_
  )
  result <- on_doctor()
  expect_false(result$datalad$available)
  expect_true(is.na(result$datalad$version))
})

test_that("print.openneuro_doctor runs without error", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) TRUE,
    .get_aws_version = function() "2.15.0",
    .get_datalad_version = function() "0.19.3"
  )
  result <- on_doctor()
  expect_no_error(print(result))
})

test_that("print.openneuro_doctor runs when backends missing", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) backend == "https",
    .get_aws_version = function() NA_character_,
    .get_datalad_version = function() NA_character_
  )
  result <- on_doctor()
  expect_no_error(print(result))
})

test_that("print.openneuro_doctor returns invisibly", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) TRUE,
    .get_aws_version = function() "2.15.0",
    .get_datalad_version = function() "0.19.3"
  )
  result <- on_doctor()
  print_result <- withVisible(print(result))
  expect_false(print_result$visible)
  expect_s3_class(print_result$value, "openneuro_doctor")
})

# --- .get_aws_version tests ---

test_that(".get_aws_version returns NA when aws cli not found", {
  local_mocked_bindings(
    .find_aws_cli = function() ""
  )
  result <- .get_aws_version()
  expect_true(is.na(result))
})

test_that(".get_aws_version returns version string from valid output", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )
  local_mocked_bindings(
    run = function(command, args, ...) {
      list(
        status = 0L,
        stdout = "aws-cli/2.15.0 Python/3.11.6 Darwin/23.0.0 source/arm64\n"
      )
    },
    .package = "processx"
  )
  result <- .get_aws_version()
  expect_equal(result, "2.15.0")
})

test_that(".get_aws_version returns NA on processx error", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )
  local_mocked_bindings(
    run = function(...) {
      stop("Command failed")
    },
    .package = "processx"
  )
  result <- .get_aws_version()
  expect_true(is.na(result))
})

test_that(".get_aws_version returns NA when version parse fails", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )
  local_mocked_bindings(
    run = function(command, args, ...) {
      list(
        status = 0L,
        stdout = "some unexpected output format\n"
      )
    },
    .package = "processx"
  )
  result <- .get_aws_version()
  expect_true(is.na(result))
})

test_that(".get_aws_version handles non-zero status", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )
  local_mocked_bindings(
    run = function(command, args, ...) {
      list(
        status = 1L,
        stdout = ""
      )
    },
    .package = "processx"
  )
  result <- .get_aws_version()
  expect_true(is.na(result))
})

# --- .get_datalad_version tests ---

test_that(".get_datalad_version returns NA or version string", {
  # Test that the function returns the expected type without mocking
  # (NA_character_ if datalad not installed, version string if installed)
  result <- .get_datalad_version()
  expect_type(result, "character")
  # Either NA or a version-like string
  if (!is.na(result)) {
    expect_true(grepl("^[0-9]+\\.[0-9]+", result))
  }
})

test_that(".get_datalad_version returns NA on processx error", {
  # Skip if datalad not installed (can't test processx error path)
  skip_if(!nzchar(Sys.which("datalad")), "datalad not installed")

  local_mocked_bindings(
    run = function(...) {
      stop("Command failed")
    },
    .package = "processx"
  )
  result <- .get_datalad_version()
  # Should return NA since processx::run will fail
  expect_true(is.na(result))
})

test_that(".get_datalad_version returns NA when version parse fails", {
  # Skip if datalad not installed (can't test parse failure path)
  skip_if(!nzchar(Sys.which("datalad")), "datalad not installed")

  local_mocked_bindings(
    run = function(command, args, ...) {
      list(
        status = 0L,
        stdout = "unexpected output without version number\n"
      )
    },
    .package = "processx"
  )
  result <- .get_datalad_version()
  expect_true(is.na(result))
})
