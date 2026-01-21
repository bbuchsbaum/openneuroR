# Tests for cache functions
# Uses local_temp_cache() helper to isolate tests

test_that("on_cache_list returns empty tibble for fresh cache", {
  cache_dir <- local_temp_cache()
  result <- on_cache_list()
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("on_cache_list has correct columns", {
  cache_dir <- local_temp_cache()
  result <- on_cache_list()
  expect_named(
    result,
    c("dataset_id", "snapshot_tag", "n_files", "total_size", "size_formatted", "cached_at")
  )
})

test_that("on_cache_info returns correct structure for empty cache", {
  cache_dir <- local_temp_cache()
  result <- on_cache_info()
  expect_type(result, "list")
  expect_named(result, c("cache_path", "n_datasets", "total_size", "size_formatted"))
  expect_equal(result$n_datasets, 0)
  expect_equal(result$total_size, 0)
})

test_that(".on_cache_root respects option", {
  tmp <- withr::local_tempdir()
  withr::local_options(openneuro.cache_root = tmp)
  # Use normalizePath to handle path differences (trailing slashes, etc.)
  expect_equal(normalizePath(.on_cache_root()), normalizePath(tmp))
})

test_that(".on_cache_root creates directory if missing", {
  tmp <- withr::local_tempdir()
  new_path <- file.path(tmp, "subdir", "cache")
  withr::local_options(openneuro.cache_root = new_path)

  result <- .on_cache_root()
  expect_true(dir.exists(result))
  # Use normalizePath to handle path differences
  expect_equal(normalizePath(result), normalizePath(new_path))
})

test_that(".on_dataset_cache_path constructs correct path", {
  tmp <- withr::local_tempdir()
  withr::local_options(openneuro.cache_root = tmp)

  result <- .on_dataset_cache_path("ds000001")
  # Check the path ends with the expected components
  expect_true(grepl("ds000001$", as.character(result)))
})

test_that(".on_file_cache_path constructs correct path", {
  tmp <- withr::local_tempdir()
  withr::local_options(openneuro.cache_root = tmp)

  result <- .on_file_cache_path("ds000001", "sub-01/anat/T1w.nii.gz")
  # Check the path contains expected components
  expect_true(grepl("ds000001", as.character(result)))
  expect_true(grepl("sub-01", as.character(result)))
  expect_true(grepl("T1w.nii.gz$", as.character(result)))
})

test_that("on_cache_clear warns when dataset not in cache", {
  cache_dir <- local_temp_cache()
  expect_message(
    result <- on_cache_clear("ds999999", confirm = FALSE),
    "not in cache"
  )
  expect_equal(result, 0L)
})

test_that("on_cache_clear reports empty cache", {
  cache_dir <- local_temp_cache()
  expect_message(
    result <- on_cache_clear(confirm = FALSE),
    "empty"
  )
  expect_equal(result, 0L)
})

test_that("on_cache_list finds datasets with files", {
  cache_dir <- local_temp_cache()

  # Create a fake cached dataset
  ds_dir <- file.path(cache_dir, "ds000001")
  dir.create(ds_dir, recursive = TRUE)
  writeLines("test content", file.path(ds_dir, "test.txt"))

  result <- on_cache_list()
  expect_equal(nrow(result), 1)
  # dataset_id should be just "ds000001", not the full path
  expect_equal(unname(result$dataset_id[1]), "ds000001")
  expect_equal(unname(result$n_files[1]), 1L)
})

test_that("on_cache_info counts datasets correctly", {
  cache_dir <- local_temp_cache()

  # Create two fake cached datasets
  ds_dir1 <- file.path(cache_dir, "ds000001")
  ds_dir2 <- file.path(cache_dir, "ds000002")
  dir.create(ds_dir1, recursive = TRUE)
  dir.create(ds_dir2, recursive = TRUE)
  writeLines("content1", file.path(ds_dir1, "file1.txt"))
  writeLines("content2", file.path(ds_dir2, "file2.txt"))

  result <- on_cache_info()
  expect_equal(result$n_datasets, 2)
  expect_true(result$total_size > 0)
})
