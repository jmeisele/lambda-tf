output "invoke_arn" {
  value = aws_lambda_function.lambda_func.invoke_arn
}

output "name" {
  value = aws_lambda_function.lambda_func.name
}
