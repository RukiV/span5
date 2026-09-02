"""Security feature tests — password hashing, lockout, revocation, reset, encryption, headers."""

import hashlib
import os
import time
from datetime import datetime, timedelta

os.environ["ENCRYPTION_KEY"] = "test-key-encryption-123456"

import pytest
from sqlmodel import Session, select

from app.auth.security import (
    hash_password, verify_password, is_hashed,
    validate_password_strength,
    PasswordTooShort, PasswordMissingLowercase,
    PasswordMissingUppercase, PasswordMissingDigit, PasswordMissingSpecial,
)
from app.auth.crypto import encrypt_value, decrypt_value
from app.auth.session import create_session_token, verify_session_token, create_refresh_token
from app.models.user import User
from app.models.password_reset import PasswordResetToken


# ── Password Hashing ────────────────────────────────────────────

def test_bcrypt_hash_produces_bcrypt_prefix():
    h = hash_password("Strong@123")
    assert h.startswith("$2b$") or h.startswith("$2a$")

def test_is_hashed_recognises_bcrypt():
    h = hash_password("Strong@123")
    assert is_hashed(h)

def test_verify_correct_password_succeeds():
    h = hash_password("Strong@123")
    assert verify_password("Strong@123", h) is True

def test_verify_wrong_password_fails():
    h = hash_password("Strong@123")
    assert verify_password("WrongPass1!", h) is False


# ── Password Complexity ─────────────────────────────────────────

class TestPasswordComplexity:
    def test_too_short(self):
        with pytest.raises(PasswordTooShort):
            validate_password_strength("Ab1!x")

    def test_missing_lowercase(self):
        with pytest.raises(PasswordMissingLowercase):
            validate_password_strength("ABCDEF@1")

    def test_missing_uppercase(self):
        with pytest.raises(PasswordMissingUppercase):
            validate_password_strength("abcdef@1")

    def test_missing_digit(self):
        with pytest.raises(PasswordMissingDigit):
            validate_password_strength("Abcdefg@")

    def test_missing_special(self):
        with pytest.raises(PasswordMissingSpecial):
            validate_password_strength("Abcdefg1")

    def test_strong_password_passes(self):
        validate_password_strength("Strong@123")


# ── Account Lockout ─────────────────────────────────────────────

class TestAccountLockout:
    def test_5_failed_logins_returns_429(self, client, seeded):
        email = seeded["emails"]["fk"]
        for _ in range(5):
            client.post("/api/v1/auth/login", json={
                "user_email": email, "user_password": "wrongpass1!",
            })
        resp = client.post("/api/v1/auth/login", json={
            "user_email": email, "user_password": "wrongagain1!",
        })
        assert resp.status_code == 429
        assert "locked" in resp.json()["detail"].lower()

    def test_correct_password_resets_lockout_counter(self, client, seeded):
        email, pw = seeded["emails"]["fk"], seeded["passwords"]["fk"]
        for _ in range(3):
            client.post("/api/v1/auth/login", json={
                "user_email": email, "user_password": "wrongpass1!",
            })
        resp = client.post("/api/v1/auth/login", json={
            "user_email": email, "user_password": pw,
        })
        assert resp.status_code == 200
        # Now one wrong attempt — should NOT lock (counter was reset)
        resp2 = client.post("/api/v1/auth/login", json={
            "user_email": email, "user_password": "wrongpass1!",
        })
        assert resp2.status_code == 401


# ── Session Revocation ──────────────────────────────────────────

class TestSessionRevocation:
    def test_logout_revokes_token(self, client, seeded):
        email, pw = seeded["emails"]["admin"], seeded["passwords"]["admin"]
        login_resp = client.post("/api/v1/auth/login", json={
            "user_email": email, "user_password": pw,
        })
        token = login_resp.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}", "X-Client-Type": "web"}

        logout_resp = client.post("/api/v1/auth/logout", headers=headers)
        assert logout_resp.status_code == 200

        reuse_resp = client.get("/api/v1/assets", headers=headers)
        assert reuse_resp.status_code == 401


# ── Refresh Token Rotation ──────────────────────────────────────

class TestRefreshRotation:
    def test_refresh_returns_new_token_pair(self, client, seeded):
        email, pw = seeded["emails"]["admin"], seeded["passwords"]["admin"]
        login_resp = client.post("/api/v1/auth/login", json={
            "user_email": email, "user_password": pw,
        })
        refresh_token = login_resp.json()["refresh_token"]
        headers = {"Authorization": f"Bearer {refresh_token}"}

        resp = client.post("/api/v1/auth/refresh", headers=headers)
        assert resp.status_code == 200
        assert "access_token" in resp.json()
        assert "refresh_token" in resp.json()

    def test_old_refresh_rejected_after_use(self, client, seeded):
        email, pw = seeded["emails"]["admin"], seeded["passwords"]["admin"]
        login_resp = client.post("/api/v1/auth/login", json={
            "user_email": email, "user_password": pw,
        })
        old_refresh = login_resp.json()["refresh_token"]

        client.post("/api/v1/auth/refresh",
                     headers={"Authorization": f"Bearer {old_refresh}"})
        resp2 = client.post("/api/v1/auth/refresh",
                             headers={"Authorization": f"Bearer {old_refresh}"})
        assert resp2.status_code == 401


# ── Password Reset ──────────────────────────────────────────────

class TestPasswordReset:
    def test_forgot_password_returns_200(self, client, seeded):
        resp = client.post("/api/v1/auth/forgot-password", json={
            "user_email": seeded["emails"]["fk"],
        })
        assert resp.status_code == 200

    def test_forgot_password_unknown_email_returns_200(self, client):
        resp = client.post("/api/v1/auth/forgot-password", json={
            "user_email": "nobody@nowhere.test",
        })
        assert resp.status_code == 200

    def test_reset_password_full_cycle(self, client, seeded, engine, monkeypatch):
        email = seeded["emails"]["fk"]
        raw_token = "known-raw-reset-token"
        # The endpoint never stores the raw token (only its SHA-256 hash), so pin
        # the RNG to make the full cycle deterministic.
        monkeypatch.setattr(
            "app.api.v1.endpoints.auth.secrets.token_urlsafe", lambda n: raw_token
        )
        client.post("/api/v1/auth/forgot-password", json={"user_email": email})

        with Session(engine) as session:
            token_row = session.exec(
                select(PasswordResetToken).where(
                    PasswordResetToken.user_id == seeded["ids"]["fk"]
                ).order_by(PasswordResetToken.reset_id.desc())
            ).first()
            assert token_row is not None
            assert token_row.token_hash == hashlib.sha256(
                raw_token.encode("utf-8")
            ).hexdigest()

        resp = client.post("/api/v1/auth/reset-password", json={
            "token": raw_token,
            "new_password": "NewPass@123",
        })
        assert resp.status_code == 200

        login_resp = client.post("/api/v1/auth/login", json={
            "user_email": email,
            "user_password": "NewPass@123",
        })
        assert login_resp.status_code == 200

    def test_reset_password_used_token_fails(self, client, seeded, engine, monkeypatch):
        email = seeded["emails"]["fk"]
        raw_token = "known-raw-reset-token"
        monkeypatch.setattr(
            "app.api.v1.endpoints.auth.secrets.token_urlsafe", lambda n: raw_token
        )
        client.post("/api/v1/auth/forgot-password", json={"user_email": email})

        client.post("/api/v1/auth/reset-password", json={
            "token": raw_token, "new_password": "NewPass@123",
        })
        resp2 = client.post("/api/v1/auth/reset-password", json={
            "token": raw_token, "new_password": "Another@123",
        })
        assert resp2.status_code == 400


# ── Encryption at Rest ──────────────────────────────────────────

class TestEncryption:
    def test_encrypt_decrypt_roundtrip(self):
        plain = "0721234567"
        cipher = encrypt_value(plain)
        assert cipher != plain
        assert decrypt_value(cipher) == plain

    def test_encrypt_empty_returns_empty(self):
        assert encrypt_value("") == ""
        assert decrypt_value("") == ""


# ── Security Headers ────────────────────────────────────────────

class TestSecurityHeaders:
    def test_security_headers_present(self, client):
        resp = client.get("/api/v1/auth/me",
                          headers={"Authorization": "Bearer invalid-token"})
        assert resp.headers.get("X-Content-Type-Options") == "nosniff"
        assert resp.headers.get("X-Frame-Options") == "DENY"
        assert resp.headers.get("Strict-Transport-Security") is not None
