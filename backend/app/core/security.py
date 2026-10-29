import hashlib
import secrets

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

_hasher = PasswordHasher()


def hash_password(password: str) -> str:
    """Argon2id hash (salted, slow by design)."""
    return _hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _hasher.verify(password_hash, password)
    except (VerifyMismatchError, InvalidHashError):
        return False


def new_token() -> str:
    """Random opaque token given to the client (never stored as-is)."""
    return secrets.token_urlsafe(32)


def hash_token(token: str) -> str:
    """Tokens are stored as SHA-256 hashes so a database leak can't be replayed."""
    return hashlib.sha256(token.encode()).hexdigest()
