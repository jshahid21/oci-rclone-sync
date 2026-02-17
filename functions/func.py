"""
OCI-to-AWS Firehose Function
Streams files from OCI Object Storage to AWS S3 upon creation.
Uses Resource Principals and zero-disk streaming (boto3.upload_fileobj).
"""

import base64
import io
import json
import logging
import os
from typing import Any, Tuple

import oci
from fdk import response

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables (injected by Terraform)
OCI_SOURCE_NAMESPACE = os.environ.get("OCI_SOURCE_NAMESPACE", "")
OCI_SOURCE_BUCKET = os.environ.get("OCI_SOURCE_BUCKET", "")
AWS_S3_BUCKET = os.environ.get("AWS_S3_BUCKET", "")
AWS_S3_PREFIX = os.environ.get("AWS_S3_PREFIX", "")
AWS_REGION = os.environ.get("AWS_REGION", "")
AWS_ACCESS_KEY_SECRET_ID = os.environ.get("AWS_ACCESS_KEY_SECRET_ID", "")
AWS_SECRET_KEY_SECRET_ID = os.environ.get("AWS_SECRET_KEY_SECRET_ID", "")


def get_resource_principal_signer():
    """Obtain signer using OCI Resource Principals (Dynamic Group)."""
    try:
        signer = oci.auth.signers.get_resource_principals_signer()
        logger.info("Resource Principal signer obtained successfully")
        return signer
    except Exception as e:
        logger.error("Failed to obtain Resource Principal signer: %s", e)
        raise RuntimeError(f"Auth failed - ensure Dynamic Group is configured: {e}") from e


def get_aws_credentials(secrets_client: oci.secrets.SecretsClient) -> Tuple[str, str]:
    """Retrieve AWS credentials from OCI Vault at runtime."""
    if not AWS_ACCESS_KEY_SECRET_ID or not AWS_SECRET_KEY_SECRET_ID:
        raise ValueError("AWS_ACCESS_KEY_SECRET_ID and AWS_SECRET_KEY_SECRET_ID must be set")

    def get_secret_value(secret_id: str) -> str:
        get_secret_bundle_response = secrets_client.get_secret_bundle(
            secret_id=secret_id,
            stage="LATEST"
        )
        base64_content = get_secret_bundle_response.data.secret_bundle_content.content
        return base64.b64decode(base64_content).decode("utf-8")

    access_key = get_secret_value(AWS_ACCESS_KEY_SECRET_ID)
    secret_key = get_secret_value(AWS_SECRET_KEY_SECRET_ID)
    return access_key, secret_key


def stream_object_to_s3(
    object_storage_client: oci.object_storage.ObjectStorageClient,
    s3_client: Any,
    namespace: str,
    bucket: str,
    object_name: str,
    s3_bucket: str,
    s3_key: str,
) -> None:
    """
    Stream object from OCI to S3 without writing to disk.
    Uses get_object streaming response and boto3 upload_fileobj.
    """
    # Get object as streaming response (zero-disk: never downloads to function disk)
    get_object_response = object_storage_client.get_object(
        namespace_name=namespace,
        bucket_name=bucket,
        object_name=object_name,
    )

    # response.data is a stream (file-like with read())
    oci_stream = get_object_response.data

    # Stream directly to S3 via upload_fileobj
    # boto3.upload_fileobj accepts any file-like object
    s3_client.upload_fileobj(oci_stream, s3_bucket, s3_key)
    logger.info("Streamed %s -> s3://%s/%s", object_name, s3_bucket, s3_key)


def handler(ctx, data: io.BytesIO = None):
    """
    OCI Function entrypoint.
    Triggered by Events service on Object Create.
    """
    try:
        if data is None or data.getvalue() == b"":
            return response.Response(
                ctx,
                response_data=json.dumps({"error": "No event data received"}),
                status_code=400,
            )

        event = json.loads(data.getvalue())
        logger.info("Received event: %s", json.dumps(event, default=str)[:500])

        # Parse OCI Events payload for Object Create
        # Format: data.additionalDetails.{namespace, bucketName, objectName}
        data_obj = event.get("data", {})
        additional = data_obj.get("additionalDetails", {})

        namespace = additional.get("namespace") or OCI_SOURCE_NAMESPACE
        bucket = additional.get("bucketName") or OCI_SOURCE_BUCKET
        object_name = additional.get("objectName", "")

        if not object_name:
            return response.Response(
                ctx,
                response_data=json.dumps({"error": "No object name in event"}),
                status_code=400,
            )

        if not namespace or not bucket:
            return response.Response(
                ctx,
                response_data=json.dumps({
                    "error": "Missing namespace or bucket",
                    "namespace": namespace,
                    "bucket": bucket,
                }),
                status_code=400,
            )

        # S3 key: optional prefix + object name (preserve path)
        s3_key = f"{AWS_S3_PREFIX.rstrip('/')}/{object_name}" if AWS_S3_PREFIX else object_name

        # Auth: Resource Principals
        signer = get_resource_principal_signer()

        # OCI Clients
        object_storage_client = oci.object_storage.ObjectStorageClient(config={}, signer=signer)
        secrets_client = oci.secrets.SecretsClient(config={}, signer=signer)

        # AWS credentials from OCI Vault
        aws_access_key, aws_secret_key = get_aws_credentials(secrets_client)

        # boto3 S3 client
        import boto3
        session = boto3.Session(
            aws_access_key_id=aws_access_key,
            aws_secret_access_key=aws_secret_key,
            region_name=AWS_REGION,
        )
        s3_client = session.client("s3")

        # Stream OCI -> S3 (zero-disk)
        stream_object_to_s3(
            object_storage_client=object_storage_client,
            s3_client=s3_client,
            namespace=namespace,
            bucket=bucket,
            object_name=object_name,
            s3_bucket=AWS_S3_BUCKET,
            s3_key=s3_key,
        )

        return response.Response(
            ctx,
            response_data=json.dumps({
                "status": "success",
                "object": object_name,
                "s3_key": s3_key,
            }),
            status_code=200,
        )

    except json.JSONDecodeError as e:
        logger.exception("Invalid JSON in event")
        return response.Response(
            ctx,
            response_data=json.dumps({"error": f"Invalid JSON: {e}"}),
            status_code=400,
        )
    except ValueError as e:
        logger.exception("Configuration error: %s", e)
        return response.Response(
            ctx,
            response_data=json.dumps({"error": str(e)}),
            status_code=500,
        )
    except RuntimeError as e:
        logger.exception("Auth error: %s", e)
        return response.Response(
            ctx,
            response_data=json.dumps({"error": str(e)}),
            status_code=503,
        )
    except Exception as e:
        logger.exception("Unhandled error: %s", e)
        return response.Response(
            ctx,
            response_data=json.dumps({"error": str(e)}),
            status_code=500,
        )
