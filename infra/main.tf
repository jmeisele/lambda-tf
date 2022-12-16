terraform {
  required_version = "~> 1.0"
  cloud {
    hostname     = "app.terraform.io"
    organization = "davinci"
    workspaces {
      name = "lambda-tf"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
}

provider "aws" {
  allowed_account_ids     = [var.account_id]
  access_key              = var.access_key
  secret_key              = var.secret_key
  region                  = var.region
  skip_metadata_api_check = true
}


resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# IAM policy for logging from a lambda and getting our image from ECR
resource "aws_iam_policy" "iam_policy_for_lambda" {
  name        = "aws_iam_policy_for_terraform_aws_lambda_role"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": "ecr:BatchGetImage",
      "Resource": "arn:aws:ecr:us-east-1:803475916935:melkor_lambda_ecr/*"
    }
  ]
}
EOF
}

# Policy Attachment on the role.
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}

resource "aws_ecr_repository" "ecr" {
  name                 = var.ecr_name
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository_policy" "ecr_policy" {
  repository = aws_ecr_repository.ecr.name
  policy     = <<EOF
  {
    "Version": "2008-10-17",
    "Statement": [
      {
        "Sid": "Adds access to push and pull images",
        "Effect": "Allow",
        "Principal": "*",
        "Action": [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetLifecyclePolicy",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
      }
    ]
  }
  EOF
}

data "aws_ecr_repository" "repository" {
  name = aws_ecr_repository.ecr.name
}

data "aws_ecr_image" "image" {
  repository_name = aws_ecr_repository.ecr.name
  image_tag       = var.image_tag
}

# Create a lambda function from the image we uploaded to ECR
resource "aws_lambda_function" "terraform_lambda_func" {
  function_name = var.lambda_func_name
  role          = aws_iam_role.iam_for_lambda.arn
  image_uri     = "${data.aws_ecr_repository.repository.repository_url}@${data.aws_ecr_image.image.image_digest}"
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
  package_type  = "Image"
}

# Lambda Invoke & Event Source Mapping
resource "aws_api_gateway_rest_api" "lambda-api" {
  name = "serverless_lambda_gw"
}

resource "aws_api_gateway_resource" "proxypred" {
  rest_api_id = aws_api_gateway_rest_api.lambda-api.id
  parent_id   = aws_api_gateway_rest_api.lambda-api.root_resource_id
  path_part   = "classify"
}

resource "aws_api_gateway_method" "methodproxy" {
  rest_api_id   = aws_api_gateway_rest_api.lambda-api.id
  resource_id   = aws_api_gateway_resource.proxypred.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "apilambda" {
  rest_api_id = aws_api_gateway_rest_api.lambda-api.id
  resource_id = aws_api_gateway_method.methodproxy.resource_id
  http_method = aws_api_gateway_method.methodproxy.http_method

  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.terraform_lambda_func.invoke_arn
  timeout_milliseconds    = 29000
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.lambda-api.id
  resource_id = aws_api_gateway_resource.proxypred.id
  http_method = aws_api_gateway_method.methodproxy.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "MyDemoIntegrationResponse" {
  rest_api_id = aws_api_gateway_rest_api.lambda-api.id
  resource_id = aws_api_gateway_resource.proxypred.id
  http_method = aws_api_gateway_method.methodproxy.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  depends_on = [
    aws_api_gateway_integration.apilambda
  ]
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAnyWhere"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.terraform_lambda_func.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${var.account_id}:${aws_api_gateway_rest_api.lambda-api.id}/*/${aws_api_gateway_method.methodproxy.http_method}${aws_api_gateway_resource.proxypred.path}"
}

resource "aws_api_gateway_deployment" "apideploy" {
  depends_on = [
    aws_api_gateway_integration.apilambda
  ]
  rest_api_id = aws_api_gateway_rest_api.lambda-api.id
  triggers = {
    redeployment = aws_api_gateway_resource.proxypred.path
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "test" {
  deployment_id = aws_api_gateway_deployment.apideploy.id
  rest_api_id   = aws_api_gateway_rest_api.lambda-api.id
  stage_name    = "testing"
}

# IAM for API
resource "aws_api_gateway_rest_api_policy" "api_allow_invoke" {
  rest_api_id = aws_api_gateway_rest_api.lambda-api.id

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
        "arn:aws:execute-api:${var.region}:${var.account_id}:${aws_api_gateway_rest_api.lambda-api.id}/*/${aws_api_gateway_method.methodproxy.http_method}${aws_api_gateway_resource.proxypred.path}"
      ]
    }
  ]
}
EOF
}

output "base_url" {
  value = "${aws_api_gateway_stage.test.invoke_url}${aws_api_gateway_resource.proxypred.path}"
}