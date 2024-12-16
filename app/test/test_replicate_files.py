import os
import pytest
from unittest.mock import patch, MagicMock

# Import the Lambda function
from app.replicate_files import handler

# Mock environment variables
os.environ["SOURCE_BUCKET"] = "source-bucket"
os.environ["DESTINATION_BUCKET"] = "destination-bucket"

# Mock event for testing
mock_event = {
    "detail": {
        "object": [{"key": "users.json"}, {"key": "irrelevant-file.json"}]
    }
}

@patch("app.replicate_files.s3_client")
def test_handler_success(mock_s3_client):
    # Mock S3 copy_object method
    mock_s3_client.copy_object = MagicMock()

    # Call the handler
    handler(mock_event, None)

    # Assert copy_object was called for users.json
    mock_s3_client.copy_object.assert_called_once_with(
        Bucket="destination-bucket",
        CopySource={"Bucket": "source-bucket", "Key": "users.json"},
        Key="users.json"
    )

def test_handler_skips_irrelevant_files():
    # Mock S3 client to avoid real AWS interaction
    with patch("app.replicate_files.s3_client") as mock_s3_client:
        mock_s3_client.copy_object = MagicMock()

        # Call the handler
        handler(mock_event, None)

        # Assert copy_object was called only once for users.json
        assert mock_s3_client.copy_object.call_count == 1
