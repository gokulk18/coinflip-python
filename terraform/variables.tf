variable "aws_region" {
  description = "AWS region to deploy the Coin Flip serverless app into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix all created resources."
  type        = string
  default     = "coin-flip"
}

variable "lambda_runtime" {
  description = "Lambda runtime for the coin flip function."
  type        = string
  default     = "python3.12"
}

variable "log_retention_days" {
  description = "How many days to retain CloudWatch logs for the Lambda function."
  type        = number
  default     = 7
}
