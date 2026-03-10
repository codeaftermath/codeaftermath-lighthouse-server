terraform {
  backend "s3" {
    bucket         = "codeaftermath-terraform-state"
    key            = "lighthouse-server/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "codeaftermath-terraform-locks"
    encrypt        = true
  }
}
