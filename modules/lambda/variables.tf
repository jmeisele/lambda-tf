variable "func_name" {
  type        = string
  description = "Lambda Function Name"
}

variable "ecr_name" {
  type        = string
  description = "Name of ECR repository"
  default     = "davinci_ecr"
}

variable "ecr_image_tag" {
  type        = string
  description = "Name of Image tagged in ECR"
}

variable "access_to_dynamo_db" {
  type        = bool
  description = "True or False if access needed to DynamoDB"
  default     = false
}

variable "dynamo_db_table_name" {
  type        = string
  description = "DyanmoDB table name Lambda func needs access to"
  default     = null
}