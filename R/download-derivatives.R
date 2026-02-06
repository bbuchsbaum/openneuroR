#' Download Derivative Dataset
#'
#' Downloads fMRIPrep, MRIQC, or other derivative outputs from OpenNeuro
#' datasets. Supports filtering by subject, output space, and BIDS suffix.
#' Uses S3 backend (openneuro-derivatives bucket) with HTTPS fallback.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#' @param pipeline Pipeline name (e.g., "fmriprep", "mriqc").
#' @param subjects Character vector of subject IDs (e.g., `c("sub-01", "sub-02")`)
#'   or a regex pattern wrapped in [regex()] (e.g., `regex("sub-0[1-5]")`).
#'   Subject IDs can be specified with or without the "sub-" prefix.
#'   If `NULL` (default), downloads all subjects.
#' @param space Character string: output space to filter by (e.g.,
#'   "MNI152NLin2009cAsym", "fsaverage", "T1w"). If `NULL` (default),
#'   downloads all spaces. Matching is exact (specify full space name).
#'   Files without a `_space-` entity (native space) are always included.
#' @param suffix Character vector of BIDS suffixes to filter by (e.g.,
#'   `c("bold", "T1w", "mask")`). If `NULL` (default), downloads all suffixes.
#'   Files without a clear suffix (metadata files) are always included.
#' @param dry_run If `TRUE`, returns a tibble of files that would be downloaded
#'   without actually downloading them. Default is `FALSE`.
#' @param dest_dir Destination directory. If `NULL` (default) and `use_cache`
#'   is `TRUE`, downloads to BIDS-compliant cache location:
#'   `{cache}/{dataset_id}/derivatives/{pipeline}/`.
#' @param use_cache If `TRUE` (default) and `dest_dir` is `NULL`, downloads to
#'   CRAN-compliant cache location. Set `FALSE` to use current working directory.
#' @param quiet If `TRUE`, suppress all progress output. Default `FALSE`.
#' @param verbose If `TRUE`, show per-file progress in addition to overall
#'   progress. Default `FALSE`.
#' @param force If `TRUE`, re-download files even if they exist with correct
#'   size. Default `FALSE`.
#' @param backend Backend to use for downloading: "s3" or "https".
#'   If `NULL` (default), auto-selects S3 for openneuro-derivatives bucket.
#' @param client An `openneuro_client` object. If `NULL`, creates default client.
#'
#' @return If `dry_run = TRUE`, returns a tibble with columns:
#'   \describe{
#'     \item{path}{Relative path within derivative}
#'     \item{size}{File size in bytes}
#'     \item{size_formatted}{Human-readable size (e.g., "1.2 GB")}
#'     \item{dest_path}{Full destination path where file would be downloaded}
#'   }
#'
#'   If `dry_run = FALSE`, invisibly returns a list with:
#'   \describe{
#'     \item{downloaded}{Number of files downloaded}
#'     \item{skipped}{Number of files skipped (already cached)}
#'     \item{failed}{Character vector of failed file names}
#'     \item{total_bytes}{Total bytes downloaded}
#'     \item{dest_dir}{Path to destination directory}
#'     \item{backend}{Backend used for download}
#'   }
#'
#' @details
#' ## Filter Logic
#'
#' All filters combine with AND logic - a file must match ALL specified
#' filters to be included. For example, `subjects = "sub-01", space = "MNI152NLin2009cAsym"`
#' downloads only sub-01's MNI-space files.
#'
#' ## Cache Structure
#'
#' Derivatives are cached in BIDS-compliant structure:
#' `{cache_root}/{dataset_id}/derivatives/{pipeline}/`
#'
#' This keeps derivatives organized alongside raw data while maintaining
#' clear separation by pipeline.
#'
#' ## Backend Selection
#'
#' S3 backend is preferred for the openneuro-derivatives bucket as it
#' provides fast parallel sync. HTTPS fallback is used if S3 is unavailable.
#'
#' ## Space Matching
#'
#' Space matching is exact - specify the full space name (e.g.,
#' "MNI152NLin2009cAsym", not "MNI"). Files without a `_space-` entity
#' (native/T1w space per BIDS convention) are always included when
#' filtering by space.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Download all fMRIPrep derivatives for a dataset
#' on_download_derivatives("ds000001", "fmriprep")
#'
#' # Download specific subjects
#' on_download_derivatives("ds000001", "fmriprep",
#'                         subjects = c("sub-01", "sub-02"))
#'
#' # Download only MNI-space outputs
#' on_download_derivatives("ds000001", "fmriprep",
#'                         space = "MNI152NLin2009cAsym")
#'
#' # Download only BOLD and mask files
#' on_download_derivatives("ds000001", "fmriprep",
#'                         suffix = c("bold", "mask"))
#'
#' # Preview files without downloading
#' files <- on_download_derivatives("ds000001", "fmriprep",
#'                                   subjects = "sub-01",
#'                                   space = "MNI152NLin2009cAsym",
#'                                   dry_run = TRUE)
#' print(files)
#'
#' # Combine all filters
#' on_download_derivatives("ds000001", "fmriprep",
#'                         subjects = regex("sub-0[1-5]"),
#'                         space = "MNI152NLin2009cAsym",
#'                         suffix = c("bold", "T1w"))
#' }
#'
#' @seealso [on_derivatives()] to discover available derivatives,
#'   [on_spaces()] to discover available output spaces,
#'   [on_download()] to download raw datasets
on_download_derivatives <- function(dataset_id,
                                     pipeline,
                                     subjects = NULL,
                                     space = NULL,
                                     suffix = NULL,
                                     dry_run = FALSE,
                                     dest_dir = NULL,
                                     use_cache = TRUE,
                                     quiet = FALSE,
                                     verbose = FALSE,
                                     force = FALSE,
                                     backend = NULL,
                                     client = NULL) {
  # Validate dataset_id
  if (missing(dataset_id) || !is.character(dataset_id) ||
      length(dataset_id) != 1 || nchar(dataset_id) == 0) {
    rlang::abort(
      c("Invalid dataset identifier",
        "x" = "`dataset_id` must be a non-empty character string",
        "i" = 'Example: on_download_derivatives("ds000001", "fmriprep")'),
      class = "openneuro_validation_error"
    )
  }

  # Validate pipeline
  if (missing(pipeline) || !is.character(pipeline) ||
      length(pipeline) != 1 || nchar(pipeline) == 0) {
    rlang::abort(
      c("Invalid pipeline name",
        "x" = "`pipeline` must be a non-empty character string",
        "i" = 'Example: on_download_derivatives("ds000001", "fmriprep")'),
      class = "openneuro_validation_error"
    )
  }

  # Get or create client
  client <- client %||% on_client()

  # Validate derivative exists via on_derivatives() lookup
  deriv_info <- on_derivatives(dataset_id, refresh = FALSE, client = client)

  if (nrow(deriv_info) == 0) {
    rlang::abort(
      c("No derivatives found",
        "x" = paste0("Dataset '", dataset_id, "' has no available derivatives"),
        "i" = "Use on_derivatives() to check available pipelines"),
      class = "openneuro_validation_error"
    )
  }

  # Find the matching pipeline
  pipeline_row <- deriv_info[deriv_info$pipeline == pipeline, ]

  if (nrow(pipeline_row) == 0) {
    available_pipelines <- paste(deriv_info$pipeline, collapse = ", ")
    rlang::abort(
      c("Pipeline not found",
        "x" = paste0("Pipeline '", pipeline, "' not available for ", dataset_id),
        "i" = paste0("Available pipelines: ", available_pipelines)),
      class = "openneuro_validation_error"
    )
  }

  # Use first match (embedded takes precedence per discovery logic)
  pipeline_row <- pipeline_row[1, ]
  source <- pipeline_row$source[1]

  # Determine destination directory
  caching <- is.null(dest_dir) && use_cache
  if (caching) {
    dest_dir <- .on_derivative_cache_path(dataset_id, pipeline)
  } else if (is.null(dest_dir)) {
    dest_dir <- fs::path(getwd(), dataset_id, "derivatives", pipeline)
  }

  # Get full file listing
  if (!quiet) {
    cli::cli_alert_info("Listing derivative files...")
  }

  files_df <- .list_derivative_files_full(
    dataset_id = dataset_id,
    pipeline = pipeline,
    source = source,
    client = client
  )

  if (nrow(files_df) == 0) {
    if (!quiet) {
      cli::cli_alert_warning(
        "No files found for {.val {pipeline}} derivative of {.val {dataset_id}}"
      )
    }
    if (dry_run) {
      return(tibble::tibble(
        path = character(),
        size = numeric(),
        size_formatted = character(),
        dest_path = character()
      ))
    }
    return(invisible(list(
      downloaded = 0L,
      skipped = 0L,
      failed = character(),
      total_bytes = 0,
      dest_dir = dest_dir,
      backend = NA_character_
    )))
  }

  # Apply filter chain (AND logic)

  # 1. Subject filter
  if (!is.null(subjects)) {
    if (is_regex(subjects)) {
      # Regex matching
      pattern <- as.character(subjects)
      files_df <- .filter_derivative_files_by_subjects_regex(files_df, pattern)
    } else {
      # Literal subject IDs - normalize and filter
      normalized <- .normalize_subject_ids(subjects)
      files_df <- .filter_derivative_files_by_subjects(files_df, normalized)
    }
  }

  # 2. Space filter
  if (!is.null(space)) {
    files_df <- .filter_files_by_space(files_df, space)
  }


  # 3. Suffix filter
  if (!is.null(suffix)) {
    files_df <- .filter_files_by_suffix(files_df, suffix)
  }

  # Check if any files remain after filtering
  if (nrow(files_df) == 0) {
    if (!quiet) {
      cli::cli_alert_warning("No files match the specified filters")
    }
    if (dry_run) {
      return(tibble::tibble(
        path = character(),
        size = numeric(),
        size_formatted = character(),
        dest_path = character()
      ))
    }
    return(invisible(list(
      downloaded = 0L,
      skipped = 0L,
      failed = character(),
      total_bytes = 0,
      dest_dir = dest_dir,
      backend = NA_character_
    )))
  }

  # dry_run handling
  if (dry_run) {
    return(tibble::tibble(
      path = files_df$full_path,
      size = files_df$size,
      size_formatted = vapply(files_df$size, .format_bytes, character(1)),
      dest_path = as.character(fs::path(dest_dir, files_df$full_path))
    ))
  }

  # Ensure destination directory exists
  fs::dir_create(dest_dir, recurse = TRUE)

  # Download execution
  # For openneuro-derivatives bucket, construct S3 path as: {pipeline}/{dataset_id}-{pipeline}
  if (source == "openneuro-derivatives") {
    s3_dataset_id <- paste0(pipeline, "/", dataset_id, "-", pipeline)

    backend_result <- .download_with_backend(
      dataset_id = s3_dataset_id,
      dest_dir = dest_dir,
      files = files_df$full_path,
      backend = backend,
      quiet = quiet,
      bucket = "openneuro-derivatives"
    )

    if (!is.null(backend_result) && isTRUE(backend_result$success)) {
      # Batch update manifest
      if (caching) {
        dataset_root <- .on_dataset_cache_path(dataset_id)
        fs::dir_create(dataset_root, recurse = TRUE)

        file_entries <- lapply(seq_len(nrow(files_df)), function(i) {
          list(
            path = paste0("derivatives/", pipeline, "/", files_df$full_path[i]),
            size = files_df$size[i]
          )
        })
        .batch_update_manifest(
          dataset_dir = dataset_root,
          file_entries = file_entries,
          dataset_id = dataset_id,
          snapshot_tag = paste0(pipeline, "-derivative"),
          backend = backend_result$backend,
          type = "derivative"
        )
      }

      # Build result
      total_bytes <- sum(files_df$size, na.rm = TRUE)
      result <- list(
        downloaded = nrow(files_df),
        skipped = 0L,
        failed = character(),
        total_bytes = total_bytes,
        dest_dir = dest_dir,
        backend = backend_result$backend
      )

      .print_completion_summary(result, quiet)
      return(invisible(result))
    }
  }

  # HTTPS fallback or embedded source
  # For embedded derivatives, use standard download flow
  if (source == "embedded") {
    # Transform files_df to match expected format for .download_with_progress
    # Need full_path prefixed with derivatives/{pipeline}/
    download_files_df <- tibble::tibble(
      filename = files_df$filename,
      full_path = paste0("derivatives/", pipeline, "/", files_df$full_path),
      size = files_df$size,
      annexed = rep(FALSE, nrow(files_df))
    )

    # Download to parent directory (raw dataset cache) since paths include derivatives/
    parent_dest <- .on_dataset_cache_path(dataset_id)
    fs::dir_create(parent_dest, recurse = TRUE)

    result <- .download_with_progress(
      files_df = download_files_df,
      dest_dir = parent_dest,
      dataset_id = dataset_id,
      tag = NULL,
      quiet = quiet,
      verbose = verbose,
      force = force,
      use_cache = caching,
      type = "derivative"
    )

    result$backend <- "https"
    result$dest_dir <- dest_dir
    return(invisible(result))
  }

  # S3 source with HTTPS fallback (shouldn't normally reach here)
  if (!quiet) {
    cli::cli_alert_warning("S3 backend failed, HTTPS fallback not available for openneuro-derivatives")
  }

  return(invisible(list(
    downloaded = 0L,
    skipped = 0L,
    failed = files_df$full_path,
    total_bytes = 0,
    dest_dir = dest_dir,
    backend = "failed"
  )))
}


#' List All Derivative Files (Full Listing)
#'
#' Gets a complete file listing for a derivative dataset. For embedded
#' derivatives, uses the OpenNeuro API recursively. For openneuro-derivatives
#' S3 bucket, uses AWS CLI with recursive listing.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#' @param pipeline Pipeline name (e.g., "fmriprep").
#' @param source Source of derivative: "embedded" or "openneuro-derivatives".
#' @param client An `openneuro_client` object (for embedded sources).
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{filename}{Base filename}
#'     \item{full_path}{Relative path within derivative}
#'     \item{size}{File size in bytes}
#'   }
#'
#' @keywords internal
.list_derivative_files_full <- function(dataset_id, pipeline, source,
                                         client = NULL) {
  if (source == "embedded") {
    .list_derivative_files_embedded_full(dataset_id, pipeline, client)
  } else if (source == "openneuro-derivatives") {
    .list_derivative_files_s3_full(dataset_id, pipeline)
  } else {
    rlang::abort(
      c("Unknown derivative source",
        "x" = paste0("Source '", source, "' not supported"),
        "i" = "Expected 'embedded' or 'openneuro-derivatives'"),
      class = "openneuro_validation_error"
    )
  }
}


#' List Embedded Derivative Files (Full)
#'
#' Recursively lists all files in an embedded derivative using the OpenNeuro API.
#'
#' @param dataset_id Dataset identifier.
#' @param pipeline Pipeline name.
#' @param client An `openneuro_client` object.
#'
#' @return A tibble with filename, full_path, and size columns.
#'
#' @keywords internal
.list_derivative_files_embedded_full <- function(dataset_id, pipeline,
                                                   client = NULL) {
  client <- client %||% on_client()

  # Get root listing
  root_files <- tryCatch(
    on_files(dataset_id, tag = NULL, client = client),
    error = function(e) return(NULL)
  )

  if (is.null(root_files) || nrow(root_files) == 0) {
    return(.empty_derivative_files_tibble())
  }

  # Find derivatives directory
  deriv_row <- root_files[root_files$directory == TRUE &
                            root_files$filename == "derivatives", ]

  if (nrow(deriv_row) == 0) {
    return(.empty_derivative_files_tibble())
  }

  # Get derivatives directory contents
  deriv_contents <- tryCatch(
    on_files(dataset_id, tag = NULL, tree = deriv_row$key[1], client = client),
    error = function(e) return(NULL)
  )

  if (is.null(deriv_contents) || nrow(deriv_contents) == 0) {
    return(.empty_derivative_files_tibble())
  }

  # Find the pipeline directory
  pipeline_row <- deriv_contents[deriv_contents$directory == TRUE &
                                   deriv_contents$filename == pipeline, ]

  if (nrow(pipeline_row) == 0) {
    return(.empty_derivative_files_tibble())
  }

  # Recursively list all files in pipeline directory
  all_files <- .list_directory_recursive(
    dataset_id = dataset_id,
    tag = NULL,
    key = pipeline_row$key[1],
    parent_path = "",
    client = client
  )

  all_files
}


#' Recursively List Directory Contents
#'
#' Helper to recursively traverse a directory tree via API.
#'
#' @param dataset_id Dataset identifier.
#' @param tag Snapshot tag (can be NULL).
#' @param key Directory key for API call.
#' @param parent_path Path prefix for building full paths.
#' @param client An `openneuro_client` object.
#'
#' @return A tibble with filename, full_path, and size columns.
#'
#' @keywords internal
.list_directory_recursive <- function(dataset_id, tag, key, parent_path,
                                        client) {
  dir_files <- tryCatch(
    on_files(dataset_id, tag = tag, tree = key, client = client),
    error = function(e) return(NULL)
  )

  if (is.null(dir_files) || nrow(dir_files) == 0) {
    return(.empty_derivative_files_tibble())
  }

  has_parent <- length(parent_path) == 1 && !is.na(parent_path) && nzchar(parent_path)
  entry_paths <- if (has_parent) {
    paste0(parent_path, "/", dir_files$filename)
  } else {
    dir_files$filename
  }

  file_mask <- !dir_files$directory
  dir_mask <- dir_files$directory

  result_parts <- list()

  if (any(file_mask)) {
    result_parts[[length(result_parts) + 1L]] <- tibble::tibble(
      filename = dir_files$filename[file_mask],
      full_path = entry_paths[file_mask],
      size = as.numeric(dir_files$size[file_mask])
    )
  }

  if (any(dir_mask)) {
    dir_keys <- dir_files$key[dir_mask]
    dir_paths <- entry_paths[dir_mask]

    sub_parts <- Map(
      function(subkey, subpath) {
        .list_directory_recursive(
          dataset_id = dataset_id,
          tag = tag,
          key = subkey,
          parent_path = subpath,
          client = client
        )
      },
      dir_keys,
      dir_paths
    )

    # Drop empty results early to avoid bind overhead
    sub_parts <- sub_parts[vapply(sub_parts, nrow, integer(1)) > 0]

    result_parts <- c(result_parts, sub_parts)
  }

  if (length(result_parts) == 0) {
    return(.empty_derivative_files_tibble())
  }

  dplyr::bind_rows(result_parts)
}


#' List S3 Derivative Files (Full)
#'
#' Lists all files from the openneuro-derivatives S3 bucket using AWS CLI.
#' Paginates through the entire listing without limits.
#'
#' @param dataset_id Dataset identifier.
#' @param pipeline Pipeline name.
#'
#' @return A tibble with filename, full_path, and size columns.
#'
#' @keywords internal
.list_derivative_files_s3_full <- function(dataset_id, pipeline) {
  aws_cli <- .find_aws_cli()

  if (!nzchar(aws_cli)) {
    rlang::warn(
      c("AWS CLI not available",
        "i" = "Install AWS CLI to list OpenNeuroDerivatives S3 bucket",
        "i" = "Returning empty file list"),
      class = "openneuro_aws_warning"
    )
    return(.empty_derivative_files_tibble())
  }

  # Build S3 path: s3://openneuro-derivatives/{pipeline}/{dataset_id}-{pipeline}/
  s3_path <- paste0("s3://openneuro-derivatives/", pipeline, "/",
                    dataset_id, "-", pipeline, "/")

  # Use AWS CLI with recursive listing (no pagination limits)
  result <- tryCatch({
    processx::run(
      command = aws_cli,
      args = c("s3", "ls", "--no-sign-request", "--recursive", s3_path),
      timeout = 120,  # Longer timeout for full listing
      error_on_status = FALSE
    )
  }, error = function(e) {
    rlang::warn(
      c("Failed to run AWS CLI",
        "x" = conditionMessage(e)),
      class = "openneuro_aws_warning"
    )
    return(list(status = 1, stdout = "", stderr = conditionMessage(e)))
  })

  if (result$status != 0) {
    stderr_lower <- tolower(result$stderr)
    if (grepl("access denied|accessdenied|forbidden", stderr_lower)) {
      rlang::warn(
        c("Access denied to OpenNeuroDerivatives S3 bucket",
          "i" = paste0("Could not list files for ", dataset_id, "-", pipeline)),
        class = "openneuro_s3_access_warning"
      )
    } else if (!grepl("nosuchkey|nosuchbucket|not found", stderr_lower)) {
      rlang::warn(
        c("AWS S3 listing failed",
          "x" = result$stderr),
        class = "openneuro_aws_warning"
      )
    }
    return(.empty_derivative_files_tibble())
  }

  # Parse AWS ls output
  # Format: "2024-01-15 12:34:56    1234567 path/to/file.nii.gz"
  lines <- strsplit(result$stdout, "\n", fixed = TRUE)[[1]]
  lines <- lines[nzchar(trimws(lines))]

  if (length(lines) == 0) {
    return(.empty_derivative_files_tibble())
  }

  # Parse each line
  parsed <- lapply(lines, function(line) {
    # Split by whitespace
    parts <- strsplit(trimws(line), "\\s+")[[1]]
    if (length(parts) >= 4) {
      # Size is 3rd element, path is 4th element
      size <- as.numeric(parts[3])
      full_path <- parts[4]
      filename <- basename(full_path)
      list(filename = filename, full_path = full_path, size = size)
    } else {
      NULL
    }
  })

  # Remove NULLs
  parsed <- Filter(Negate(is.null), parsed)

  if (length(parsed) == 0) {
    return(.empty_derivative_files_tibble())
  }

  tibble::tibble(
    filename = vapply(parsed, function(x) x$filename, character(1)),
    full_path = vapply(parsed, function(x) x$full_path, character(1)),
    size = vapply(parsed, function(x) x$size, numeric(1))
  )
}


#' Filter Files by Space
#'
#' Filters a file tibble to include only files matching the specified space
#' or files without a `_space-` entity (native space per BIDS convention).
#'
#' @param files_df A tibble with `full_path` column.
#' @param space Character string: space name to filter by (exact match).
#'
#' @return Filtered tibble.
#'
#' @keywords internal
.filter_files_by_space <- function(files_df, space) {
  if (length(space) == 0 || is.null(space)) {
    return(files_df)
  }

  # Extract space from each filename
  file_spaces <- vapply(files_df$full_path, function(path) {
    .extract_space_from_filename(basename(path))
  }, character(1), USE.NAMES = FALSE)

  # Keep files that:
  # 1. Have matching space (exact match)
  # 2. Have no space entity (NA = native space, always include)
  keep <- file_spaces == space | is.na(file_spaces)

  # Warn if requested space not found in any file
  available_spaces <- unique(file_spaces[!is.na(file_spaces)])
  if (!space %in% available_spaces && length(available_spaces) > 0) {
    rlang::warn(
      c("Requested space not found in files",
        "x" = paste0("Space '", space, "' not found"),
        "i" = paste0("Available spaces: ", paste(available_spaces, collapse = ", "))),
      class = "openneuro_space_warning"
    )
  }

  files_df[keep, ]
}


#' Filter Files by BIDS Suffix
#'
#' Filters a file tibble to include only files matching the specified BIDS
#' suffixes. Files without a clear suffix (metadata files, etc.) are always
#' included.
#'
#' @param files_df A tibble with `full_path` column.
#' @param suffix Character vector: BIDS suffixes to filter by.
#'
#' @return Filtered tibble.
#'
#' @keywords internal
.filter_files_by_suffix <- function(files_df, suffix) {
  if (length(suffix) == 0 || is.null(suffix)) {
    return(files_df)
  }

  # Extract suffix from each filename
  file_suffixes <- vapply(files_df$full_path, function(path) {
    .extract_suffix_from_filename(basename(path))
  }, character(1), USE.NAMES = FALSE)

  # Keep files that:
  # 1. Have a matching suffix
  # 2. Have no clear suffix (NA = metadata file, always include)
  keep <- file_suffixes %in% suffix | is.na(file_suffixes)

  files_df[keep, ]
}


#' Extract BIDS Suffix from Filename
#'
#' Extracts the BIDS suffix from a filename. The suffix is the part
#' after the last underscore and before the extension.
#'
#' @param filename Character string: a BIDS-formatted filename.
#'
#' @return Character string: the suffix, or `NA_character_` if none found.
#'
#' @details
#' Handles compound extensions like `.nii.gz`, `.func.gii`, `.dtseries.nii`.
#'
#' @examples
#' \dontrun{
#' .extract_suffix_from_filename("sub-01_space-MNI_desc-preproc_bold.nii.gz")
#' # Returns: "bold"
#'
#' .extract_suffix_from_filename("dataset_description.json")
#' # Returns: NA_character_ (not a BIDS file)
#' }
#'
#' @keywords internal
.extract_suffix_from_filename <- function(filename) {
  # Remove directory path
  basename_part <- basename(filename)

  # Handle compound extensions
  # Order matters - check longer patterns first
  compound_patterns <- c(
    "\\.dtseries\\.nii$",
    "\\.dlabel\\.nii$",
    "\\.ptseries\\.nii$",
    "\\.func\\.gii$",
    "\\.surf\\.gii$",
    "\\.label\\.gii$",
    "\\.shape\\.gii$",
    "\\.nii\\.gz$",
    "\\.tsv\\.gz$",
    "\\.json$",
    "\\.tsv$",
    "\\.nii$",
    "\\.gii$",
    "\\.txt$",
    "\\.html$",
    "\\.svg$"
  )

  no_ext <- basename_part
  for (pat in compound_patterns) {
    if (grepl(pat, no_ext, ignore.case = TRUE)) {
      no_ext <- sub(pat, "", no_ext, ignore.case = TRUE)
      break
    }
  }

  # If no extension was removed, try generic extension removal
  if (no_ext == basename_part) {
    no_ext <- sub("\\.[^.]+$", "", no_ext)
  }

  # Get last underscore-separated part
  parts <- strsplit(no_ext, "_", fixed = TRUE)[[1]]

  if (length(parts) <= 1) {
    # No underscore or single part = likely not a BIDS file
    return(NA_character_)
  }

  # Return the last part
  parts[length(parts)]
}


#' Filter Derivative Files by Subject IDs (Literal)
#'
#' Filters derivative files to include only those belonging to specified subjects.
#'
#' @param files_df A tibble with `full_path` column.
#' @param subjects Character vector of normalized subject IDs (with "sub-" prefix).
#'
#' @return Filtered tibble.
#'
#' @keywords internal
.filter_derivative_files_by_subjects <- function(files_df, subjects) {
  if (length(subjects) == 0) {
    return(files_df)
  }

  paths <- files_df$full_path

  # Build single alternation regex for all subjects (vectorized)
  subj_alt <- paste(subjects, collapse = "|")

  # Match subject directory: sub-XX/... or .../sub-XX/...
  dir_pattern <- paste0("(^|/)(", subj_alt, ")/")
  # Match subject in filename: sub-XX_...
  file_pattern <- paste0("(^|/)(", subj_alt, ")_")
  # Root-level files (no subject reference) are always included
  no_subject <- !grepl("/sub-", paths) & !grepl("^sub-", paths)

  keep <- grepl(dir_pattern, paths) | grepl(file_pattern, paths) | no_subject

  files_df[keep, ]
}


#' Filter Derivative Files by Subject Regex
#'
#' Filters derivative files using a regex pattern for subject matching.
#'
#' @param files_df A tibble with `full_path` column.
#' @param pattern Regex pattern string for subject matching.
#'
#' @return Filtered tibble.
#'
#' @keywords internal
.filter_derivative_files_by_subjects_regex <- function(files_df, pattern) {
  # Auto-anchor pattern for full subject ID matching
  anchored <- paste0("(^|/)(", pattern, ")(/|_)")

  keep <- vapply(files_df$full_path, function(path) {
    if (grepl(anchored, path)) {
      return(TRUE)
    }
    # Root-level files (no subject directory) are included
    if (!grepl("/sub-", path) && !grepl("^sub-", path)) {
      return(TRUE)
    }
    FALSE
  }, logical(1), USE.NAMES = FALSE)

  files_df[keep, ]
}


#' Get Derivative Cache Path
#'
#' Returns the cache path for a derivative dataset.
#' Structure: `{cache_root}/{dataset_id}/derivatives/{pipeline}/`
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#' @param pipeline Pipeline name (e.g., "fmriprep").
#'
#' @return Character string: path to derivative cache directory.
#'
#' @keywords internal
.on_derivative_cache_path <- function(dataset_id, pipeline) {
  base_path <- .on_dataset_cache_path(dataset_id)
  fs::path(base_path, "derivatives", pipeline)
}


#' Create Empty Derivative Files Tibble
#'
#' Returns an empty tibble with the structure used for derivative file listings.
#'
#' @return An empty tibble with filename, full_path, and size columns.
#'
#' @keywords internal
.empty_derivative_files_tibble <- function() {
  tibble::tibble(
    filename = character(),
    full_path = character(),
    size = numeric()
  )
}
