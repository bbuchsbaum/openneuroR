# Check that the AWS CLI Actually Runs

A binary named `aws` on the PATH is not sufficient: broken installations
(for example a Python entry point whose `awscli` module is missing) are
present but non-functional. This invokes `aws --version` and reports
success only when the command exits cleanly, so backend auto-selection
never picks an S3 backend that cannot run.

## Usage

``` r
.aws_cli_works(aws_path)
```

## Arguments

- aws_path:

  Path to the AWS CLI executable.

## Value

Logical: TRUE if `aws --version` exits with status 0, else FALSE.
