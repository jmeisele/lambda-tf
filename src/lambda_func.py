import json
import logging
from typing import Any, Dict

format = "%(asctime)s %(levelname)s - %(message)s"
logging.basicConfig(level=logging.DEBUG, format=format, force=True)
logger = logging.getLogger()


def lambda_handler(event, context) -> Dict[str, Any]:
    logger.info("Event: {}".format(event))
    logger.info("Context: {}".format(context))
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps("Hello from Docker in lambda 🐋"),
    }
