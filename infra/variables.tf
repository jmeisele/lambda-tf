variable "access_key" {
  type = string
}

variable "secret_key" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "image_tag" {
  type = string
}

variable "lambda_func_name" {
  type = string
}

variable "ecr_name" {
  type = string
}

variable "account_id" {
  type        = number
  description = "AWS Account ID"
  default     = 288195736164
}