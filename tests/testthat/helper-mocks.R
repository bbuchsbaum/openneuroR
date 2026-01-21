# Common test helpers for openneuro package tests

#' Create a temporary cache directory for testing
#'
#' Sets up a temporary directory and configures the openneuro.cache_root option
#' to point to it. The directory and option are automatically cleaned up when
#' the test completes.
#'
#' @param env Environment to use for cleanup scope. Defaults to parent frame.
#' @return Path to the temporary cache directory (invisibly).
#'
#' @examples
#' test_that("caching works", {
#'   cache_dir <- local_temp_cache()
#'   # cache_dir is now active and will be cleaned up after test
#' })
local_temp_cache <- function(env = parent.frame()) {
  tmp <- withr::local_tempdir(.local_envir = env)
  withr::local_options(openneuro.cache_root = tmp, .local_envir = env)
  invisible(tmp)
}

#' Skip test if live tests are not enabled
#'
#' Tests that require actual network calls can be gated behind the
#' OPENNEURO_LIVE_TESTS environment variable. This function skips the
#' test if that variable is NOT set to "true".
#'
#' @examples
#' test_that("live API call works", {
#'   skip_if_live_tests()
#'   # This code only runs if OPENNEURO_LIVE_TESTS=true
#' })
skip_if_live_tests <- function() {
  if (!identical(Sys.getenv("OPENNEURO_LIVE_TESTS"), "true")) {
    testthat::skip("OPENNEURO_LIVE_TESTS not enabled")
  }
}

#' Skip test if httptest2 mocks are not available
#'
#' Skips the test if the specified mock directory does not exist.
#'
#' @param mock_dir Name of the mock directory (relative to testthat directory).
#' @examples
#' test_that("API call with mocks", {
#'   skip_if_no_mocks("api.openneuro.org")
#'   # Test code using mocks
#' })
skip_if_no_mocks <- function(mock_dir) {
  mock_path <- testthat::test_path(mock_dir)
  if (!dir.exists(mock_path)) {
    testthat::skip(paste0("Mock directory '", mock_dir, "' not found"))
  }
}
