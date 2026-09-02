"""Rate limiting configuration built on slowapi.

Limits are applied to sensitive/unauthenticated high-traffic endpoints to
mitigate brute-force, credential-stuffing and abuse. The limiter is only
enabled in non-test environments so the pytest suite is unaffected.
"""
import os

from slowapi import Limiter
from slowapi.util import get_remote_address

_DEV_ENVIRONMENTS = {"development", "dev", "local", "test", "testing"}
_TEST_ENVIRONMENTS = {"test", "testing"}

_ENV = os.getenv("ENVIRONMENT", "development").strip().lower()
_is_test = _ENV in _TEST_ENVIRONMENTS

limiter = Limiter(key_func=get_remote_address, enabled=not _is_test)
