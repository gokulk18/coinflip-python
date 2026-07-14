output "invoke_url" {
  description = "Base invoke URL of the API Gateway HTTP API. Append /flip to reach the coin-flip endpoint."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "flip_endpoint" {
  description = "Full URL of the coin-flip endpoint. Paste this into frontend/app.js as API_URL."
  value       = "${aws_apigatewayv2_stage.default.invoke_url}flip"
}

output "lambda_function_name" {
  description = "Name of the deployed Lambda function."
  value       = aws_lambda_function.flip_coin.function_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group where Lambda execution logs are written."
  value       = aws_cloudwatch_log_group.lambda_logs.name
}
