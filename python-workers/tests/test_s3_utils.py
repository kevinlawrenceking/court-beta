"""Tests for S3 utility functions."""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from s3_utils import DOCUMENTS_BUCKET, UPLOADS_BUCKET


class TestS3Config:
    def test_default_bucket_names(self):
        # These should have sensible defaults even without env vars
        assert isinstance(DOCUMENTS_BUCKET, str)
        assert isinstance(UPLOADS_BUCKET, str)
        assert len(DOCUMENTS_BUCKET) > 0
        assert len(UPLOADS_BUCKET) > 0
