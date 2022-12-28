output "base_url" {
  value = "${aws_api_gateway_stage.test.invoke_url}${aws_api_gateway_resource.proxypred.path}"
}