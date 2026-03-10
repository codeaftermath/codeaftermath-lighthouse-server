terraform {
  backend "s3" {
    bucket       = "codeaftermath-terraform-state"
    key          = "lighthouse-server/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
