# Tests for backend detection and dispatch
# Uses local_mocked_bindings() to avoid CLI invocations

test_that(".backend_available detects missing AWS CLI", {
  local_mocked_bindings(
    .find_aws_cli = function() ""
  )
  expect_false(.backend_available("s3"))
})

test_that(".backend_available detects present AWS CLI", {
  local_mocked_bindings(
    .find_aws_cli = function() "/usr/local/bin/aws"
  )
  expect_true(.backend_available("s3"))
})

test_that(".backend_available detects missing DataLad", {
  local_mocked_bindings(
    .sys_which = function(names) {
      setNames("", names)
    }
  )
  expect_false(.backend_available("datalad"))
})

test_that(".backend_available detects present DataLad", {
  local_mocked_bindings(
    .sys_which = function(names) {
      if (names == "datalad") return(setNames("/usr/bin/datalad", names))
      if (names == "git-annex") return(setNames("/usr/bin/git-annex", names))
      setNames("", names)
    }
  )
  expect_true(.backend_available("datalad"))
})

test_that(".backend_available requires both datalad and git-annex", {
  # DataLad without git-annex should fail
  local_mocked_bindings(
    .sys_which = function(names) {
      if (names == "datalad") return(setNames("/usr/bin/datalad", names))
      setNames("", names)  # git-annex missing
    }
  )
  expect_false(.backend_available("datalad"))
})

test_that(".backend_available always returns TRUE for https", {
  expect_true(.backend_available("https"))
})

test_that(".backend_available returns FALSE for unknown backend", {
  expect_false(.backend_available("unknown"))
})

test_that(".select_backend returns https when nothing else available", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) backend == "https"
  )
  expect_equal(.select_backend(), "https")
})

test_that(".select_backend respects priority when all available", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) TRUE
  )
  expect_equal(.select_backend(), "datalad")  # Highest priority
})

test_that(".select_backend returns s3 when datalad unavailable", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) {
      backend %in% c("s3", "https")
    }
  )
  expect_equal(.select_backend(), "s3")
})

test_that(".select_backend returns preferred backend if available", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) TRUE
  )
  expect_equal(.select_backend(preferred = "s3"), "s3")
  expect_equal(.select_backend(preferred = "https"), "https")
})

test_that(".select_backend falls back when preferred unavailable", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) {
      backend %in% c("s3", "https")
    }
  )
  # Request datalad but it's unavailable - should fall back
  expect_warning(
    result <- .select_backend(preferred = "datalad"),
    "not available"
  )
  expect_equal(result, "s3")
})

test_that(".select_backend warns on unknown backend", {
  local_mocked_bindings(
    .backend_status = function(backend, refresh = FALSE) backend == "https"
  )
  expect_warning(
    result <- .select_backend(preferred = "invalid"),
    "not recognized"
  )
  expect_equal(result, "https")
})
