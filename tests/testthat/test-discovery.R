# Tests for discovery.R - on_derivatives() and helpers

test_that(".detect_embedded_derivatives returns empty when no derivatives dir", {
  local_mocked_bindings(
    on_files = function(...) tibble::tibble(
      filename = c("README.md"),
      size = c(NA_real_),
      directory = c(FALSE),
      annexed = c(FALSE),
      key = c(NA_character_)
    ),
    .package = "openneuro"
  )

  out <- .detect_embedded_derivatives("ds000001", tag = NULL, client = NULL)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
})

test_that(".detect_embedded_derivatives lists pipeline directories", {
  local_mocked_bindings(
    on_files = function(dataset_id, tag = NULL, tree = NULL, client = NULL) {
      if (is.null(tree)) {
        return(tibble::tibble(
          filename = c("derivatives"),
          size = c(NA_real_),
          directory = c(TRUE),
          annexed = c(FALSE),
          key = c("k_deriv")
        ))
      }

      if (identical(tree, "k_deriv")) {
        return(tibble::tibble(
          filename = c("fmriprep", "mriqc"),
          size = c(NA_real_, NA_real_),
          directory = c(TRUE, TRUE),
          annexed = c(FALSE, FALSE),
          key = c("k_fmriprep", "k_mriqc")
        ))
      }

      tibble::tibble(
        filename = character(),
        size = numeric(),
        directory = logical(),
        annexed = logical(),
        key = character()
      )
    },
    .package = "openneuro"
  )

  out <- .detect_embedded_derivatives("ds000001", tag = NULL, client = NULL)
  expect_equal(nrow(out), 2L)
  expect_setequal(out$pipeline, c("fmriprep", "mriqc"))
  expect_setequal(out$source, c("embedded"))
})

test_that(".find_derivatives_in_github filters by dataset_id and formats results", {
  local_mocked_bindings(
    .list_openneuro_derivatives_repos = function(refresh = FALSE) {
      list(
        list(
          dataset_id = "ds000001",
          pipeline = "fmriprep",
          repo_name = "ds000001-fmriprep",
          pushed_at = "2024-01-01T00:00:00Z",
          size_kb = 100
        ),
        list(
          dataset_id = "ds000002",
          pipeline = "mriqc",
          repo_name = "ds000002-mriqc",
          pushed_at = "2024-01-02T00:00:00Z",
          size_kb = 200
        )
      )
    },
    .package = "openneuro"
  )

  out <- .find_derivatives_in_github("ds000001", refresh = FALSE)
  expect_equal(nrow(out), 1L)
  expect_equal(out$dataset_id[[1]], "ds000001")
  expect_equal(out$pipeline[[1]], "fmriprep")
  expect_equal(out$source[[1]], "openneuro-derivatives")
  expect_true(inherits(out$last_modified[[1]], "POSIXct"))
  expect_true(grepl("^s3://openneuro-derivatives/", out$s3_url[[1]]))
})

test_that("on_derivatives prefers embedded over openneuro-derivatives for duplicates", {
  .discovery_cache_clear()

  embed_calls <- 0L
  gh_calls <- 0L

  local_mocked_bindings(
    .detect_embedded_derivatives = function(...) {
      embed_calls <<- embed_calls + 1L
      tibble::tibble(
        dataset_id = "ds000001",
        pipeline = c("fmriprep"),
        source = c("embedded"),
        version = NA_character_,
        n_subjects = NA_integer_,
        n_files = NA_integer_,
        total_size = NA_character_,
        last_modified = as.POSIXct(NA, tz = "UTC"),
        s3_url = NA_character_
      )
    },
    .find_derivatives_in_github = function(...) {
      gh_calls <<- gh_calls + 1L
      tibble::tibble(
        dataset_id = "ds000001",
        pipeline = c("fmriprep", "mriqc"),
        source = c("openneuro-derivatives", "openneuro-derivatives"),
        version = NA_character_,
        n_subjects = NA_integer_,
        n_files = NA_integer_,
        total_size = NA_character_,
        last_modified = as.POSIXct(NA, tz = "UTC"),
        s3_url = c("s3://openneuro-derivatives/fmriprep/ds000001-fmriprep/",
                   "s3://openneuro-derivatives/mriqc/ds000001-mriqc/")
      )
    },
    .package = "openneuro"
  )

  out1 <- on_derivatives("ds000001", refresh = FALSE)
  expect_setequal(out1$pipeline, c("fmriprep", "mriqc"))
  expect_equal(out1$source[out1$pipeline == "fmriprep"], "embedded")

  # Cache hit should avoid re-calling internals
  out2 <- on_derivatives("ds000001", refresh = FALSE)
  expect_equal(embed_calls, 1L)
  expect_equal(gh_calls, 1L)
  expect_equal(nrow(out2), nrow(out1))
})

test_that("on_derivatives errors cleanly for not found datasets (embedded)", {
  .discovery_cache_clear()

  local_mocked_bindings(
    .detect_embedded_derivatives = function(...) {
      rlang::abort("nope", class = "openneuro_not_found_error")
    },
    .package = "openneuro"
  )

  expect_error(
    on_derivatives("ds999999", sources = "embedded"),
    class = "openneuro_not_found_error"
  )
})

test_that("on_derivatives warns and returns empty when GitHub lookup fails", {
  .discovery_cache_clear()

  local_mocked_bindings(
    .detect_embedded_derivatives = function(...) .empty_derivatives_tibble(),
    .find_derivatives_in_github = function(...) stop("GitHub down"),
    .package = "openneuro"
  )

  expect_warning(
    out <- on_derivatives("ds000001", sources = "openneuro-derivatives"),
    class = "openneuro_github_warning"
  )
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
})

test_that(".transform_timestamps_posix converts numeric last_modified", {
  df <- tibble::tibble(last_modified = as.numeric(Sys.time()))
  out <- openneuro:::.transform_timestamps_posix(df)
  expect_true(inherits(out$last_modified, "POSIXct"))
})

