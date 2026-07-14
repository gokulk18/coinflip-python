terraform {
  backend "s3" {
    bucket       = "coin-flip-terraform-state-902664897239"
    key          = "coin-flip-serverless/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
