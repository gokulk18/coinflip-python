locals {
  lambda_source_path = "${path.module}/../backend/lambda_function.py"
  lambda_zip_path    = "${path.module}/build/lambda_function.zip"
}

resource "terraform_data" "lambda_zip" {
  triggers_replace = {
    source_hash = filemd5(local.lambda_source_path)
  }

  provisioner "local-exec" {
    interpreter = ["python", "-c"]
    command     = <<-EOT
      import os, zipfile
      os.makedirs(os.path.dirname(r"${local.lambda_zip_path}"), exist_ok=True)
      with zipfile.ZipFile(r"${local.lambda_zip_path}", "w", zipfile.ZIP_DEFLATED) as zf:
          zf.write(r"${local.lambda_source_path}", arcname="lambda_function.py")
    EOT
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-flip-coin"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "flip_coin" {
  function_name = "${var.project_name}-flip-coin"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime

  filename         = local.lambda_zip_path
  source_code_hash = filebase64sha256(local.lambda_source_path)

  timeout = 5

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_basic_execution,
    terraform_data.lambda_zip,
  ]
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.flip_coin.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "flip_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /flip"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.flip_coin.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
