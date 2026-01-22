# Tests for api-search.R - on_search() functionality

test_that("on_search returns tibble with expected columns", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_search(limit = 3)
    expect_s3_class(result, "tbl_df")
    expect_named(result, c("id", "name", "created", "public", "modalities", "n_subjects", "tasks"))
    expect_true(nrow(result) >= 1)
  })
})

test_that("on_search returns datasets with valid data types", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_search(limit = 3)

    expect_type(result$id, "character")
    expect_type(result$name, "character")
    expect_s3_class(result$created, "POSIXct")
    expect_type(result$public, "logical")
    expect_type(result$modalities, "list")
    expect_type(result$n_subjects, "integer")
    expect_type(result$tasks, "list")
  })
})

test_that("on_search respects limit parameter", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_search(limit = 3)
    # We can't guarantee exact count (API may return fewer), but should not exceed limit
    expect_true(nrow(result) <= 3)
  })
})

test_that("on_search dataset IDs start with 'ds'", {
  skip_if_no_mocks("openneuro.org")

  with_mock_dir("openneuro.org", {
    result <- on_search(limit = 3)
    expect_true(all(grepl("^ds", result$id)))
  })
})

# --- Tests with mocked on_request ---

test_that("on_search with query returns results", {
  # Mock a successful search response
  local_mocked_bindings(
    on_request = function(gql, variables, client) {
      list(
        search = list(
          edges = list(
            list(node = list(
              id = "ds000001",
              name = "Test Dataset",
              created = "2024-01-01T00:00:00.000Z",
              public = TRUE,
              latestSnapshot = list(
                summary = list(
                  modalities = list("MRI"),
                  subjects = list("sub-01", "sub-02"),
                  tasks = list("rest")
                )
              )
            ))
          ),
          pageInfo = list(hasNextPage = FALSE, endCursor = NULL)
        )
      )
    },
    on_client = function() list(url = "https://openneuro.org/crn/graphql")
  )

  result <- on_search(query = "visual", limit = 10)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$id[1], "ds000001")
})

test_that("on_search warns when search API returns null", {
  # Mock an empty search response (API unavailable case)
  local_mocked_bindings(
    on_request = function(gql, variables, client) {
      list(search = NULL)  # Search API returns null
    },
    on_client = function() list(url = "https://openneuro.org/crn/graphql")
  )

  expect_warning(
    result <- on_search(query = "nonexistent", limit = 10),
    "search API"
  )
  expect_equal(nrow(result), 0)
})

test_that("on_search pagination with all=TRUE loops through pages", {
  call_count <- 0

  local_mocked_bindings(
    on_request = function(gql, variables, client) {
      call_count <<- call_count + 1
      if (call_count == 1) {
        # First page
        list(
          search = list(
            edges = list(
              list(node = list(
                id = "ds000001",
                name = "Dataset 1",
                created = "2024-01-01T00:00:00.000Z",
                public = TRUE,
                latestSnapshot = list(summary = list(modalities = list(), subjects = list(), tasks = list()))
              ))
            ),
            pageInfo = list(hasNextPage = TRUE, endCursor = "cursor1")
          )
        )
      } else {
        # Second page (last)
        list(
          search = list(
            edges = list(
              list(node = list(
                id = "ds000002",
                name = "Dataset 2",
                created = "2024-01-02T00:00:00.000Z",
                public = TRUE,
                latestSnapshot = list(summary = list(modalities = list(), subjects = list(), tasks = list()))
              ))
            ),
            pageInfo = list(hasNextPage = FALSE, endCursor = NULL)
          )
        )
      }
    },
    on_client = function() list(url = "https://openneuro.org/crn/graphql")
  )

  result <- on_search(query = "test", all = TRUE)
  expect_equal(call_count, 2)  # Should have made 2 API calls
  expect_equal(nrow(result), 2)  # Should have combined results
  expect_equal(result$id, c("ds000001", "ds000002"))
})

# --- .on_list_datasets tests ---

test_that(".on_list_datasets returns datasets without query", {
  local_mocked_bindings(
    on_request = function(gql, variables, client) {
      list(
        datasets = list(
          edges = list(
            list(node = list(
              id = "ds000003",
              name = "Listed Dataset",
              created = "2024-01-01T00:00:00.000Z",
              public = TRUE,
              latestSnapshot = list(
                summary = list(
                  modalities = list("EEG"),
                  subjects = list("sub-01"),
                  tasks = list()
                )
              )
            ))
          ),
          pageInfo = list(hasNextPage = FALSE)
        )
      )
    },
    on_client = function() list(url = "https://openneuro.org/crn/graphql")
  )

  result <- .on_list_datasets(limit = 10)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$id[1], "ds000003")
})

test_that(".on_list_datasets with modality filter", {
  local_mocked_bindings(
    on_request = function(gql, variables, client) {
      # Verify modality is passed in variables
      expect_equal(variables$modality, "MRI")
      list(
        datasets = list(
          edges = list(
            list(node = list(
              id = "ds000004",
              name = "MRI Dataset",
              created = "2024-01-01T00:00:00.000Z",
              public = TRUE,
              latestSnapshot = list(
                summary = list(
                  modalities = list("MRI"),
                  subjects = list("sub-01"),
                  tasks = list()
                )
              )
            ))
          ),
          pageInfo = list(hasNextPage = FALSE)
        )
      )
    },
    on_client = function() list(url = "https://openneuro.org/crn/graphql")
  )

  result <- .on_list_datasets(modality = "MRI", limit = 10)
  expect_equal(nrow(result), 1)
  expect_equal(result$id[1], "ds000004")
})

test_that(".on_list_datasets pagination with all=TRUE", {
  call_count <- 0

  local_mocked_bindings(
    on_request = function(gql, variables, client) {
      call_count <<- call_count + 1
      if (call_count == 1) {
        list(
          datasets = list(
            edges = list(
              list(node = list(
                id = "ds000005",
                name = "Dataset 5",
                created = "2024-01-01T00:00:00.000Z",
                public = TRUE,
                latestSnapshot = list(summary = list(modalities = list(), subjects = list(), tasks = list()))
              ))
            ),
            pageInfo = list(hasNextPage = TRUE, endCursor = "cursor1")
          )
        )
      } else {
        list(
          datasets = list(
            edges = list(
              list(node = list(
                id = "ds000006",
                name = "Dataset 6",
                created = "2024-01-02T00:00:00.000Z",
                public = TRUE,
                latestSnapshot = list(summary = list(modalities = list(), subjects = list(), tasks = list()))
              ))
            ),
            pageInfo = list(hasNextPage = FALSE)
          )
        )
      }
    },
    on_client = function() list(url = "https://openneuro.org/crn/graphql")
  )

  result <- .on_list_datasets(all = TRUE)
  expect_equal(call_count, 2)
  expect_equal(nrow(result), 2)
  expect_equal(result$id, c("ds000005", "ds000006"))
})

test_that("on_search without query uses list_datasets", {
  list_called <- FALSE

  local_mocked_bindings(
    .on_list_datasets = function(modality, limit, all, client) {
      list_called <<- TRUE
      tibble::tibble(
        id = "ds000007",
        name = "Test",
        created = as.POSIXct("2024-01-01", tz = "UTC"),
        public = TRUE,
        modalities = list(list()),
        n_subjects = 1L,
        tasks = list(list())
      )
    },
    on_client = function() list(url = "https://openneuro.org/crn/graphql")
  )

  result <- on_search(query = NULL, limit = 10)
  expect_true(list_called)
  expect_equal(result$id[1], "ds000007")
})
