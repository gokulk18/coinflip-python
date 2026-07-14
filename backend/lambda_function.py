"""
AWS Lambda handler for the Coin Flip demo.

This is intentionally a *plain* Lambda function with no web framework
(no FastAPI/Flask/Django) and no adapter (no Mangum). API Gateway (HTTP API,
payload format 2.0) invokes `lambda_handler` directly with an event dict, and
whatever this function returns is converted straight back into an HTTP
response for the browser.

Learning goal: see the raw shape of the API Gateway <-> Lambda contract
without a framework hiding it from you.
"""

import json
import logging
import random
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
}


def _response(status_code: int, body: dict) -> dict:
    """Build the dict shape API Gateway (HTTP API) expects back from Lambda."""
    return {
        "statusCode": status_code,
        "headers": CORS_HEADERS,
        "body": json.dumps(body),
    }


def lambda_handler(event, context):
    """
    Entry point configured in Terraform as the Lambda's handler
    (backend/lambda_function.lambda_handler).

    Flips a virtual coin and returns the result as JSON. Every invocation
    is logged so the full request lifecycle is visible in CloudWatch Logs.
    """
    request_id = getattr(context, "aws_request_id", "unknown")
    start_time = time.time()

    logger.info("Incoming event: %s", json.dumps(event))
    logger.info("Request ID: %s | Timestamp: %s", request_id, time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))

    try:
        # API Gateway sends an OPTIONS preflight before the actual GET when
        # CORS is involved; respond with an empty 200 so the browser proceeds.
        http_method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
        if http_method == "OPTIONS":
            return _response(200, {"message": "CORS preflight OK"})

        result = random.choice(["Heads", "Tails"])
        message = f"The coin landed on {result}."

        logger.info("Generated result: %s", result)

        body = {"result": result, "message": message}

        duration_ms = round((time.time() - start_time) * 1000, 2)
        logger.info("Execution completed | Request ID: %s | Duration: %sms", request_id, duration_ms)

        return _response(200, body)

    except Exception:
        logger.exception("Unhandled error while processing request | Request ID: %s", request_id)
        return _response(500, {"error": "Internal server error", "message": "Something went wrong while flipping the coin."})
