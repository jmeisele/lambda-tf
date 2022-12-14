import json

from src.lambda_func import lambda_handler


def test_lambda_handler() -> None:
    """Test Case for lambda_func"""
    event = "foo"
    context = "bar"
    response = lambda_handler(event, context)
    assert response["statusCode"] == 200
    assert json.loads(response["body"]) == "Hello from Docker in lambda 🐋"
