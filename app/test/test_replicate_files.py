import unittest
from unittest.mock import patch, MagicMock
import os
from replicate_files import handler, replicate_file

@patch.dict(os.environ, {
    "SOURCE_BUCKET": "test-source-bucket",
    "DESTINATION_BUCKET": "test-destination-bucket",
    "DESTINATION_PREFIX": "assets/"
})
class TestLambdaHandler(unittest.TestCase):

    @patch("replicate_files.s3_client")
    def test_replicate_file_success(self, mock_s3_client):
        replicate_file("test-source-bucket", "test-destination-bucket", "test-key.json")
        mock_s3_client.copy_object.assert_called_once_with(
            CopySource={"Bucket": "test-source-bucket", "Key": "test-key.json"},
            Bucket="test-destination-bucket",
            Key="assets/test-key.json"
        )

    @patch("replicate_files.s3_client")
    def test_handler_replicates_on_update(self, mock_s3_client):
        mock_s3_client.copy_object.return_value = None

        event = {
            "Records": [
                {
                    "eventName": "ObjectCreated:Put",
                    "s3": {
                        "bucket": {"name": "test-source-bucket"},
                        "object": {"key": "test-key.json"}
                    }
                }
            ]
        }

        handler(event, None)

        mock_s3_client.copy_object.assert_called_once_with(
            CopySource={"Bucket": "test-source-bucket", "Key": "test-key.json"},
            Bucket="test-destination-bucket",
            Key="assets/test-key.json"
        )

    @patch("replicate_files.s3_client")
    def test_handler_restores_deleted_file(self, mock_s3_client):
        mock_s3_client.copy_object.return_value = None

        event = {
            "Records": [
                {
                    "eventName": "ObjectRemoved:Delete",
                    "s3": {
                        "bucket": {"name": "test-destination-bucket"},
                        "object": {"key": "test-key.json"}
                    }
                }
            ]
        }

        handler(event, None)

        mock_s3_client.copy_object.assert_called_once_with(
            CopySource={"Bucket": "test-source-bucket", "Key": "test-key.json"},
            Bucket="test-destination-bucket",
            Key="assets/test-key.json"
        )

    @patch("replicate_files.s3_client")
    def test_handler_ignores_non_related_events(self, mock_s3_client):
        event = {
            "Records": [
                {
                    "eventName": "ObjectCreated:Put",
                    "s3": {
                        "bucket": {"name": "unrelated-bucket"},
                        "object": {"key": "test-key.json"}
                    }
                }
            ]
        }

        handler(event, None)
        mock_s3_client.copy_object.assert_not_called()

if __name__ == "__main__":
    unittest.main()
