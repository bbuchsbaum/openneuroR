# Tests for discovery-spaces.R - on_spaces() and helpers

test_that("on_spaces discovers spaces for embedded derivatives with sessions", {
  local_mocked_bindings(
    on_files = function(id, tag = NULL, tree = NULL, client = NULL) {
      entries <- switch(tree %||% "ROOT",
        "ROOT" = list(
          list(filename = "derivatives", directory = TRUE, key = "k_deriv")
        ),
        "k_deriv" = list(
          list(filename = "fmriprep", directory = TRUE, key = "k_fmriprep")
        ),
        "k_fmriprep" = list(
          list(filename = "sub-01", directory = TRUE, key = "k_sub01")
        ),
        "k_sub01" = list(
          list(filename = "ses-01", directory = TRUE, key = "k_ses01")
        ),
        "k_ses01" = list(
          list(filename = "func", directory = TRUE, key = "k_ses01_func")
        ),
        "k_ses01_func" = list(
          list(
            filename = "sub-01_ses-01_task-rest_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz",
            directory = FALSE,
            key = "k_file1"
          ),
          list(
            filename = "sub-01_ses-01_space-fsaverage_hemi-L_bold.func.gii",
            directory = FALSE,
            key = "k_file2"
          )
        ),
        list()
      )

      tibble::tibble(
        filename = vapply(entries, function(x) x$filename, character(1)),
        size = rep(NA_real_, length(entries)),
        directory = vapply(entries, function(x) x$directory, logical(1)),
        annexed = rep(FALSE, length(entries)),
        key = vapply(entries, function(x) x$key %||% NA_character_, character(1))
      )
    },
    .package = "openneuro"
  )

  derivative <- tibble::tibble(
    dataset_id = "ds000001",
    pipeline = "fmriprep",
    source = "embedded"
  )

  spaces <- on_spaces(derivative, refresh = TRUE)
  expect_setequal(spaces, c("MNI152NLin2009cAsym", "fsaverage"))
})

test_that("on_spaces uses --max-items when sampling S3 listings", {
  args_used <- NULL

  local_mocked_bindings(.find_aws_cli = function() "aws", .package = "openneuro")
  local_mocked_bindings(
    run = function(command, args, timeout, error_on_status) {
      args_used <<- args
      list(
        status = 0,
        stdout = paste(
          "2024-01-15 12:34:56    123 sub-01_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz",
          "2024-01-15 12:34:56    456 sub-01_space-fsaverage_hemi-L_bold.func.gii",
          sep = "\n"
        ),
        stderr = ""
      )
    },
    .package = "processx"
  )

  derivative <- tibble::tibble(
    dataset_id = "ds000001",
    pipeline = "fmriprep",
    source = "openneuro-derivatives"
  )

  spaces <- on_spaces(derivative, refresh = TRUE)
  expect_setequal(spaces, c("MNI152NLin2009cAsym", "fsaverage"))
  expect_true("--max-items" %in% args_used)
  expect_true("500" %in% args_used)
  expect_false("--page-size" %in% args_used)
})

test_that("on_spaces warns for unknown derivative source and returns empty", {
  derivative <- tibble::tibble(
    dataset_id = "ds000001",
    pipeline = "fmriprep",
    source = "unknown"
  )

  expect_warning(
    expect_warning(
      spaces <- on_spaces(derivative, refresh = TRUE),
      class = "openneuro_unknown_source_warning"
    ),
    class = "openneuro_no_spaces_warning"
  )

  expect_type(spaces, "character")
  expect_equal(length(spaces), 0L)
})

test_that("on_spaces warns when no spaces are detected", {
  local_mocked_bindings(
    .list_derivative_files_embedded = function(...) character(0),
    .package = "openneuro"
  )

  derivative <- tibble::tibble(
    dataset_id = "ds000001",
    pipeline = "fmriprep",
    source = "embedded"
  )

  expect_warning(
    spaces <- on_spaces(derivative, refresh = TRUE),
    class = "openneuro_no_spaces_warning"
  )
  expect_equal(length(spaces), 0L)
})

# --- Helper function tests ---

test_that(".extract_space_from_filename extracts space correctly", {
  # Standard case
  expect_equal(
    openneuro:::.extract_space_from_filename("sub-01_space-MNI152NLin2009cAsym_bold.nii.gz"),
    "MNI152NLin2009cAsym"
  )

  # Surface space
  expect_equal(
    openneuro:::.extract_space_from_filename("sub-01_space-fsaverage_hemi-L_bold.func.gii"),
    "fsaverage"
  )

  # No space entity
  expect_true(is.na(
    openneuro:::.extract_space_from_filename("sub-01_desc-preproc_bold.nii.gz")
  ))

  # Empty string
  expect_true(is.na(
    openneuro:::.extract_space_from_filename("")
  ))

  # Space at end of filename (before extension)
  expect_equal(
    openneuro:::.extract_space_from_filename("sub-01_space-T1w.nii.gz"),
    "T1w"
  )
})

test_that(".extract_spaces_from_files returns unique sorted spaces", {
  filenames <- c(
    "sub-01_space-MNI152NLin2009cAsym_bold.nii.gz",
    "sub-01_space-fsaverage_bold.func.gii",
    "sub-02_space-MNI152NLin2009cAsym_bold.nii.gz",  # Duplicate space
    "sub-01_desc-preproc_bold.nii.gz"  # No space
  )

  result <- openneuro:::.extract_spaces_from_files(filenames)

  expect_equal(length(result), 2L)
  expect_equal(result, c("MNI152NLin2009cAsym", "fsaverage"))  # Sorted alphabetically
})

test_that(".extract_spaces_from_files handles empty input", {
  result <- openneuro:::.extract_spaces_from_files(character(0))
  expect_equal(result, character(0))
})

test_that(".extract_spaces_from_files handles all NA input", {
  filenames <- c("file1.txt", "file2.json", "README.md")

  result <- openneuro:::.extract_spaces_from_files(filenames)
  expect_equal(result, character(0))
})

# --- Input validation tests ---

test_that("on_spaces validates derivative is a data.frame", {
  expect_error(
    on_spaces("not a data.frame"),
    class = "openneuro_validation_error"
  )
})

test_that("on_spaces validates derivative has exactly 1 row", {
  derivative <- tibble::tibble(
    dataset_id = c("ds000001", "ds000002"),
    pipeline = c("fmriprep", "mriqc"),
    source = c("embedded", "embedded")
  )

  expect_error(
    on_spaces(derivative),
    class = "openneuro_validation_error"
  )
})

test_that("on_spaces validates required columns exist", {
  derivative <- tibble::tibble(
    dataset_id = "ds000001",
    pipeline = "fmriprep"
    # Missing 'source' column
  )

  expect_error(
    on_spaces(derivative),
    class = "openneuro_validation_error"
  )
})

# --- S3 listing edge cases ---

test_that(".list_derivative_files_s3 handles malformed AWS output", {
  local_mocked_bindings(.find_aws_cli = function() "aws", .package = "openneuro")
  local_mocked_bindings(
    run = function(command, args, timeout, error_on_status) {
      list(
        status = 0,
        stdout = "malformed line without enough parts\n\n",  # Malformed output
        stderr = ""
      )
    },
    .package = "processx"
  )

  result <- openneuro:::.list_derivative_files_s3("ds000001", "fmriprep")
  expect_type(result, "character")
  # Should handle gracefully, returning empty or partial results
})

test_that(".list_derivative_files_s3 warns on access denied", {
  local_mocked_bindings(.find_aws_cli = function() "aws", .package = "openneuro")
  local_mocked_bindings(
    run = function(command, args, timeout, error_on_status) {
      list(
        status = 1,
        stdout = "",
        stderr = "An error occurred (AccessDenied)"
      )
    },
    .package = "processx"
  )

  expect_warning(
    result <- openneuro:::.list_derivative_files_s3("ds000001", "fmriprep"),
    class = "openneuro_s3_access_warning"
  )
  expect_equal(result, character(0))
})
