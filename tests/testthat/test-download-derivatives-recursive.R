# Tests for embedded derivative recursive listing helpers

test_that(".list_directory_recursive returns full paths for nested trees", {
  local_mocked_bindings(
    on_files = function(dataset_id, tag = NULL, tree = NULL, client = NULL, ...) {
      entries <- switch(tree,
        "k_root" = tibble::tibble(
          filename = c("fileA.txt", "subdir"),
          size = c(1, NA_real_),
          directory = c(FALSE, TRUE),
          annexed = c(FALSE, FALSE),
          key = c(NA_character_, "k_subdir")
        ),
        "k_subdir" = tibble::tibble(
          filename = c("fileB.txt", "nested"),
          size = c(2, NA_real_),
          directory = c(FALSE, TRUE),
          annexed = c(FALSE, FALSE),
          key = c(NA_character_, "k_nested")
        ),
        "k_nested" = tibble::tibble(
          filename = c("fileC.txt"),
          size = c(3),
          directory = c(FALSE),
          annexed = c(FALSE),
          key = c(NA_character_)
        ),
        tibble::tibble(
          filename = character(),
          size = numeric(),
          directory = logical(),
          annexed = logical(),
          key = character()
        )
      )

      entries
    }
  )

  result <- .list_directory_recursive(
    dataset_id = "ds000001",
    tag = NULL,
    key = "k_root",
    parent_path = "",
    client = NULL
  )

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 3L)
  expect_setequal(
    result$full_path,
    c("fileA.txt", "subdir/fileB.txt", "subdir/nested/fileC.txt")
  )
})

