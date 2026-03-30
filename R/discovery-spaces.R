#' Space Discovery for Derivative Datasets
#'
#' Functions for discovering available output spaces (MNI152NLin2009cAsym,
#' fsaverage, etc.) in derivative datasets.
#'
#' @name discovery-spaces
#' @keywords internal
NULL

#' Extract Space from BIDS Filename
#'
#' Extracts the space label from a BIDS-formatted filename. Looks for the
#' `_space-<label>` entity pattern.
#'
#' @param filename Character string: A BIDS-formatted filename.
#'
#' @return Character string: The space label, or `NA_character_` if no
#'   space entity is found.
#'
#' @details
#' This function does NOT infer T1w from files without a space entity.
#' Per BIDS convention, native space files often omit the space entity,
#' so absence of `_space-` does not imply T1w space.
#'
#' @keywords internal
.extract_space_from_filename <- function(filename) {
  # Pattern matches _space- followed by alphanumeric characters

# Captures the space label until the next _ or end of string
  pattern <- "_space-([A-Za-z0-9]+)"
  match <- regmatches(filename, regexpr(pattern, filename, perl = TRUE))

  if (length(match) == 0 || nchar(match) == 0) {
    return(NA_character_)
  }

  # Remove the "_space-" prefix to get just the label
  sub("^_space-", "", match)
}

#' Extract Unique Spaces from Filenames
#'
#' Extracts unique space labels from a vector of BIDS-formatted filenames.
#' Results are sorted alphabetically and NAs are removed.
#'
#' @param filenames Character vector: BIDS-formatted filenames.
#'
#' @return Character vector: Unique space labels, sorted alphabetically.
#'   Returns `character(0)` if no spaces are found.
#'
#' @keywords internal
.extract_spaces_from_files <- function(filenames) {
  if (length(filenames) == 0) {
    return(character(0))
  }

  # Extract space from each filename
  spaces <- vapply(filenames, .extract_space_from_filename, character(1),
                   USE.NAMES = FALSE)

  # Remove NAs, get unique, sort alphabetically
  spaces <- spaces[!is.na(spaces)]

  if (length(spaces) == 0) {
    return(character(0))
  }

  sort(unique(spaces))
}

#' List Derivative Files for Embedded Sources
#'
#' Lists files from an embedded derivative dataset using the OpenNeuro API.
#' Samples files from the first few subjects to efficiently determine
#' available spaces without exhaustive listing.
#'
#' @param dataset_id Character string: Dataset identifier (e.g., "ds000102").
#' @param pipeline Character string: Pipeline name (e.g., "fmriprep").
#' @param tag Character string or NULL: Snapshot version tag.
#' @param client An `openneuro_client` object, or NULL to use default.
#'
#' @return Character vector: Filenames found in the derivative dataset.
#'
#' @details
#' This function navigates the `derivatives/<pipeline>/` tree and samples
#' files from the first 2-3 subjects. It looks in both `func/` and `anat/`
#' subdirectories for each subject.
#'
#' @keywords internal
.list_derivative_files_embedded <- function(dataset_id, pipeline, tag = NULL,
                                             client = NULL) {
  # Get root file listing
  root_files <- tryCatch(
    on_files(dataset_id, tag, client = client),
    error = function(e) {
      return(NULL)
    }
  )

  if (is.null(root_files) || nrow(root_files) == 0) {
    return(character(0))
  }

  # Find derivatives directory
  deriv_row <- root_files[root_files$directory == TRUE &
                            root_files$filename == "derivatives", ]

  if (nrow(deriv_row) == 0) {
    return(character(0))
  }

  # Get derivatives directory contents
  deriv_contents <- tryCatch(
    on_files(dataset_id, tag, tree = deriv_row$key[1], client = client),
    error = function(e) {
      return(NULL)
    }
  )

  if (is.null(deriv_contents) || nrow(deriv_contents) == 0) {
    return(character(0))
  }

  # Find the specific pipeline directory
  pipeline_row <- deriv_contents[deriv_contents$directory == TRUE &
                                   deriv_contents$filename == pipeline, ]

  if (nrow(pipeline_row) == 0) {
    return(character(0))
  }

  # Get pipeline directory contents
  pipeline_contents <- tryCatch(
    on_files(dataset_id, tag, tree = pipeline_row$key[1], client = client),
    error = function(e) {
      return(NULL)
    }
  )

  if (is.null(pipeline_contents) || nrow(pipeline_contents) == 0) {
    return(character(0))
  }

  # Collect filenames from subject directories (sample first 3 subjects)
  all_filenames <- character(0)

  # Helper: list filenames (non-directories) within a directory key
  .list_files_in_dir <- function(dir_key) {
    dir_contents <- tryCatch(
      on_files(dataset_id, tag, tree = dir_key, client = client),
      error = function(e) {
        return(NULL)
      }
    )

    if (is.null(dir_contents) || nrow(dir_contents) == 0) {
      return(character(0))
    }

    files <- dir_contents[!dir_contents$directory, ]
    files$filename
  }

  # Look for subject directories (sub-*)
  subject_dirs <- pipeline_contents[pipeline_contents$directory == TRUE &
                                      grepl("^sub-", pipeline_contents$filename), ]

  # Limit to first 3 subjects for efficiency
  n_subjects <- min(3, nrow(subject_dirs))
  if (n_subjects == 0) {
    # No subject directories - check for files directly in pipeline dir
    files <- pipeline_contents[!pipeline_contents$directory, ]
    return(files$filename)
  }

  for (i in seq_len(n_subjects)) {
    subject_key <- subject_dirs$key[i]

    # Get subject directory contents
    subject_contents <- tryCatch(
      on_files(dataset_id, tag, tree = subject_key, client = client),
      error = function(e) {
        return(NULL)
      }
    )

    if (is.null(subject_contents) || nrow(subject_contents) == 0) {
      next
    }

    # Files directly in subject directory
    subject_files <- subject_contents[!subject_contents$directory, ]
    all_filenames <- c(all_filenames, subject_files$filename)

    # Check anat/ and func/ subdirectories directly under subject
    for (modality in c("anat", "func")) {
      mod_row <- subject_contents[subject_contents$directory == TRUE &
                                   subject_contents$filename == modality, ]
      if (nrow(mod_row) > 0) {
        all_filenames <- c(all_filenames, .list_files_in_dir(mod_row$key[1]))
      }
    }

    # Also check within session directories (ses-*)
    session_dirs <- subject_contents[subject_contents$directory == TRUE &
                                       grepl("^ses-", subject_contents$filename), ]
    if (nrow(session_dirs) > 0) {
      for (j in seq_len(nrow(session_dirs))) {
        session_contents <- tryCatch(
          on_files(dataset_id, tag, tree = session_dirs$key[j], client = client),
          error = function(e) {
            return(NULL)
          }
        )

        if (is.null(session_contents) || nrow(session_contents) == 0) {
          next
        }

        # Files directly in session directory (rare but include)
        session_files <- session_contents[!session_contents$directory, ]
        all_filenames <- c(all_filenames, session_files$filename)

        # anat/func within session
        for (modality in c("anat", "func")) {
          mod_row <- session_contents[session_contents$directory == TRUE &
                                       session_contents$filename == modality, ]
          if (nrow(mod_row) > 0) {
            all_filenames <- c(all_filenames, .list_files_in_dir(mod_row$key[1]))
          }
        }
      }
    }
  }

  unique(all_filenames)
}

#' List Derivative Files from OpenNeuroDerivatives S3 Bucket
#'
#' Lists files from the OpenNeuroDerivatives S3 bucket using the AWS CLI.
#' This function handles the `s3://openneuro-derivatives/` bucket structure.
#'
#' @param dataset_id Character string: Dataset identifier (e.g., "ds000102").
#' @param pipeline Character string: Pipeline name (e.g., "fmriprep").
#'
#' @return Character vector: Filenames found in the S3 bucket.
#'   Returns empty vector with warning if access is denied or AWS CLI
#'   is not available.
#'
#' @details
#' The OpenNeuroDerivatives S3 bucket uses the structure:
#' `s3://openneuro-derivatives/{pipeline}/{dataset_id}-{pipeline}/`
#'
#' This function uses `--no-sign-request` for anonymous access and
#' limits results to 500 items for efficiency.
#'
#' @keywords internal
.list_derivative_files_s3 <- function(dataset_id, pipeline) {
  # Check if AWS CLI is available
  aws_cli <- .find_aws_cli()

  if (!nzchar(aws_cli)) {
    rlang::warn(
      c("AWS CLI not available",
        "i" = "Install AWS CLI to access OpenNeuroDerivatives S3 bucket",
        "i" = "Returning empty space list for this derivative"),
      class = "openneuro_aws_warning"
    )
    return(character(0))
  }

  # Build S3 path
  # Structure: s3://openneuro-derivatives/{pipeline}/{dataset_id}-{pipeline}/
  s3_path <- paste0("s3://openneuro-derivatives/", pipeline, "/",
                    dataset_id, "-", pipeline, "/")

  # Build AWS CLI command
  # Use --no-sign-request for anonymous access
  # Limit to 500 items for efficiency (we just need space sampling)
  result <- tryCatch({
    processx::run(
      command = aws_cli,
      args = c("s3", "ls", "--no-sign-request", "--recursive",
               s3_path, "--max-items", "500"),
      timeout = 30,
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

  # Check for errors
  if (result$status != 0) {
    stderr_lower <- tolower(result$stderr)
    if (grepl("access denied|accessdenied|forbidden", stderr_lower)) {
      rlang::warn(
        c("Access denied to OpenNeuroDerivatives S3 bucket",
          "i" = paste0("Could not list files for ", dataset_id, "-", pipeline),
          "i" = "This derivative may not be available via S3"),
        class = "openneuro_s3_access_warning"
      )
    } else if (grepl("nosuchkey|nosuchbucket|not found", stderr_lower)) {
      # Not found - not a warning, just no files
      return(character(0))
    } else {
      rlang::warn(
        c("AWS S3 listing failed",
          "x" = result$stderr),
        class = "openneuro_aws_warning"
      )
    }
    return(character(0))
  }

  # Parse AWS ls output
  # Format: "2024-01-15 12:34:56    1234567 path/to/file.nii.gz"
  lines <- strsplit(result$stdout, "\n", fixed = TRUE)[[1]]
  lines <- lines[nzchar(trimws(lines))]

  if (length(lines) == 0) {
    return(character(0))
  }

  # Extract just the filename (last component of path)
  filenames <- vapply(lines, function(line) {
    # Split by whitespace and get the path (4th column)
    parts <- strsplit(trimws(line), "\\s+")[[1]]
    if (length(parts) >= 4) {
      # Get the full path and extract just the filename
      full_path <- parts[length(parts)]
      basename(full_path)
    } else {
      NA_character_
    }
  }, character(1), USE.NAMES = FALSE)

  filenames <- filenames[!is.na(filenames)]
  unique(filenames)
}

#' Discover Available Output Spaces
#'
#' Discovers the available output spaces (MNI152NLin2009cAsym, fsaverage, etc.)
#' for a derivative dataset. Parses BIDS `_space-` entity from filenames.
#'
#' @param derivative A single-row tibble from [on_derivatives()] output.
#'   Must contain columns: `dataset_id`, `pipeline`, and `source`.
#' @param refresh If `TRUE`, bypass cache and fetch fresh data.
#'   Default is `FALSE` to use cached results.
#' @param client An `openneuro_client` object for API calls (embedded sources).
#'   If `NULL` (default), creates a default client.
#'
#' @return A character vector of space names, sorted alphabetically.
#'   Common spaces include:
#'   \itemize{
#'     \item Volumetric: MNI152NLin2009cAsym, MNI152NLin6Asym, T1w
#'     \item Surface: fsaverage, fsaverage5, fsaverage6, fsnative
#'   }
#'
#'   Returns `character(0)` with a warning if no spaces are found.
#'
#' @details
#' ## Space Discovery
#'
#' This function samples derivative files and extracts the `_space-<label>`
#' entity from BIDS-formatted filenames. It does NOT infer T1w from files
#' without a space entity (per BIDS convention, native space files may
#' omit the space entity).
#'
#' ## Source Handling
#'
#' - **embedded**: Uses the OpenNeuro API to list files in the
#'   `derivatives/{pipeline}/` directory.
#' - **openneuro-derivatives**: Uses AWS CLI to list files from the
#'   `s3://openneuro-derivatives/` bucket.
#'
#' ## Caching
#'
#' Results are cached per-session to minimize API/S3 calls. Use
#' `refresh = TRUE` to bypass the cache.
#'
#' @export
#'
#' @examples
#' \donttest{
#' # First, get available derivatives for a dataset
#' derivs <- on_derivatives("ds000102")
#' print(derivs)
#'
#' # Then get spaces for the first derivative
#' spaces <- on_spaces(derivs[1, ])
#' print(spaces)
#' # Example output: c("MNI152NLin2009cAsym", "fsaverage")
#'
#' # Force refresh of cached spaces
#' spaces <- on_spaces(derivs[1, ], refresh = TRUE)
#' }
#'
#' @seealso [on_derivatives()] to discover available derivative datasets
on_spaces <- function(derivative, refresh = FALSE, client = NULL) {
  # Input validation: must be a data.frame with exactly 1 row
  if (!is.data.frame(derivative)) {
    rlang::abort(
      c("Invalid derivative argument",
        "x" = "`derivative` must be a data.frame (tibble) from on_derivatives()",
        "i" = "Use: on_derivatives(\"ds000102\") |> dplyr::slice(1) |> on_spaces()"),
      class = "openneuro_validation_error"
    )
  }

  if (nrow(derivative) != 1) {
    rlang::abort(
      c("Invalid derivative argument",
        "x" = paste0("`derivative` must have exactly 1 row, got ", nrow(derivative)),
        "i" = "Use dplyr::slice() or [1, ] to select a single derivative"),
      class = "openneuro_validation_error"
    )
  }

  # Check required columns
  required_cols <- c("dataset_id", "pipeline", "source")
  missing_cols <- setdiff(required_cols, names(derivative))

  if (length(missing_cols) > 0) {
    rlang::abort(
      c("Missing required columns in derivative",
        "x" = paste0("Missing: ", paste(missing_cols, collapse = ", ")),
        "i" = "Ensure derivative is from on_derivatives() output"),
      class = "openneuro_validation_error"
    )
  }

  # Extract values
  dataset_id <- derivative$dataset_id[1]
  pipeline <- derivative$pipeline[1]
  source <- derivative$source[1]

  # Build cache key
  cache_key <- paste0("spaces_", dataset_id, "_", pipeline, "_", source)

  # Check cache (unless refresh requested)
  if (!refresh && .discovery_cache$has(cache_key)) {
    return(.discovery_cache$get(cache_key))
  }

  # Get file listing based on source
  filenames <- if (source == "embedded") {
    .list_derivative_files_embedded(dataset_id, pipeline, tag = NULL,
                                     client = client)
  } else if (source == "openneuro-derivatives") {
    .list_derivative_files_s3(dataset_id, pipeline)
  } else {
    rlang::warn(
      c("Unknown derivative source",
        "x" = paste0("Source '", source, "' not recognized"),
        "i" = "Expected 'embedded' or 'openneuro-derivatives'"),
      class = "openneuro_unknown_source_warning"
    )
    character(0)
  }

  # Extract spaces from filenames
  spaces <- .extract_spaces_from_files(filenames)

  # Warn if no spaces found
  if (length(spaces) == 0) {
    rlang::warn(
      c("No output spaces found",
        "i" = paste0("Could not detect spaces for ", dataset_id, " ", pipeline),
        "i" = "Files may not contain _space- entity or listing failed"),
      class = "openneuro_no_spaces_warning"
    )
  }

  # Cache and return
  .discovery_cache$set(cache_key, spaces)
  spaces
}
