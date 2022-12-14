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
  allowed_account_ids     = [288195736164]
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