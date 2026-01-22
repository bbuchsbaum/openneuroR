# Tests for cache-manifest.R - manifest file management
# Uses local_temp_cache() helper for isolated testing

# --- .manifest_path tests ---

test_that(".manifest_path returns correct path structure", {
  tmp <- withr::local_tempdir()
  result <- .manifest_path(tmp)
  # Verify path ends with manifest.json and contains the temp dir
  expect_true(grepl("manifest\\.json$", as.character(result)))
  expect_true(grepl(basename(tmp), as.character(result)))
})

# --- .read_manifest tests ---

test_that(".read_manifest returns NULL when manifest doesn't exist", {
  tmp <- withr::local_tempdir()
  result <- .read_manifest(tmp)
  expect_null(result)
})

test_that(".read_manifest reads valid manifest JSON correctly", {
  tmp <- withr::local_tempdir()
  manifest_file <- file.path(tmp, "manifest.json")

  # Create a valid manifest
  manifest_data <- list(
    schema_version = 1L,
    dataset_id = "ds000001",
    snapshot_tag = "1.0.0",
    cached_at = "2024-01-01T00:00:00Z",
    files = list(
      list(path = "README.md", size = 100)
    )
  )
  jsonlite::write_json(manifest_data, manifest_file, auto_unbox = TRUE)

  result <- .read_manifest(tmp)
  expect_type(result, "list")
  expect_equal(result$schema_version, 1L)
  expect_equal(result$dataset_id, "ds000001")
  expect_equal(result$snapshot_tag, "1.0.0")
  expect_length(result$files, 1)
})

test_that(".read_manifest returns NULL and warns on corrupt JSON", {
  tmp <- withr::local_tempdir()
  manifest_file <- file.path(tmp, "manifest.json")

  # Write invalid JSON
  writeLines("{ invalid json content", manifest_file)

  expect_warning(
    result <- .read_manifest(tmp),
    "Corrupt manifest"
  )
  expect_null(result)
})

# --- .write_manifest tests ---

test_that(".write_manifest creates directory if missing", {
  tmp <- withr::local_tempdir()
  new_dir <- file.path(tmp, "subdir", "nested")

  manifest <- list(
    schema_version = 1L,
    dataset_id = "ds000001",
    snapshot_tag = "1.0.0",
    files = list()
  )

  .write_manifest(manifest, new_dir)

  expect_true(dir.exists(new_dir))
  expect_true(file.exists(file.path(new_dir, "manifest.json")))
})

test_that(".write_manifest writes valid JSON that can be read back", {
  tmp <- withr::local_tempdir()

  manifest <- list(
    schema_version = 1L,
    dataset_id = "ds000002",
    snapshot_tag = "2.0.0",
    cached_at = "2024-06-15T12:00:00Z",
    files = list(
      list(path = "participants.tsv", size = 500)
    )
  )

  .write_manifest(manifest, tmp)

  # Read it back
  result <- jsonlite::read_json(file.path(tmp, "manifest.json"), simplifyVector = FALSE)
  expect_equal(result$schema_version, 1L)
  expect_equal(result$dataset_id, "ds000002")
  expect_equal(result$snapshot_tag, "2.0.0")
  expect_equal(result$files[[1]]$path, "participants.tsv")
})

test_that(".write_manifest cross-filesystem fallback path works", {
  tmp <- withr::local_tempdir()

  manifest <- list(
    schema_version = 1L,
    dataset_id = "ds000003",
    snapshot_tag = "1.0.0",
    files = list()
  )

  # Mock fs::file_move to error, triggering copy fallback
  local_mocked_bindings(
    file_move = function(...) {
      stop("cross-filesystem move not supported")
    },
    .package = "fs"
  )

  # Should succeed via copy fallback
  result <- .write_manifest(manifest, tmp)
  expect_true(file.exists(file.path(tmp, "manifest.json")))
})

test_that(".write_manifest error handling when write fails", {
  tmp <- withr::local_tempdir()

  manifest <- list(
    schema_version = 1L,
    dataset_id = "ds000004",
    snapshot_tag = "1.0.0",
    files = list()
  )

  # Mock write_json to always error
  local_mocked_bindings(
    write_json = function(...) {
      stop("disk full")
    },
    .package = "jsonlite"
  )

  expect_error(
    .write_manifest(manifest, tmp),
    class = "openneuro_cache_error"
  )
})

# --- .new_manifest tests ---

test_that(".new_manifest creates structure with correct fields", {
  result <- .new_manifest("ds000005", "1.2.3")

  expect_type(result, "list")
  expect_named(result, c("schema_version", "dataset_id", "snapshot_tag", "cached_at", "files"))
  expect_equal(result$schema_version, 1L)
  expect_equal(result$dataset_id, "ds000005")
  expect_equal(result$snapshot_tag, "1.2.3")
  expect_type(result$cached_at, "character")
  # Verify timestamp format (ISO 8601)
  expect_true(grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", result$cached_at))
})

test_that(".new_manifest files array is empty", {
  result <- .new_manifest("ds000006", "2.0.0")
  expect_equal(result$files, list())
  expect_length(result$files, 0)
})

# --- .update_manifest tests ---

test_that(".update_manifest creates new manifest if none exists", {
  tmp <- withr::local_tempdir()

  new_file_info <- list(path = "README.md", size = 256)

  result <- .update_manifest(
    dataset_dir = tmp,
    new_file_info = new_file_info,
    dataset_id = "ds000007",
    snapshot_tag = "1.0.0",
    backend = "https"
  )

  # Check structure
  expect_type(result, "list")
  expect_equal(result$dataset_id, "ds000007")
  expect_equal(result$snapshot_tag, "1.0.0")
  expect_length(result$files, 1)
  expect_equal(result$files[[1]]$path, "README.md")
  expect_equal(result$files[[1]]$size, 256)
  expect_equal(result$files[[1]]$backend, "https")

  # Verify written to disk
  expect_true(file.exists(file.path(tmp, "manifest.json")))
})

test_that(".update_manifest adds new file to existing manifest", {
  tmp <- withr::local_tempdir()

  # Create initial manifest with one file
  initial_file <- list(path = "README.md", size = 256)
  .update_manifest(
    dataset_dir = tmp,
    new_file_info = initial_file,
    dataset_id = "ds000008",
    snapshot_tag = "1.0.0",
    backend = "https"
  )

  # Add second file
  second_file <- list(path = "participants.tsv", size = 1024)
  result <- .update_manifest(
    dataset_dir = tmp,
    new_file_info = second_file,
    dataset_id = "ds000008",
    snapshot_tag = "1.0.0",
    backend = "s3"
  )

  expect_length(result$files, 2)
  expect_equal(result$files[[1]]$path, "README.md")
  expect_equal(result$files[[2]]$path, "participants.tsv")
  expect_equal(result$files[[2]]$backend, "s3")
})

test_that(".update_manifest updates existing file entry (same path, new metadata)", {
  tmp <- withr::local_tempdir()

  # Create initial manifest with one file
  initial_file <- list(path = "data/sub-01.nii.gz", size = 1000)
  .update_manifest(
    dataset_dir = tmp,
    new_file_info = initial_file,
    dataset_id = "ds000009",
    snapshot_tag = "1.0.0",
    backend = "https"
  )

  # Update the same file with new size (re-download scenario)
  updated_file <- list(path = "data/sub-01.nii.gz", size = 2000)
  result <- .update_manifest(
    dataset_dir = tmp,
    new_file_info = updated_file,
    dataset_id = "ds000009",
    snapshot_tag = "1.0.0",
    backend = "s3"
  )

  # Should still have only one file
  expect_length(result$files, 1)
  # But with updated metadata
  expect_equal(result$files[[1]]$path, "data/sub-01.nii.gz")
  expect_equal(result$files[[1]]$size, 2000)
  expect_equal(result$files[[1]]$backend, "s3")
})
