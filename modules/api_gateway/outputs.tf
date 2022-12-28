output "base_url" {
  value = "${aws_api_gateway_stage.stage.invoke_url}${aws_api_gateway_resource.proxy_pred.path}"
}