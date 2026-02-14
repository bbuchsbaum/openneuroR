# Tests for cache-path.R helpers

test_that(".validate_path_under_root allows paths within root", {
  tmp <- withr::local_tempdir()
  root <- file.path(tmp, "cache_root")
  fs::dir_create(root, recurse = TRUE)

  expect_no_error(
    .validate_path_under_root(file.path(root, "sub-01", "file.txt"), root)
  )
})

test_that(".validate_path_under_root blocks prefix-collision siblings", {
  tmp <- withr::local_tempdir()
  root <- file.path(tmp, "cache_root")
  fs::dir_create(root, recurse = TRUE)

  # Sibling path shares string prefix but is not under root.
  evil <- file.path(tmp, "cache_root_evil", "file.txt")

  expect_error(
    .validate_path_under_root(evil, root),
    class = "openneuro_validation_error"
  )
})

test_that(".on_dataset_cache_path enforces dataset ID format", {
  tmp <- withr::local_tempdir()
  withr::local_options(openneuro.cache_root = tmp)

  expect_error(
    .on_dataset_cache_path("../escape"),
    class = "openneuro_validation_error"
  )
})
