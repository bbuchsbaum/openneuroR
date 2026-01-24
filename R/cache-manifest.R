#' Get Manifest Path
#'
#' Returns the path to the manifest.json file within a dataset directory.
#'
#' @param dataset_dir Path to the dataset cache directory.
#'
#' @return Path to manifest.json.
#'
#' @keywords internal
.manifest_path <- function(dataset_dir) {
  fs::path(dataset_dir, "manifest.json")
}


#' Read Manifest
#'
#' Reads the manifest.json file from a dataset directory if it exists.
#' Returns NULL if the manifest doesn't exist. Issues a warning and
#' returns NULL if the manifest exists but contains corrupt JSON.
#'
#' @param dataset_dir Path to the dataset cache directory.
#'
#' @return Manifest as a list, or NULL if not found or corrupt.
#'
#' @keywords internal
.read_manifest <- function(dataset_dir) {
  manifest_file <- .manifest_path(dataset_dir)

  if (!fs::file_exists(manifest_file)) {
    return(NULL)
  }

  tryCatch(
    {
      jsonlite::read_json(manifest_file, simplifyVector = FALSE)
    },
    error = function(e) {
      rlang::warn(
        c("Corrupt manifest file, treating as empty",
          "x" = paste0("Could not parse: ", manifest_file),
          "i" = conditionMessage(e))
      )
      NULL
    }
  )
}


#' Write Manifest Atomically
#'
#' Writes a manifest to JSON using atomic pattern: writes to temp file first,
#' then moves to final location. Creates the dataset directory if needed.
#'
#' @param manifest Manifest list to write.
#' @param dataset_dir Path to the dataset cache directory.
#'
#' @return Invisibly returns the manifest path on success.
#'
#' @keywords internal
.write_manifest <- function(manifest, dataset_dir) {
  manifest_file <- .manifest_path(dataset_dir)

  # Create directory if needed

  fs::dir_create(dataset_dir, recurse = TRUE)

  # Create temp file for atomic write

  temp_path <- fs::file_temp(ext = "json")

  tryCatch(
    {
      # Write to temp file (human-readable format)
      jsonlite::write_json(manifest, temp_path, auto_unbox = TRUE, pretty = TRUE)

      # Move to final location (atomic on same filesystem)
      tryCatch(
        {
          fs::file_move(temp_path, manifest_file)
        },
        error = function(e) {
          # Cross-filesystem fallback: copy then delete
          fs::file_copy(temp_path, manifest_file, overwrite = TRUE)
          fs::file_delete(temp_path)
        }
      )

      invisible(manifest_file)
    },
    error = function(e) {
      # Clean up temp file on failure
      if (fs::file_exists(temp_path)) {
        fs::file_delete(temp_path)
      }
      rlang::abort(
        c("Failed to write manifest",
          "x" = paste0("Could not write to: ", manifest_file),
          "i" = conditionMessage(e)),
        class = "openneuro_cache_error",
        parent = e
      )
    }
  )
}


#' Create New Manifest
#'
#' Creates an empty manifest structure for a dataset.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#' @param snapshot_tag Snapshot/version tag (e.g., "1.0.0").
#'
#' @return A new manifest list structure.
#'
#' @keywords internal
.new_manifest <- function(dataset_id, snapshot_tag) {
  list(
    schema_version = 1L,
    dataset_id = dataset_id,
    snapshot_tag = snapshot_tag,
    cached_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    files = list()
  )
}


#' Update Manifest with New File
#'
#' Reads existing manifest (or creates new), adds/updates a file entry,
#' and writes back atomically.
#'
#' @param dataset_dir Path to the dataset cache directory.
#' @param new_file_info List with file information (path, size).
#' @param dataset_id Dataset identifier (used if creating new manifest).
#' @param snapshot_tag Snapshot tag (used if creating new manifest).
#' @param backend Backend used for download (e.g., "https").
#' @param type Type of cached data: "raw" for raw dataset files, "derivative"
#'   for fMRIPrep/MRIQC derivative outputs. Defaults to "raw". Existing
#'   manifest entries without a type field are treated as "raw" for backward
#'   compatibility.
#'
#' @return Invisibly returns the updated manifest.
#'
#' @keywords internal
.update_manifest <- function(dataset_dir, new_file_info, dataset_id,
                              snapshot_tag, backend = "https", type = "raw") {
  # Read existing manifest or create new
  manifest <- .read_manifest(dataset_dir)

  if (is.null(manifest)) {
    manifest <- .new_manifest(dataset_id, snapshot_tag)
  }

  # Create file entry
  file_entry <- list(
    path = new_file_info$path,
    size = new_file_info$size,
    downloaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    backend = backend,
    type = type
  )

  # Find existing entry index or append
  existing_idx <- NULL
  for (i in seq_along(manifest$files)) {
    if (manifest$files[[i]]$path == new_file_info$path) {
      existing_idx <- i
      break
    }
  }

  if (!is.null(existing_idx)) {
    # Update existing entry
    manifest$files[[existing_idx]] <- file_entry
  } else {
    # Append new entry
    manifest$files <- c(manifest$files, list(file_entry))
  }

  # Write back atomically
  .write_manifest(manifest, dataset_dir)

  invisible(manifest)
}
