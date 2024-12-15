import email
import json

import boto3
import requests


def lambda_handler(event, context):
    # Get the message ID for the email
    message_id = event["Records"][0]["ses"]["mail"]["messageId"]

    # Retrieve the email content from S3 if configured to store
    s3_client = boto3.client("s3")
    bucket_name = "newsblur-email-logs"
    email_data = s3_client.get_object(Bucket=bucket_name, Key=message_id)
    raw_email = email_data["Body"].read().decode("utf-8")

    # Parse the raw email
    parsed_email = email.message_from_string(raw_email)

    # Prepare the payload for the webhook
    # Include original recipient
    payload = {
        "from": parsed_email["From"],
        "to": parsed_email["To"],
        "subject": parsed_email["Subject"],
        "body": parsed_email.get_payload(),
        "original_recipient": parsed_email["X-Original-Recipient"],
    }

    # Send to webhook
    webhook_url = "https://push.newsblur.com/newsletters/receive/"
    response = requests.post(webhook_url, json=payload)

    return {"statusCode": response.status_code, "body": json.dumps("Email forwarded to webhook")}
