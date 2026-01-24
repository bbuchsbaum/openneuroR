# Tests for download-derivatives.R - on_download_derivatives() and helper functions
# Uses local_mocked_bindings() to mock all network dependencies

# --- Input Validation Tests ---

test_that("on_download_derivatives validates dataset_id parameter - empty string", {
  expect_error(
    on_download_derivatives("", "fmriprep"),
    class = "openneuro_validation_error"
  )
})

test_that("on_download_derivatives validates dataset_id parameter - NULL", {
  expect_error(
    on_download_derivatives(NULL, "fmriprep"),
    class = "openneuro_validation_error"
  )
})

test_that("on_download_derivatives validates dataset_id parameter - non-character", {
  expect_error(
    on_download_derivatives(123, "fmriprep"),
    class = "openneuro_validation_error"
  )
})

test_that("on_download_derivatives validates pipeline parameter - empty string", {
  expect_error(
    on_download_derivatives("ds000001", ""),
    class = "openneuro_validation_error"
  )
})

test_that("on_download_derivatives validates pipeline parameter - NULL", {
  expect_error(
    on_download_derivatives("ds000001", NULL),
    class = "openneuro_validation_error"
  )
})

# --- Derivative Lookup Tests ---

test_that("on_download_derivatives errors when no derivatives exist", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = character(),
      pipeline = character(),
      source = character()
    )
  )

  expect_error(
    on_download_derivatives("ds000001", "fmriprep", quiet = TRUE),
    class = "openneuro_validation_error"
  )
})

test_that("on_download_derivatives errors when pipeline not found", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = c("mriqc"),
      source = c("embedded")
    )
  )

  expect_error(
    on_download_derivatives("ds000001", "fmriprep", quiet = TRUE),
    class = "openneuro_validation_error"
  )
})

# --- Subject Filtering Tests ---

test_that("on_download_derivatives filters by literal subjects", {
  cache_dir <- local_temp_cache()
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("dataset_description.json",
                   "sub-01_space-MNI_bold.nii.gz",
                   "sub-02_space-MNI_bold.nii.gz",
                   "sub-03_space-MNI_bold.nii.gz"),
      full_path = c("dataset_description.json",
                    "sub-01/func/sub-01_space-MNI_bold.nii.gz",
                    "sub-02/func/sub-02_space-MNI_bold.nii.gz",
                    "sub-03/func/sub-03_space-MNI_bold.nii.gz"),
      size = c(100, 1000, 1000, 1000)
    ),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet, bucket) {
      files_passed <<- files
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  on_download_derivatives("ds000001", "fmriprep",
                          subjects = c("sub-01", "sub-02"),
                          quiet = TRUE)

  # Should include root file + sub-01 and sub-02 only

  expect_true("dataset_description.json" %in% files_passed)
  expect_true("sub-01/func/sub-01_space-MNI_bold.nii.gz" %in% files_passed)
  expect_true("sub-02/func/sub-02_space-MNI_bold.nii.gz" %in% files_passed)
  expect_false("sub-03/func/sub-03_space-MNI_bold.nii.gz" %in% files_passed)
})

test_that("on_download_derivatives filters by regex() subjects", {
  cache_dir <- local_temp_cache()
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("dataset_description.json",
                   "sub-01_bold.nii.gz", "sub-02_bold.nii.gz",
                   "sub-10_bold.nii.gz", "sub-11_bold.nii.gz"),
      full_path = c("dataset_description.json",
                    "sub-01/func/sub-01_bold.nii.gz",
                    "sub-02/func/sub-02_bold.nii.gz",
                    "sub-10/func/sub-10_bold.nii.gz",
                    "sub-11/func/sub-11_bold.nii.gz"),
      size = c(100, 1000, 1000, 1000, 1000)
    ),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet, bucket) {
      files_passed <<- files
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  on_download_derivatives("ds000001", "fmriprep",
                          subjects = regex("sub-0[12]"),
                          quiet = TRUE)

  # Should include root + sub-01 and sub-02 (matching regex)
  expect_true("dataset_description.json" %in% files_passed)
  expect_true("sub-01/func/sub-01_bold.nii.gz" %in% files_passed)
  expect_true("sub-02/func/sub-02_bold.nii.gz" %in% files_passed)
  expect_false("sub-10/func/sub-10_bold.nii.gz" %in% files_passed)
  expect_false("sub-11/func/sub-11_bold.nii.gz" %in% files_passed)
})

test_that("on_download_derivatives accepts subject IDs without sub- prefix", {
  cache_dir <- local_temp_cache()
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("sub-01_bold.nii.gz", "sub-02_bold.nii.gz"),
      full_path = c("sub-01/func/sub-01_bold.nii.gz",
                    "sub-02/func/sub-02_bold.nii.gz"),
      size = c(1000, 1000)
    ),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet, bucket) {
      files_passed <<- files
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  on_download_derivatives("ds000001", "fmriprep",
                          subjects = "01",  # Without sub- prefix
                          quiet = TRUE)

  expect_true("sub-01/func/sub-01_bold.nii.gz" %in% files_passed)
  expect_false("sub-02/func/sub-02_bold.nii.gz" %in% files_passed)
})

# --- Space Filtering Tests ---

test_that("on_download_derivatives filters by space parameter", {
  cache_dir <- local_temp_cache()
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("dataset_description.json",
                   "sub-01_space-MNI152NLin2009cAsym_bold.nii.gz",
                   "sub-01_space-T1w_bold.nii.gz",
                   "sub-01_space-fsaverage_bold.func.gii"),
      full_path = c("dataset_description.json",
                    "sub-01/func/sub-01_space-MNI152NLin2009cAsym_bold.nii.gz",
                    "sub-01/func/sub-01_space-T1w_bold.nii.gz",
                    "sub-01/func/sub-01_space-fsaverage_bold.func.gii"),
      size = c(100, 1000, 1000, 500)
    ),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet, bucket) {
      files_passed <<- files
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  on_download_derivatives("ds000001", "fmriprep",
                          space = "MNI152NLin2009cAsym",
                          quiet = TRUE)

  # Should include MNI files + root file (no space entity)
  expect_true("dataset_description.json" %in% files_passed)
  expect_true("sub-01/func/sub-01_space-MNI152NLin2009cAsym_bold.nii.gz" %in% files_passed)
  expect_false("sub-01/func/sub-01_space-T1w_bold.nii.gz" %in% files_passed)
  expect_false("sub-01/func/sub-01_space-fsaverage_bold.func.gii" %in% files_passed)
})

test_that("on_download_derivatives includes files without space entity", {
  cache_dir <- local_temp_cache()
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("dataset_description.json",
                   "sub-01_desc-confounds_timeseries.tsv",
                   "sub-01_space-MNI_bold.nii.gz"),
      full_path = c("dataset_description.json",
                    "sub-01/func/sub-01_desc-confounds_timeseries.tsv",
                    "sub-01/func/sub-01_space-MNI_bold.nii.gz"),
      size = c(100, 200, 1000)
    ),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet, bucket) {
      files_passed <<- files
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  on_download_derivatives("ds000001", "fmriprep",
                          space = "MNI",
                          quiet = TRUE)

  # Files without _space- entity should be included (native space per BIDS)
  expect_true("dataset_description.json" %in% files_passed)
  expect_true("sub-01/func/sub-01_desc-confounds_timeseries.tsv" %in% files_passed)
  expect_true("sub-01/func/sub-01_space-MNI_bold.nii.gz" %in% files_passed)
})

test_that("on_download_derivatives warns for unknown space", {
  cache_dir <- local_temp_cache()

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("sub-01_space-MNI_bold.nii.gz"),
      full_path = c("sub-01/func/sub-01_space-MNI_bold.nii.gz"),
      size = c(1000)
    ),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet, bucket) {
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  # Request a space that doesn't exist in files
  expect_warning(
    on_download_derivatives("ds000001", "fmriprep",
                            space = "fsaverage",
                            quiet = TRUE),
    class = "openneuro_space_warning"
  )
})

# --- Suffix Filtering Tests ---

test_that("on_download_derivatives filters by suffix parameter", {
  cache_dir <- local_temp_cache()
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("dataset_description.json",
                   "sub-01_space-MNI_desc-preproc_bold.nii.gz",
                   "sub-01_space-MNI_desc-brain_mask.nii.gz",
                   "sub-01_space-MNI_T1w.nii.gz"),
      full_path = c("dataset_description.json",
                    "sub-01/func/sub-01_space-MNI_desc-preproc_bold.nii.gz",
                    "sub-01/func/sub-01_space-MNI_desc-brain_mask.nii.gz",
                    "sub-01/anat/sub-01_space-MNI_T1w.nii.gz"),
      size = c(100, 1000, 500, 800)
    ),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet, bucket) {
      files_passed <<- files
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  on_download_derivatives("ds000001", "fmriprep",
                          suffix = c("bold", "mask"),
                          quiet = TRUE)

  # Should include bold and mask files
  # dataset_description.json has suffix "description" so it gets filtered out
  expect_false("dataset_description.json" %in% files_passed)
  expect_true("sub-01/func/sub-01_space-MNI_desc-preproc_bold.nii.gz" %in% files_passed)
  expect_true("sub-01/func/sub-01_space-MNI_desc-brain_mask.nii.gz" %in% files_passed)
  expect_false("sub-01/anat/sub-01_space-MNI_T1w.nii.gz" %in% files_passed)
})

test_that("on_download_derivatives includes metadata files when filtering by suffix", {
  cache_dir <- local_temp_cache()
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("dataset_description.json", "logs.html",
                   "sub-01_bold.nii.gz"),
      full_path = c("dataset_description.json", "logs.html",
                    "sub-01/func/sub-01_bold.nii.gz"),
      size = c(100, 50, 1000)
    ),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet, bucket) {
      files_passed <<- files
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  on_download_derivatives("ds000001", "fmriprep",
                          suffix = "bold",
                          quiet = TRUE)

  # Files with extracted suffix that doesn't match get filtered out
  # dataset_description.json has suffix "description" - filtered out
  expect_false("dataset_description.json" %in% files_passed)
  expect_true("sub-01/func/sub-01_bold.nii.gz" %in% files_passed)
  # logs.html doesn't have underscore so suffix extraction returns NA - included
  expect_true("logs.html" %in% files_passed)
})

# --- Combined Filter Tests (AND Logic) ---

test_that("on_download_derivatives combines filters with AND logic", {
  cache_dir <- local_temp_cache()
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("dataset_description.json",
                   # sub-01, MNI, bold
                   "sub-01_space-MNI_bold.nii.gz",
                   # sub-01, MNI, mask
                   "sub-01_space-MNI_mask.nii.gz",
                   # sub-01, T1w, bold
                   "sub-01_space-T1w_bold.nii.gz",
                   # sub-02, MNI, bold
                   "sub-02_space-MNI_bold.nii.gz"),
      full_path = c("dataset_description.json",
                    "sub-01/func/sub-01_space-MNI_bold.nii.gz",
                    "sub-01/func/sub-01_space-MNI_mask.nii.gz",
                    "sub-01/func/sub-01_space-T1w_bold.nii.gz",
                    "sub-02/func/sub-02_space-MNI_bold.nii.gz"),
      size = c(100, 1000, 500, 1000, 1000)
    ),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet, bucket) {
      files_passed <<- files
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  on_download_derivatives("ds000001", "fmriprep",
                          subjects = "sub-01",
                          space = "MNI",
                          suffix = "bold",
                          quiet = TRUE)

  # Only sub-01 + MNI space + bold suffix should match (AND all three)
  # dataset_description.json has suffix "description" so gets filtered out
  expect_false("dataset_description.json" %in% files_passed)
  expect_true("sub-01/func/sub-01_space-MNI_bold.nii.gz" %in% files_passed)  # matches all
  expect_false("sub-01/func/sub-01_space-MNI_mask.nii.gz" %in% files_passed)  # wrong suffix

  expect_false("sub-01/func/sub-01_space-T1w_bold.nii.gz" %in% files_passed)  # wrong space
  expect_false("sub-02/func/sub-02_space-MNI_bold.nii.gz" %in% files_passed)  # wrong subject
})

# --- dry_run Tests ---

test_that("on_download_derivatives dry_run returns tibble without downloading", {
  cache_dir <- local_temp_cache()
  download_called <- FALSE

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("sub-01_bold.nii.gz", "sub-01_T1w.nii.gz"),
      full_path = c("sub-01/func/sub-01_bold.nii.gz",
                    "sub-01/anat/sub-01_T1w.nii.gz"),
      size = c(1000, 800)
    ),
    .download_with_backend = function(...) {
      download_called <<- TRUE
      list(success = TRUE, backend = "s3")
    }
  )

  result <- on_download_derivatives("ds000001", "fmriprep",
                                     dry_run = TRUE,
                                     quiet = TRUE)

  expect_s3_class(result, "tbl_df")
  expect_false(download_called)
  expect_true("path" %in% names(result))
  expect_true("size" %in% names(result))
  expect_true("size_formatted" %in% names(result))
  expect_true("dest_path" %in% names(result))
  expect_equal(nrow(result), 2L)
})

test_that("on_download_derivatives dry_run with no matching files returns empty tibble", {
  cache_dir <- local_temp_cache()

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("sub-01_space-MNI_bold.nii.gz"),
      full_path = c("sub-01/func/sub-01_space-MNI_bold.nii.gz"),
      size = c(1000)
    )
  )

  result <- on_download_derivatives("ds000001", "fmriprep",
                                     subjects = "sub-99",  # No match
                                     dry_run = TRUE,
                                     quiet = TRUE)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
})

# --- Backend and Cache Path Tests ---

test_that("on_download_derivatives uses openneuro-derivatives bucket", {
  cache_dir <- local_temp_cache()
  bucket_used <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("sub-01_bold.nii.gz"),
      full_path = c("sub-01/func/sub-01_bold.nii.gz"),
      size = c(1000)
    ),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet, bucket) {
      bucket_used <<- bucket
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  on_download_derivatives("ds000001", "fmriprep", quiet = TRUE)

  expect_equal(bucket_used, "openneuro-derivatives")
})

test_that("on_download_derivatives constructs correct S3 dataset ID", {
  cache_dir <- local_temp_cache()
  dataset_id_used <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("sub-01_bold.nii.gz"),
      full_path = c("sub-01/func/sub-01_bold.nii.gz"),
      size = c(1000)
    ),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet, bucket) {
      dataset_id_used <<- dataset_id
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  on_download_derivatives("ds000001", "fmriprep", quiet = TRUE)

  # S3 path should be: {pipeline}/{dataset_id}-{pipeline}
  expect_equal(dataset_id_used, "fmriprep/ds000001-fmriprep")
})

test_that("on_download_derivatives uses derivative cache path", {
  cache_dir <- local_temp_cache()
  dest_used <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("sub-01_bold.nii.gz"),
      full_path = c("sub-01/func/sub-01_bold.nii.gz"),
      size = c(1000)
    ),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet, bucket) {
      dest_used <<- dest_dir
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  on_download_derivatives("ds000001", "fmriprep", quiet = TRUE)

  # Destination should be {cache}/ds000001/derivatives/fmriprep/
  expect_true(grepl("ds000001", dest_used))
  expect_true(grepl("derivatives", dest_used))
  expect_true(grepl("fmriprep", dest_used))
})

# --- Helper Function Tests ---

test_that(".filter_files_by_space returns all files when space is NULL", {
  files_df <- tibble::tibble(
    filename = c("file1.nii.gz", "file2.nii.gz"),
    full_path = c("sub-01_space-MNI_bold.nii.gz",
                  "sub-01_space-T1w_bold.nii.gz"),
    size = c(100, 100)
  )

  result <- .filter_files_by_space(files_df, NULL)
  expect_equal(nrow(result), 2L)
})

test_that(".filter_files_by_suffix returns all files when suffix is NULL", {
  files_df <- tibble::tibble(
    filename = c("file1.nii.gz", "file2.nii.gz"),
    full_path = c("sub-01_bold.nii.gz", "sub-01_T1w.nii.gz"),
    size = c(100, 100)
  )

  result <- .filter_files_by_suffix(files_df, NULL)
  expect_equal(nrow(result), 2L)
})

test_that(".extract_suffix_from_filename handles various extensions", {
  # Standard BIDS filename
  expect_equal(.extract_suffix_from_filename("sub-01_space-MNI_bold.nii.gz"), "bold")
  expect_equal(.extract_suffix_from_filename("sub-01_desc-preproc_T1w.nii.gz"), "T1w")
  expect_equal(.extract_suffix_from_filename("sub-01_desc-brain_mask.nii.gz"), "mask")

  # Compound extensions
  expect_equal(.extract_suffix_from_filename("sub-01_hemi-L_bold.func.gii"), "bold")
  expect_equal(.extract_suffix_from_filename("sub-01_bold.dtseries.nii"), "bold")

  # JSON sidecar
  expect_equal(.extract_suffix_from_filename("sub-01_bold.json"), "bold")

  # TSV files
  expect_equal(.extract_suffix_from_filename("sub-01_desc-confounds_timeseries.tsv"), "timeseries")

  # Files with underscore return last part as suffix
  expect_equal(.extract_suffix_from_filename("dataset_description.json"), "description")

  # Non-BIDS files without underscore return NA
  expect_true(is.na(.extract_suffix_from_filename("README")))
})

test_that(".on_derivative_cache_path returns correct structure", {
  cache_dir <- local_temp_cache()
  path <- .on_derivative_cache_path("ds000001", "fmriprep")

  # Should end with derivatives/fmriprep
  path_parts <- strsplit(as.character(path), "/")[[1]]
  n <- length(path_parts)
  expect_equal(path_parts[n], "fmriprep")
  expect_equal(path_parts[n-1], "derivatives")
  expect_equal(path_parts[n-2], "ds000001")
})

test_that(".empty_derivative_files_tibble returns correct structure", {
  result <- .empty_derivative_files_tibble()

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_true("filename" %in% names(result))
  expect_true("full_path" %in% names(result))
  expect_true("size" %in% names(result))
})

# --- Return Value Structure Tests ---

test_that("on_download_derivatives returns correct structure on success", {
  cache_dir <- local_temp_cache()

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = c("sub-01_bold.nii.gz"),
      full_path = c("sub-01/func/sub-01_bold.nii.gz"),
      size = c(1000)
    ),
    .download_with_backend = function(...) {
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  result <- on_download_derivatives("ds000001", "fmriprep", quiet = TRUE)

  expect_type(result, "list")
  expect_true("downloaded" %in% names(result))
  expect_true("skipped" %in% names(result))
  expect_true("failed" %in% names(result))
  expect_true("total_bytes" %in% names(result))
  expect_true("dest_dir" %in% names(result))
  expect_true("backend" %in% names(result))
})

test_that("on_download_derivatives returns zeros when no files found", {
  cache_dir <- local_temp_cache()

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_derivatives = function(...) tibble::tibble(
      dataset_id = "ds000001",
      pipeline = "fmriprep",
      source = "openneuro-derivatives"
    ),
    .list_derivative_files_full = function(...) tibble::tibble(
      filename = character(),
      full_path = character(),
      size = numeric()
    )
  )

  result <- on_download_derivatives("ds000001", "fmriprep", quiet = TRUE)

  expect_equal(result$downloaded, 0L)
  expect_equal(result$skipped, 0L)
  expect_equal(result$failed, character())
})


# --- Manifest Type Field Tests ---

test_that(".update_manifest adds type field to entries", {
  cache_dir <- local_temp_cache()
  dataset_dir <- file.path(cache_dir, "ds000001")
  fs::dir_create(dataset_dir)

  .update_manifest(
    dataset_dir = dataset_dir,
    new_file_info = list(path = "test.txt", size = 100),
    dataset_id = "ds000001",
    snapshot_tag = "1.0.0",
    backend = "https",
    type = "derivative"
  )

  manifest <- .read_manifest(dataset_dir)
  expect_equal(manifest$files[[1]]$type, "derivative")
})

test_that(".update_manifest defaults type to 'raw'", {
  cache_dir <- local_temp_cache()
  dataset_dir <- file.path(cache_dir, "ds000002")
  fs::dir_create(dataset_dir)

  # Call without type parameter (should default to "raw")
  .update_manifest(
    dataset_dir = dataset_dir,
    new_file_info = list(path = "participants.tsv", size = 200),
    dataset_id = "ds000002",
    snapshot_tag = "2.0.0",
    backend = "https"
  )

  manifest <- .read_manifest(dataset_dir)
  expect_equal(manifest$files[[1]]$type, "raw")
})

test_that(".update_manifest preserves type when updating existing entry", {
  cache_dir <- local_temp_cache()
  dataset_dir <- file.path(cache_dir, "ds000003")
  fs::dir_create(dataset_dir)

  # First entry as derivative
  .update_manifest(
    dataset_dir = dataset_dir,
    new_file_info = list(path = "sub-01_bold.nii.gz", size = 1000),
    dataset_id = "ds000003",
    snapshot_tag = "1.0.0",
    backend = "s3",
    type = "derivative"
  )

  # Update same file (e.g., re-download)
  .update_manifest(
    dataset_dir = dataset_dir,
    new_file_info = list(path = "sub-01_bold.nii.gz", size = 1100),
    dataset_id = "ds000003",
    snapshot_tag = "1.0.0",
    backend = "https",
    type = "derivative"
  )

  manifest <- .read_manifest(dataset_dir)
  # Should still have only one entry
  expect_equal(length(manifest$files), 1L)
  expect_equal(manifest$files[[1]]$type, "derivative")
  expect_equal(manifest$files[[1]]$size, 1100)
})


# --- on_cache_list() Type Column Tests ---

test_that("on_cache_list includes type column", {
  cache_dir <- local_temp_cache()

  # Create a dataset with manifest
  dataset_dir <- file.path(cache_dir, "ds000001")
  fs::dir_create(dataset_dir)

  .update_manifest(
    dataset_dir = dataset_dir,
    new_file_info = list(path = "participants.tsv", size = 100),
    dataset_id = "ds000001",
    snapshot_tag = "1.0.0",
    backend = "https",
    type = "raw"
  )

  result <- on_cache_list()

  expect_true("type" %in% names(result))
  expect_equal(nrow(result), 1L)
  expect_equal(result$type[[1]], "raw")
})

test_that("on_cache_list shows 'derivative' for derivative-only cache", {
  cache_dir <- local_temp_cache()

  # Create a dataset with only derivative entries in root manifest
  dataset_dir <- file.path(cache_dir, "ds000001")
  fs::dir_create(dataset_dir)

  .update_manifest(
    dataset_dir = dataset_dir,
    new_file_info = list(path = "derivatives/fmriprep/sub-01_bold.nii.gz", size = 1000),
    dataset_id = "ds000001",
    snapshot_tag = "fmriprep-derivative",
    backend = "s3",
    type = "derivative"
  )

  result <- on_cache_list()

  # Should find the ds000001 directory
  ds_row <- result[result$dataset_id == "ds000001", ]
  expect_equal(nrow(ds_row), 1L)
  expect_equal(ds_row$type[[1]], "derivative")
})

test_that("on_cache_list shows 'raw+derivative' for mixed cache", {
  cache_dir <- local_temp_cache()

  # Create a dataset with both raw and derivative entries
  dataset_dir <- file.path(cache_dir, "ds000001")
  fs::dir_create(dataset_dir)

  # Add raw file
  .update_manifest(
    dataset_dir = dataset_dir,
    new_file_info = list(path = "participants.tsv", size = 100),
    dataset_id = "ds000001",
    snapshot_tag = "1.0.0",
    backend = "https",
    type = "raw"
  )

  # Add derivative file
  .update_manifest(
    dataset_dir = dataset_dir,
    new_file_info = list(path = "derivatives/fmriprep/sub-01_bold.nii.gz", size = 1000),
    dataset_id = "ds000001",
    snapshot_tag = "1.0.0",
    backend = "s3",
    type = "derivative"
  )

  result <- on_cache_list()

  ds_row <- result[result$dataset_id == "ds000001", ]
  expect_equal(nrow(ds_row), 1L)
  expect_equal(ds_row$type[[1]], "raw+derivative")
})

test_that("manifests without type field default to 'raw'", {
  cache_dir <- local_temp_cache()

  # Create a dataset with an old-style manifest (no type field)
  dataset_dir <- file.path(cache_dir, "ds000001")
  fs::dir_create(dataset_dir)

  # Write manifest directly without type field
  old_manifest <- list(
    schema_version = 1L,
    dataset_id = "ds000001",
    snapshot_tag = "1.0.0",
    cached_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    files = list(
      list(
        path = "participants.tsv",
        size = 100,
        downloaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        backend = "https"
        # Note: no type field
      )
    )
  )

  jsonlite::write_json(old_manifest,
                       file.path(dataset_dir, "manifest.json"),
                       auto_unbox = TRUE, pretty = TRUE)

  result <- on_cache_list()

  ds_row <- result[result$dataset_id == "ds000001", ]
  expect_equal(nrow(ds_row), 1L)
  # Should default to "raw" for backward compatibility
  expect_equal(ds_row$type[[1]], "raw")
})

test_that("on_cache_list returns empty tibble with type column when no cache", {
  cache_dir <- local_temp_cache()

  result <- on_cache_list()

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_true("type" %in% names(result))
})
