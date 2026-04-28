import hashlib
import logging
import os
from typing import Optional, Tuple

logger = logging.getLogger(__name__)
PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "biasguard-42ac2")

_db = None

def _get_db():
    global _db
    if _db is None:
        from google.cloud import firestore
        _db = firestore.Client(project=PROJECT_ID)
    return _db


def download_and_hash_csv(bucket_name: str, storage_path: str) -> Tuple[bytes, str]:
    from google.cloud import storage as gcs
    client = gcs.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(storage_path)
    csv_bytes = blob.download_as_bytes()
    csv_hash = hashlib.sha256(csv_bytes).hexdigest()
    return csv_bytes, csv_hash


def get_cached_scan(uid: str, csv_hash: str) -> Optional[str]:
    try:
        doc = (_get_db().collection("users").document(uid)
               .collection("csv_cache").document(csv_hash).get())
        if doc.exists:
            return doc.to_dict().get("scan_id")
    except Exception as e:
        logger.warning(f"get_cached_scan failed: {e}")
    return None


def store_cache_entry(uid: str, csv_hash: str, scan_id: str) -> None:
    try:
        (_get_db().collection("users").document(uid)
         .collection("csv_cache").document(csv_hash)
         .set({"scan_id": scan_id}))
    except Exception as e:
        logger.warning(f"store_cache_entry failed: {e}")