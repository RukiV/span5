import sys
from pathlib import Path

# Add parent folder so Python finds the 'models' package
current_dir = Path(__file__).parent
sys.path.insert(0, str(current_dir.parent))

print(f"Testing from: {current_dir}")

# Import from the models package (uses your __init__.py)
try:
    from models import UserCreate, AssettypeCreate
    print("✅ Successfully imported UserCreate and AssettypeCreate")
except Exception as e:
    print("❌ Import failed:", e)
    print("\nTry running with: python -m models.test_validators")
    sys.exit(1)

from pydantic import ValidationError
import logging

logging.basicConfig(level=logging.INFO)

print("\n=== Validator Test Results ===\n")

# Test 1: Valid data
try:
    user = UserCreate(
        user_name="John",
        user_surname="Doe",
        user_email="john.doe@example.com",
        user_password="SecurePass123",
        user_status="active",
        role_id=1
    )
    print("✅ Valid User created successfully")
except Exception as e:
    print("❌ Valid user failed:", str(e))

# Test 2: Dirty input (sanitization not active yet)
try:
    dirty = UserCreate(
        user_name="  John<script>alert(1)</script> ; DROP TABLE -- ",
        user_surname="Doe",
        user_email="john@example.com",
        user_password="SecurePass123",
        user_status="active",
        role_id=1
    )
    print("✅ Dirty input accepted (for now):", repr(dirty.user_name))
except Exception as e:
    print("❌ Dirty input error:", str(e))

# Test 3: Invalid data (will work better after we add Field validators)
try:
    bad_user = UserCreate(
        user_name="", 
        user_surname="Doe",
        user_email="not-an-email",
        user_password="short",
        user_status="active",
        role_id=1
    )
except ValidationError as e:
    print("✅ Correctly blocked bad data!")
    for error in e.errors()[:6]:
        print("   -", error['loc'], ":", error['msg'])
except Exception as e:
    print("❌ Unexpected error (normal for now):", str(e))

print("\n=== Test Complete ===")