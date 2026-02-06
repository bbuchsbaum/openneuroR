# Tests for download-list.R - file listing functions
# Uses local_mocked_bindings() to mock API calls

# Helper to create mock file tibble
mock_files_tibble <- function(files = list()) {
  if (length(files) == 0) {
    return(tibble::tibble(
      filename = character(),
      key = character(),
      size = character(),
      annexed = logical(),
      directory = logical()
    ))
  }

  tibble::tibble(
    filename = vapply(files, `[[`, character(1), "filename"),
    key = vapply(files, `[[`, character(1), "key"),
    size = vapply(files, function(f) as.character(f$size %||% "0"), character(1)),
    annexed = vapply(files, `[[`, logical(1), "annexed"),
    directory = vapply(files, `[[`, logical(1), "directory")
  )
}


# --- .list_all_files tests ---

test_that(".list_all_files returns empty tibble when no files found", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_snapshots = function(...) tibble::tibble(tag = "1.0.0", created = as.numeric(Sys.time()), size = 1000),
    on_files = function(...) mock_files_tibble()
  )

  result <- .list_all_files("ds000001")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("filename", "full_path", "size", "annexed"))
})

test_that(".list_all_files collects files from root level", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_snapshots = function(...) tibble::tibble(tag = "1.0.0", created = as.numeric(Sys.time()), size = 1000),
    on_files = function(dataset_id, tag = NULL, tree = NULL, client = NULL) {
      # Return root level files (no directories)
      mock_files_tibble(list(
        list(filename = "README.md", key = "k1", size = "100",
             annexed = FALSE, directory = FALSE),
        list(filename = "participants.tsv", key = "k2", size = "500",
             annexed = FALSE, directory = FALSE)
      ))
    }
  )

  result <- .list_all_files("ds000001")

  expect_equal(nrow(result), 2)
  expect_equal(result$filename, c("README.md", "participants.tsv"))
  expect_equal(result$full_path, c("README.md", "participants.tsv"))
  expect_equal(result$size, c(100, 500))
})

test_that(".list_all_files recurses into directories", {
  # Track on_files calls to respond differently
  call_count <- 0
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_snapshots = function(...) tibble::tibble(tag = "1.0.0", created = as.numeric(Sys.time()), size = 1000),
    on_files = function(dataset_id, tag = NULL, tree = NULL, client = NULL) {
      call_count <<- call_count + 1

      if (is.null(tree) || call_count == 1) {
        # Root level: one file and one directory
        mock_files_tibble(list(
          list(filename = "README.md", key = "k1", size = "100",
               annexed = FALSE, directory = FALSE),
          list(filename = "sub-01", key = "d1", size = "0",
               annexed = FALSE, directory = TRUE)
        ))
      } else {
        # Inside sub-01 directory
        mock_files_tibble(list(
          list(filename = "anat.nii.gz", key = "k2", size = "1000000",
               annexed = TRUE, directory = FALSE)
        ))
      }
    }
  )

  result <- .list_all_files("ds000001")

  expect_equal(nrow(result), 2)
  expect_true("README.md" %in% result$full_path)
  expect_true("sub-01/anat.nii.gz" %in% result$full_path)
})

test_that(".list_all_files returns correct column types", {
  local_mocked_bindings(
    on_client = function() list(url = "mock", token = NULL),
    on_snapshots = function(...) tibble::tibble(tag = "1.0.0", created = as.numeric(Sys.time()), size = 1000),
    on_files = function(...) {
      mock_files_tibble(list(
        list(filename = "data.nii.gz", key = "k1", size = "1000",
             annexed = TRUE, directory = FALSE)
      ))
    }
  )

  result <- .list_all_files("ds000001")

  expect_type(result$filename, "character")
  expect_type(result$full_path, "character")
  expect_type(result$size, "double")
  expect_type(result$annexed, "logical")
})


# --- .list_directory tests ---

test_that(".list_directory handles empty directories", {
  local_mocked_bindings(
    on_files = function(...) mock_files_tibble()
  )

  result <- .list_directory(
    dataset_id = "ds000001",
    tag = NULL,
    key = "dir_key",
    parent_path = "sub-01",
    client = list()
  )

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that(".list_directory builds full_path correctly", {
  local_mocked_bindings(
    on_files = function(...) {
      mock_files_tibble(list(
        list(filename = "T1w.nii.gz", key = "k1", size = "1000000",
             annexed = TRUE, directory = FALSE)
      ))
    }
  )

  result <- .list_directory(
    dataset_id = "ds000001",
    tag = NULL,
    key = "dir_key",
    parent_path = "sub-01/anat",
    client = list()
  )

  expect_equal(result$full_path, "sub-01/anat/T1w.nii.gz")
})

test_that(".list_directory recurses into nested subdirectories", {
  # Track calls to respond differently
  call_count <- 0
  local_mocked_bindings(
    on_files = function(dataset_id, tag = NULL, tree = NULL, client = NULL) {
      call_count <<- call_count + 1

      if (call_count == 1) {
        # First level: one directory
        mock_files_tibble(list(
          list(filename = "anat", key = "d1", size = "0",
               annexed = FALSE, directory = TRUE)
        ))
      } else {
        # Inside anat directory: one file
        mock_files_tibble(list(
          list(filename = "T1w.nii.gz", key = "k1", size = "1000000",
               annexed = TRUE, directory = FALSE)
        ))
      }
    }
  )

  result <- .list_directory(
    dataset_id = "ds000001",
    tag = NULL,
    key = "sub01_key",
    parent_path = "sub-01",
    client = list()
  )

  expect_equal(nrow(result), 1)
  expect_equal(result$full_path, "sub-01/anat/T1w.nii.gz")
})
