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
