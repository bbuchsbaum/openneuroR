# Tests for subject-filter.R - Subject filtering infrastructure

# --- regex() tests ---

test_that("regex() returns correct class", {
  result <- regex("sub-0[1-5]")

  expect_s3_class(result, "on_regex")
  expect_s3_class(result, "character")
  expect_equal(as.character(result), "sub-0[1-5]")
})

test_that("regex() rejects NULL", {
  expect_error(
    regex(NULL),
    class = "openneuro_validation_error"
  )
})

test_that("regex() rejects empty string", {
  expect_error(
    regex(""),
    class = "openneuro_validation_error"
  )
})

test_that("regex() rejects vector", {
  expect_error(
    regex(c("sub-01", "sub-02")),
    class = "openneuro_validation_error"
  )
})

test_that("regex() rejects non-character", {
  expect_error(
    regex(123),
    class = "openneuro_validation_error"
  )
})


# --- is_regex() tests ---

test_that("is_regex() returns TRUE for regex()", {
  expect_true(is_regex(regex("sub-0[1-5]")))
})

test_that("is_regex() returns FALSE for plain string", {
  expect_false(is_regex("sub-01"))
})

test_that("is_regex() returns FALSE for NULL", {
  expect_false(is_regex(NULL))
})

test_that("is_regex() returns FALSE for character vector", {
  expect_false(is_regex(c("sub-01", "sub-02")))
})


# --- .normalize_subject_id() tests ---

test_that(".normalize_subject_id() adds prefix when missing", {
  expect_equal(.normalize_subject_id("01"), "sub-01")
})

test_that(".normalize_subject_id() keeps prefix when present", {
  expect_equal(.normalize_subject_id("sub-01"), "sub-01")
})

test_that(".normalize_subject_id() handles longer IDs", {
  expect_equal(.normalize_subject_id("101"), "sub-101")
  expect_equal(.normalize_subject_id("sub-101"), "sub-101")
})


# --- .normalize_subject_ids() tests ---

test_that(".normalize_subject_ids() handles mixed input", {
  result <- .normalize_subject_ids(c("01", "sub-02", "03"))

  expect_equal(result, c("sub-01", "sub-02", "sub-03"))
})

test_that(".normalize_subject_ids() returns character vector", {
  result <- .normalize_subject_ids(c("01", "02"))

  expect_type(result, "character")
  expect_length(result, 2)
})

test_that(".normalize_subject_ids() handles empty vector", {
  result <- .normalize_subject_ids(character())

  expect_equal(result, character())
})


# --- .validate_subjects() tests ---

test_that(".validate_subjects() accepts valid IDs", {
  available <- c("01", "02", "03")
  requested <- c("01", "02")

  result <- .validate_subjects(requested, available, "ds000001")

  expect_equal(result, c("sub-01", "sub-02"))
})

test_that(".validate_subjects() accepts IDs with sub- prefix", {
  available <- c("01", "02", "03")
  requested <- c("sub-01", "sub-02")

  result <- .validate_subjects(requested, available, "ds000001")

  expect_equal(result, c("sub-01", "sub-02"))
})

test_that(".validate_subjects() errors on invalid IDs", {
  available <- c("01", "02", "03")
  requested <- c("01", "99")

  expect_error(
    .validate_subjects(requested, available, "ds000001"),
    class = "openneuro_validation_error"
  )
})

test_that(".validate_subjects() error message includes invalid IDs", {
  available <- c("01", "02", "03")
  requested <- c("01", "99", "100")

  err <- expect_error(
    .validate_subjects(requested, available, "ds000001"),
    class = "openneuro_validation_error"
  )

  expect_match(conditionMessage(err), "sub-99")
  expect_match(conditionMessage(err), "sub-100")
})

test_that(".validate_subjects() error message shows available subjects", {
  available <- c("01", "02", "03")
  requested <- c("99")

  err <- expect_error(
    .validate_subjects(requested, available, "ds000001"),
    class = "openneuro_validation_error"
  )

  expect_match(conditionMessage(err), "Available in ds000001")
})

test_that(".validate_subjects() truncates long available list", {
  available <- sprintf("%02d", 1:20)
  requested <- c("99")

  err <- expect_error(
    .validate_subjects(requested, available, "ds000001"),
    class = "openneuro_validation_error"
  )

  expect_match(conditionMessage(err), "\\.\\.\\.")
})


# --- .match_subjects_regex() tests ---

test_that(".match_subjects_regex() matches simple pattern", {
  subjects <- c("sub-01", "sub-02", "sub-03", "sub-10", "sub-11")

  result <- .match_subjects_regex(subjects, "sub-0[12]")

  expect_equal(result, c(TRUE, TRUE, FALSE, FALSE, FALSE))
})

test_that(".match_subjects_regex() auto-anchors pattern", {
  # sub-01 should NOT match sub-010 due to anchoring
  subjects <- c("sub-01", "sub-010", "sub-011")

  result <- .match_subjects_regex(subjects, "sub-01")

  expect_equal(result, c(TRUE, FALSE, FALSE))
})

test_that(".match_subjects_regex() handles range patterns", {
  subjects <- c("sub-01", "sub-05", "sub-10", "sub-15")

  result <- .match_subjects_regex(subjects, "sub-0[1-9]")

  expect_equal(result, c(TRUE, TRUE, FALSE, FALSE))
})

test_that(".match_subjects_regex() handles wildcard patterns", {
  subjects <- c("sub-01", "sub-02", "sub-10", "sub-20")

  result <- .match_subjects_regex(subjects, "sub-1.*")

  expect_equal(result, c(FALSE, FALSE, TRUE, FALSE))
})


# --- .filter_files_by_subjects() tests ---

test_that(".filter_files_by_subjects() includes root files", {
  files_df <- tibble::tibble(
    full_path = c(
      "dataset_description.json",
      "README",
      "participants.tsv",
      "sub-01/anat/T1w.nii.gz",
      "sub-02/anat/T1w.nii.gz"
    ),
    size = c(100, 50, 200, 1000, 1000)
  )

  result <- .filter_files_by_subjects(files_df, "sub-01", include_derivatives = TRUE)

  # Should include all root files plus sub-01
  expect_equal(nrow(result), 4)
  expect_true("dataset_description.json" %in% result$full_path)
  expect_true("README" %in% result$full_path)
  expect_true("participants.tsv" %in% result$full_path)
  expect_true("sub-01/anat/T1w.nii.gz" %in% result$full_path)
  expect_false("sub-02/anat/T1w.nii.gz" %in% result$full_path)
})

test_that(".filter_files_by_subjects() filters subject directories", {
  files_df <- tibble::tibble(
    full_path = c(
      "sub-01/anat/T1w.nii.gz",
      "sub-01/func/bold.nii.gz",
      "sub-02/anat/T1w.nii.gz",
      "sub-03/anat/T1w.nii.gz"
    ),
    size = c(1000, 2000, 1000, 1000)
  )

  result <- .filter_files_by_subjects(files_df, c("sub-01", "sub-03"),
                                       include_derivatives = TRUE)

  expect_equal(nrow(result), 3)
  expect_true("sub-01/anat/T1w.nii.gz" %in% result$full_path)
  expect_true("sub-01/func/bold.nii.gz" %in% result$full_path)
  expect_true("sub-03/anat/T1w.nii.gz" %in% result$full_path)
  expect_false("sub-02/anat/T1w.nii.gz" %in% result$full_path)
})

test_that(".filter_files_by_subjects() includes derivatives when TRUE", {
  files_df <- tibble::tibble(
    full_path = c(
      "sub-01/anat/T1w.nii.gz",
      "derivatives/fmriprep/sub-01/anat/T1w_preproc.nii.gz",
      "derivatives/fmriprep/sub-02/anat/T1w_preproc.nii.gz"
    ),
    size = c(1000, 1000, 1000)
  )

  result <- .filter_files_by_subjects(files_df, "sub-01", include_derivatives = TRUE)

  expect_equal(nrow(result), 2)
  expect_true("sub-01/anat/T1w.nii.gz" %in% result$full_path)
  expect_true("derivatives/fmriprep/sub-01/anat/T1w_preproc.nii.gz" %in% result$full_path)
})

test_that(".filter_files_by_subjects() excludes derivatives when FALSE", {
  files_df <- tibble::tibble(
    full_path = c(
      "sub-01/anat/T1w.nii.gz",
      "derivatives/fmriprep/sub-01/anat/T1w_preproc.nii.gz"
    ),
    size = c(1000, 1000)
  )

  result <- .filter_files_by_subjects(files_df, "sub-01", include_derivatives = FALSE)

  expect_equal(nrow(result), 1)
  expect_true("sub-01/anat/T1w.nii.gz" %in% result$full_path)
  expect_false("derivatives/fmriprep/sub-01/anat/T1w_preproc.nii.gz" %in% result$full_path)
})

test_that(".filter_files_by_subjects() handles CHANGES file", {
  files_df <- tibble::tibble(
    full_path = c("CHANGES", "sub-01/anat/T1w.nii.gz"),
    size = c(50, 1000)
  )

  result <- .filter_files_by_subjects(files_df, "sub-02", include_derivatives = TRUE)

  # CHANGES is a root file, should be included
  expect_equal(nrow(result), 1)
  expect_true("CHANGES" %in% result$full_path)
})

test_that(".filter_files_by_subjects() handles .bidsignore file", {
  files_df <- tibble::tibble(
    full_path = c(".bidsignore", "sub-01/anat/T1w.nii.gz"),
    size = c(20, 1000)
  )

  result <- .filter_files_by_subjects(files_df, "sub-02", include_derivatives = TRUE)

  expect_equal(nrow(result), 1)
  expect_true(".bidsignore" %in% result$full_path)
})

test_that(".filter_files_by_subjects() returns empty when no matches", {
  files_df <- tibble::tibble(
    full_path = c("sub-01/anat/T1w.nii.gz", "sub-02/anat/T1w.nii.gz"),
    size = c(1000, 1000)
  )

  result <- .filter_files_by_subjects(files_df, "sub-99", include_derivatives = TRUE)

  expect_equal(nrow(result), 0)
})
