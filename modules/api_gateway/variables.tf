variable "name" {
  type        = string
  description = "Name of API Gateway"
}

variable "lambda_func_name" {
  type        = string
  description = "Name of Lambda Func"
}

variable "stage_name" {
  type        = string
  description = "Name of API Gateway stage"
}

variable "account_id" {
  type        = number
  description = "AWS Account ID"
  default     = 288195736164
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "endpoint" {
  type        = string
  description = "API Gateway Endpoint"
}