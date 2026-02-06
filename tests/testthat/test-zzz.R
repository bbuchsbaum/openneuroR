# Tests for zzz.R - package load hooks

test_that(".onLoad sets openneuro.version option if missing", {
  withr::local_options(openneuro.version = NULL)

  options(openneuro.version = NULL)
  expect_null(getOption("openneuro.version"))

  openneuro:::`.onLoad`(libname = "", pkgname = "openneuro")

  expect_s3_class(getOption("openneuro.version"), "package_version")
})

test_that(".onLoad does not override openneuro.version if already set", {
  withr::local_options(openneuro.version = as.package_version("0.0.0"))
  openneuro:::`.onLoad`(libname = "", pkgname = "openneuro")
  expect_equal(getOption("openneuro.version"), as.package_version("0.0.0"))
})

