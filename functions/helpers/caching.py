"""
BiasGuard — Dataset Caching Module
Caches Firestore results by SHA-256 hash of the uploaded CSV content.
If the same dataset is uploaded again, returns the cached scan_id
instead of re-running all Cloud Functions.
This saves: Gemini API cost, Cloud Function compute time, and user wait time.
"""

import hashlib
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

from google.cloud import firestore

logger = logging.getLogger(__name__)

db = firestore.Client(project="biasguard-42ac2")

# Cache TTL — cached results expire after 7 days
CACHE_TTL_DAYS = 7


def compute_csv_hash(csv_bytes: bytes) -> str:
    """Compute SHA-256 hash of raw CSV bytes."""
    return hashlib.sha256(csv_bytes).hexdigest()


def get_cached_scan(uid: str, csv_hash: str) -> Optional[str]:
    """
    Check if a scan result exists for this CSV hash (for this user).
    Returns the cached scan_id if found and not expired, else None.
    """
    try:
        cache_ref = (db.collection("users").document(uid)
                       .collection("cache").document(csv_hash))
        doc = cache_ref.get()

        if not doc.exists:
            return None

        data = doc.to_dict()
        cached_at = data.get("cached_at")

        # Check TTL
        if cached_at:
            age = datetime.now(timezone.utc) - cached_at
            if age > timedelta(days=CACHE_TTL_DAYS):
                logger.info(f"Cache expired for hash {csv_hash[:12]}…")
                cache_ref.delete()
                return None

        scan_id = data.get("scan_id")
        logger.info(f"Cache HIT for hash {csv_hash[:12]}… → scan_id={scan_id}")
        return scan_id

    except Exception as e:
        logger.warning(f"Cache lookup failed (non-fatal): {e}")
        return None


def store_cache_entry(uid: str, csv_hash: str, scan_id: str):
    """
    Store a cache entry mapping csv_hash → scan_id for this user.
    """
    try:
        cache_ref = (db.collection("users").document(uid)
                       .collection("cache").document(csv_hash))
        cache_ref.set({
            "scan_id": scan_id,
            "cached_at": datetime.now(timezone.utc),
            "csv_hash": csv_hash,
        })
        logger.info(f"Cache STORED for hash {csv_hash[:12]}… → scan_id={scan_id}")
    except Exception as e:
        logger.warning(f"Cache store failed (non-fatal): {e}")


def invalidate_cache(uid: str, csv_hash: str):
    """Force-delete a cache entry (used when user re-uploads for fresh analysis)."""
    try:
        (db.collection("users").document(uid)
           .collection("cache").document(csv_hash).delete())
    except Exception as e:
        logger.warning(f"Cache invalidation failed (non-fatal): {e}")


def download_and_hash_csv(bucket_name: str, blob_path: str) -> tuple[bytes, str]:
    """
    Download CSV bytes from Storage and return (bytes, sha256_hash).
    Used in CF1 before parsing, so we can do cache lookup early.
    """
    from google.cloud import storage as gcs
    client = gcs.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(blob_path)
    csv_bytes = blob.download_as_bytes()
    csv_hash = compute_csv_hash(csv_bytes)
    return csv_bytes, csv_hash
