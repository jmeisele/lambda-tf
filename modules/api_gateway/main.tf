resource "aws_api_gateway_rest_api" "lambda_api" {
  name = var.name
}

resource "aws_api_gateway_resource" "proxy_pred" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  parent_id   = aws_api_gateway_rest_api.lambda_api.root_resource_id
  path_part   = var.endpoint
  #   request_paremeters = {
  #   }
}

resource "aws_api_gateway_method" "method_proxy" {
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  resource_id   = aws_api_gateway_resource.proxy_pred.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_lambda" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_method.method_proxy.resource_id
  http_method = aws_api_gateway_method.method_proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.terraform_lambda_func.invoke_arn
  timeout_milliseconds    = 29000
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.proxy_pred.id
  http_method = aws_api_gateway_method.method_proxy.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "MyDemoIntegrationResponse" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.proxy_pred.id
  http_method = aws_api_gateway_method.method_proxy.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  depends_on = [
    aws_api_gateway_integration.api_lambda
  ]
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id = "AllowExecutionFromAnyWhere"
  action       = "lambda:InvokeFunction"
  # function_name = aws_lambda_function.terraform_lambda_func.function_name
  function_name = var.lambda_func_name
  principal     = "apigateway.amazonaws.com"

  #   # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${var.account_id}:${aws_api_gateway_rest_api.lambda_api.id}/*/${aws_api_gateway_method.method_proxy.http_method}${aws_api_gateway_resource.proxy_pred.path}"
}

# resource "aws_api_gateway_deployment" "api_deploy" {
#   depends_on = [
#     aws_api_gateway_integration.api_lambda
#   ]
#   rest_api_id = aws_api_gateway_rest_api.lambda_api.id
#   triggers = {
#     redeployment = aws_api_gateway_resource.proxy_pred.path
#   }
#   lifecycle {
#     create_before_destroy = true
#   }
# }

resource "aws_api_gateway_deployment" "api_deploy" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy_pred.path,
      aws_api_gateway_method.method_proxy.id,
      aws_api_gateway_integration.api_lambda.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.api_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  stage_name    = var.stage_name
}

# # IAM for API
resource "aws_api_gateway_rest_api_policy" "api_allow_invoke" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "execute-api:Invoke"
      ],
      "Resource": [
        "arn:aws:execute-api:${var.region}:${var.account_id}:${aws_api_gateway_rest_api.lambda_api.id}/*/${aws_api_gateway_method.method_proxy.http_method}${aws_api_gateway_resource.proxy_pred.path}"
      ]
    }
  ]
}
EOF
}