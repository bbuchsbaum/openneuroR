# Tests for download.R - on_download() and helper functions
# Uses local_mocked_bindings() to mock dependencies

# --- .is_regex tests ---

test_that(".is_regex returns TRUE for asterisk pattern", {
  expect_true(.is_regex("*.nii.gz"))
})

test_that(".is_regex returns TRUE for plus pattern", {
  expect_true(.is_regex("sub-0[1-9]+"))
})

test_that(".is_regex returns TRUE for question mark pattern", {
  expect_true(.is_regex("file?.txt"))
})

test_that(".is_regex returns TRUE for brackets pattern", {
  expect_true(.is_regex("sub-[0-9]"))
})

test_that(".is_regex returns TRUE for caret pattern", {
  expect_true(.is_regex("^participants"))
})

test_that(".is_regex returns TRUE for dollar pattern", {
  expect_true(.is_regex("README$"))
})

test_that(".is_regex returns TRUE for pipe pattern", {
  expect_true(.is_regex("anat|func"))
})

test_that(".is_regex returns TRUE for parentheses pattern", {

  expect_true(.is_regex("(sub-01|sub-02)"))
})

test_that(".is_regex returns FALSE for plain filename", {
  expect_false(.is_regex("participants.tsv"))
})

test_that(".is_regex returns FALSE for path with slashes", {
  expect_false(.is_regex("sub-01/anat/T1w.nii.gz"))
})

test_that(".is_regex returns FALSE for multi-element vector", {
  expect_false(.is_regex(c("file1.txt", "file2.txt")))
})


# --- on_download tests ---

test_that("on_download validates id parameter - empty string", {
  expect_error(
    on_download(""),
    class = "openneuro_validation_error"
  )
})

test_that("on_download validates id parameter - NULL", {
  expect_error(
    on_download(NULL),
    class = "openneuro_validation_error"
  )
})

test_that("on_download validates id parameter - non-character", {
  expect_error(
    on_download(123),
    class = "openneuro_validation_error"
  )
})

test_that("on_download validates id parameter - vector", {
  expect_error(
    on_download(c("ds000001", "ds000002")),
    class = "openneuro_validation_error"
  )
})

test_that("on_download returns early with zeros when no files found", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    .list_all_files = function(...) tibble::tibble(
      filename = character(),
      full_path = character(),
      size = numeric(),
      annexed = logical()
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id)
  )

  # cli_alert_warning is used, not base warning(), so test the result
  result <- on_download("ds000001", quiet = TRUE)

  expect_equal(result$downloaded, 0L)
  expect_equal(result$skipped, 0L)
  expect_equal(result$failed, character())
})

test_that("on_download filters by exact file paths", {
  # Create a mock that tracks what files are passed to backend
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    .list_all_files = function(...) tibble::tibble(
      filename = c("README.md", "participants.tsv", "CHANGES"),
      full_path = c("README.md", "participants.tsv", "CHANGES"),
      size = c(100, 200, 50),
      annexed = c(FALSE, FALSE, FALSE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet) {
      files_passed <<- files
      list(success = TRUE, backend = "https")
    },
    .update_manifest = function(...) invisible(NULL),
    .batch_update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  withr::local_tempdir()
  on_download("ds000001", files = c("README.md", "CHANGES"), quiet = TRUE)

  # Should only include the requested files
  expect_equal(sort(files_passed), sort(c("README.md", "CHANGES")))
})

test_that("on_download filters by regex pattern", {
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    .list_all_files = function(...) tibble::tibble(
      filename = c("README.md", "participants.tsv", "README.txt"),
      full_path = c("README.md", "participants.tsv", "README.txt"),
      size = c(100, 200, 50),
      annexed = c(FALSE, FALSE, FALSE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet) {
      files_passed <<- files
      list(success = TRUE, backend = "https")
    },
    .update_manifest = function(...) invisible(NULL),
    .batch_update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  withr::local_tempdir()
  on_download("ds000001", files = "^README", quiet = TRUE)

  # Should match both README files
  expect_equal(sort(files_passed), sort(c("README.md", "README.txt")))
})

test_that("on_download returns early with zeros when regex matches nothing", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    .list_all_files = function(...) tibble::tibble(
      filename = c("README.md", "participants.tsv"),
      full_path = c("README.md", "participants.tsv"),
      size = c(100, 200),
      annexed = c(FALSE, FALSE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id)
  )

  # cli_alert_warning is used, not base warning(), so test the result
  result <- on_download("ds000001", files = "^nonexistent", quiet = TRUE)

  expect_equal(result$downloaded, 0L)
  expect_equal(result$skipped, 0L)
  expect_equal(result$failed, character())
})

test_that("on_download falls back to HTTPS when backend returns NULL", {
  backend_used <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    .list_all_files = function(...) tibble::tibble(
      filename = c("README.md"),
      full_path = c("README.md"),
      size = c(100),
      annexed = c(FALSE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet) {
      NULL  # Backend not available
    },
    .download_with_progress = function(files_df, dest_dir, dataset_id, tag,
                                        quiet, verbose, force, use_cache) {
      list(
        downloaded = 1L,
        skipped = 0L,
        failed = character(),
        total_bytes = 100,
        dest_dir = dest_dir
      )
    }
  )

  withr::local_tempdir()
  result <- on_download("ds000001", quiet = TRUE)

  # Should use HTTPS fallback

  expect_equal(result$backend, "https")
  expect_equal(result$downloaded, 1L)
})

test_that("on_download returns backend info on S3/DataLad success", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    .list_all_files = function(...) tibble::tibble(
      filename = c("README.md"),
      full_path = c("README.md"),
      size = c(100),
      annexed = c(FALSE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet) {
      list(success = TRUE, backend = "s3")
    },
    .update_manifest = function(...) invisible(NULL),
    .batch_update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  withr::local_tempdir()
  result <- on_download("ds000001", quiet = TRUE)

  expect_true("backend" %in% names(result))
  expect_equal(result$backend, "s3")
})


# --- subjects= parameter tests ---

test_that("on_download filters by literal subject IDs", {
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_subjects = function(...) tibble::tibble(
      dataset_id = "ds000001",
      subject_id = c("01", "02", "03"),
      n_sessions = c(1L, 1L, 1L),
      n_files = c(10L, 10L, 10L)
    ),
    .list_all_files = function(...) tibble::tibble(
      filename = c("dataset_description.json", "participants.tsv",
                   "T1w.nii.gz", "T1w.nii.gz", "T1w.nii.gz"),
      full_path = c("dataset_description.json", "participants.tsv",
                    "sub-01/anat/T1w.nii.gz", "sub-02/anat/T1w.nii.gz",
                    "sub-03/anat/T1w.nii.gz"),
      size = c(100, 200, 1000, 1000, 1000),
      annexed = c(FALSE, FALSE, TRUE, TRUE, TRUE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet) {
      files_passed <<- files
      list(success = TRUE, backend = "https")
    },
    .update_manifest = function(...) invisible(NULL),
    .batch_update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  withr::local_tempdir()
  on_download("ds000001", subjects = c("sub-01"), quiet = TRUE)

  # Should include root files + sub-01 only
  expect_true("dataset_description.json" %in% files_passed)
  expect_true("participants.tsv" %in% files_passed)
  expect_true("sub-01/anat/T1w.nii.gz" %in% files_passed)
  expect_false("sub-02/anat/T1w.nii.gz" %in% files_passed)
  expect_false("sub-03/anat/T1w.nii.gz" %in% files_passed)
})

test_that("on_download filters by regex() subjects", {
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_subjects = function(...) tibble::tibble(
      dataset_id = "ds000001",
      subject_id = c("01", "02", "03", "10", "11"),
      n_sessions = c(1L, 1L, 1L, 1L, 1L),
      n_files = c(10L, 10L, 10L, 10L, 10L)
    ),
    .list_all_files = function(...) tibble::tibble(
      filename = c("dataset_description.json",
                   "T1w.nii.gz", "T1w.nii.gz", "T1w.nii.gz",
                   "T1w.nii.gz", "T1w.nii.gz"),
      full_path = c("dataset_description.json",
                    "sub-01/anat/T1w.nii.gz", "sub-02/anat/T1w.nii.gz",
                    "sub-03/anat/T1w.nii.gz", "sub-10/anat/T1w.nii.gz",
                    "sub-11/anat/T1w.nii.gz"),
      size = c(100, 1000, 1000, 1000, 1000, 1000),
      annexed = c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet) {
      files_passed <<- files
      list(success = TRUE, backend = "https")
    },
    .update_manifest = function(...) invisible(NULL),
    .batch_update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  withr::local_tempdir()
  on_download("ds000001", subjects = regex("sub-0[12]"), quiet = TRUE)

  # Should include root + sub-01 and sub-02
  expect_true("dataset_description.json" %in% files_passed)
  expect_true("sub-01/anat/T1w.nii.gz" %in% files_passed)
  expect_true("sub-02/anat/T1w.nii.gz" %in% files_passed)
  expect_false("sub-03/anat/T1w.nii.gz" %in% files_passed)
  expect_false("sub-10/anat/T1w.nii.gz" %in% files_passed)
})

test_that("on_download errors on invalid subject ID", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_subjects = function(...) tibble::tibble(
      dataset_id = "ds000001",
      subject_id = c("01", "02"),
      n_sessions = c(1L, 1L),
      n_files = c(10L, 10L)
    ),
    .list_all_files = function(...) tibble::tibble(
      filename = c("T1w.nii.gz", "T1w.nii.gz"),
      full_path = c("sub-01/anat/T1w.nii.gz", "sub-02/anat/T1w.nii.gz"),
      size = c(1000, 1000),
      annexed = c(TRUE, TRUE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id)
  )

  expect_error(
    on_download("ds000001", subjects = "99", quiet = TRUE),
    class = "openneuro_validation_error"
  )
})

test_that("on_download errors on regex matching zero subjects", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_subjects = function(...) tibble::tibble(
      dataset_id = "ds000001",
      subject_id = c("01", "02"),
      n_sessions = c(1L, 1L),
      n_files = c(10L, 10L)
    ),
    .list_all_files = function(...) tibble::tibble(
      filename = c("T1w.nii.gz", "T1w.nii.gz"),
      full_path = c("sub-01/anat/T1w.nii.gz", "sub-02/anat/T1w.nii.gz"),
      size = c(1000, 1000),
      annexed = c(TRUE, TRUE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id)
  )

  expect_error(
    on_download("ds000001", subjects = regex("sub-99.*"), quiet = TRUE),
    class = "openneuro_validation_error"
  )
})

test_that("on_download include_derivatives=FALSE excludes derivatives", {
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_subjects = function(...) tibble::tibble(
      dataset_id = "ds000001",
      subject_id = c("01"),
      n_sessions = c(1L),
      n_files = c(10L)
    ),
    .list_all_files = function(...) tibble::tibble(
      filename = c("dataset_description.json",
                   "T1w.nii.gz", "T1w_preproc.nii.gz"),
      full_path = c("dataset_description.json",
                    "sub-01/anat/T1w.nii.gz",
                    "derivatives/fmriprep/sub-01/anat/T1w_preproc.nii.gz"),
      size = c(100, 1000, 1000),
      annexed = c(FALSE, TRUE, TRUE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet) {
      files_passed <<- files
      list(success = TRUE, backend = "https")
    },
    .update_manifest = function(...) invisible(NULL),
    .batch_update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  withr::local_tempdir()
  on_download("ds000001", subjects = "01", include_derivatives = FALSE, quiet = TRUE)

  # Should include root + sub-01 raw, but NOT derivatives
  expect_true("dataset_description.json" %in% files_passed)
  expect_true("sub-01/anat/T1w.nii.gz" %in% files_passed)
  expect_false("derivatives/fmriprep/sub-01/anat/T1w_preproc.nii.gz" %in% files_passed)
})

test_that("on_download includes derivatives by default with subjects=", {
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_subjects = function(...) tibble::tibble(
      dataset_id = "ds000001",
      subject_id = c("01"),
      n_sessions = c(1L),
      n_files = c(10L)
    ),
    .list_all_files = function(...) tibble::tibble(
      filename = c("dataset_description.json",
                   "T1w.nii.gz", "T1w_preproc.nii.gz"),
      full_path = c("dataset_description.json",
                    "sub-01/anat/T1w.nii.gz",
                    "derivatives/fmriprep/sub-01/anat/T1w_preproc.nii.gz"),
      size = c(100, 1000, 1000),
      annexed = c(FALSE, TRUE, TRUE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet) {
      files_passed <<- files
      list(success = TRUE, backend = "https")
    },
    .update_manifest = function(...) invisible(NULL),
    .batch_update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  withr::local_tempdir()
  on_download("ds000001", subjects = "01", quiet = TRUE)

  # Should include derivatives by default
  expect_true("derivatives/fmriprep/sub-01/anat/T1w_preproc.nii.gz" %in% files_passed)
})

test_that("on_download root files always included with subject filter", {
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_subjects = function(...) tibble::tibble(
      dataset_id = "ds000001",
      subject_id = c("01", "02"),
      n_sessions = c(1L, 1L),
      n_files = c(10L, 10L)
    ),
    .list_all_files = function(...) tibble::tibble(
      filename = c("dataset_description.json", "README", "participants.tsv",
                   "CHANGES", ".bidsignore",
                   "T1w.nii.gz", "T1w.nii.gz"),
      full_path = c("dataset_description.json", "README", "participants.tsv",
                    "CHANGES", ".bidsignore",
                    "sub-01/anat/T1w.nii.gz", "sub-02/anat/T1w.nii.gz"),
      size = c(100, 50, 200, 30, 10, 1000, 1000),
      annexed = c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet) {
      files_passed <<- files
      list(success = TRUE, backend = "https")
    },
    .update_manifest = function(...) invisible(NULL),
    .batch_update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  withr::local_tempdir()
  on_download("ds000001", subjects = "01", quiet = TRUE)

  # All root files should be included
  expect_true("dataset_description.json" %in% files_passed)
  expect_true("README" %in% files_passed)
  expect_true("participants.tsv" %in% files_passed)
  expect_true("CHANGES" %in% files_passed)
  expect_true(".bidsignore" %in% files_passed)
  # sub-01 included, sub-02 excluded
  expect_true("sub-01/anat/T1w.nii.gz" %in% files_passed)
  expect_false("sub-02/anat/T1w.nii.gz" %in% files_passed)
})

test_that("on_download accepts subject IDs without sub- prefix", {
  files_passed <- NULL

  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_subjects = function(...) tibble::tibble(
      dataset_id = "ds000001",
      subject_id = c("01", "02"),
      n_sessions = c(1L, 1L),
      n_files = c(10L, 10L)
    ),
    .list_all_files = function(...) tibble::tibble(
      filename = c("T1w.nii.gz", "T1w.nii.gz"),
      full_path = c("sub-01/anat/T1w.nii.gz", "sub-02/anat/T1w.nii.gz"),
      size = c(1000, 1000),
      annexed = c(TRUE, TRUE)
    ),
    .on_dataset_cache_path = function(id) file.path(tempdir(), id),
    .download_with_backend = function(dataset_id, dest_dir, files, backend, quiet) {
      files_passed <<- files
      list(success = TRUE, backend = "https")
    },
    .update_manifest = function(...) invisible(NULL),
    .batch_update_manifest = function(...) invisible(NULL),
    .print_completion_summary = function(...) invisible(NULL)
  )

  withr::local_tempdir()
  # Use "01" without sub- prefix
  on_download("ds000001", subjects = c("01"), quiet = TRUE)

  expect_true("sub-01/anat/T1w.nii.gz" %in% files_passed)
  expect_false("sub-02/anat/T1w.nii.gz" %in% files_passed)
})
