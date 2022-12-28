output "name" {
  description = "Lambda Func Name"
  value       = aws_lambda_function.lambda_func.function_name
}

output "invoke_arn" {
  value = aws_lambda_function.lambda_func.invoke_arn
}