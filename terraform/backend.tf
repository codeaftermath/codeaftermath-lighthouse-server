terraform {
  # The S3 backend region cannot be a variable — it must be a literal string.
  # Update this value to match the region where the bootstrap S3 bucket lives.
  backend "s3" {
    bucket       = "codeaftermath-terraform-state"
    key          = "lighthouse-server/terraform.tfstate"
    region       = "us-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
