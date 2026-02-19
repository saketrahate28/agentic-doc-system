"""
Authentication Module
=====================
Part of the Agentic Documentation System demo.
This module demonstrates a sample codebase that the
documentation pipeline will track and sync to Confluence.

Confluence Page: https://pikachu28.atlassian.net/wiki/spaces/ED1/pages/688129
"""

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional
import hashlib
import secrets


@dataclass
class User:
    """Represents an authenticated user in the system."""
    id: str
    email: str
    name: str
    role: str = "viewer"
    created_at: datetime = None

    def __post_init__(self) -> None:
        if self.created_at is None:
            self.created_at = datetime.utcnow()


class AuthenticationError(Exception):
    """Raised when authentication fails."""
    pass


class AuthorizationError(Exception):
    """Raised when a user lacks required permissions."""
    pass


class AuthService:
    """
    Authentication and authorization service.

    Handles user login, token generation, and role-based
    access control for the application.

    Supported roles:
        - viewer: Read-only access
        - editor: Can modify content
        - admin: Full system access
    """

    ROLE_HIERARCHY = {
        "viewer": 0,
        "editor": 1,
        "admin": 2,
    }

    def __init__(self) -> None:
        self._users: dict[str, User] = {}
        self._tokens: dict[str, str] = {}  # token -> user_id
        self._token_expiry: dict[str, datetime] = {}

    def register_user(
        self,
        email: str,
        name: str,
        password: str,
        role: str = "viewer",
    ) -> User:
        """
        Register a new user in the system.

        Args:
            email: User's email address (must be unique).
            name: User's display name.
            password: Plain-text password (will be hashed).
            role: One of 'viewer', 'editor', 'admin'.

        Returns:
            The newly created User object.

        Raises:
            ValueError: If email already exists or role is invalid.
        """
        if role not in self.ROLE_HIERARCHY:
            raise ValueError(f"Invalid role: {role}. Must be one of {list(self.ROLE_HIERARCHY.keys())}")

        if any(u.email == email for u in self._users.values()):
            raise ValueError(f"User with email {email} already exists")

        user_id = hashlib.sha256(email.encode()).hexdigest()[:12]
        user = User(id=user_id, email=email, name=name, role=role)
        self._users[user_id] = user
        return user

    def login(self, email: str, password: str) -> str:
        """
        Authenticate a user and return an access token.

        Args:
            email: User's email address.
            password: User's password.

        Returns:
            A secure access token string.

        Raises:
            AuthenticationError: If credentials are invalid.
        """
        user = next(
            (u for u in self._users.values() if u.email == email),
            None,
        )
        if user is None:
            raise AuthenticationError("Invalid email or password")

        token = secrets.token_urlsafe(32)
        self._tokens[token] = user.id
        self._token_expiry[token] = datetime.utcnow() + timedelta(hours=24)
        return token

    def verify_token(self, token: str) -> User:
        """
        Verify an access token and return the associated user.

        Args:
            token: The access token to verify.

        Returns:
            The User associated with the token.

        Raises:
            AuthenticationError: If token is invalid or expired.
        """
        if token not in self._tokens:
            raise AuthenticationError("Invalid token")

        if datetime.utcnow() > self._token_expiry[token]:
            del self._tokens[token]
            del self._token_expiry[token]
            raise AuthenticationError("Token has expired")

        user_id = self._tokens[token]
        return self._users[user_id]

    def check_permission(
        self,
        user: User,
        required_role: str,
    ) -> bool:
        """
        Check if a user has the required role level.

        Args:
            user: The user to check.
            required_role: The minimum role required.

        Returns:
            True if user has sufficient permissions.

        Raises:
            AuthorizationError: If user lacks required role.
        """
        if required_role not in self.ROLE_HIERARCHY:
            raise ValueError(f"Invalid role: {required_role}")

        user_level = self.ROLE_HIERARCHY.get(user.role, -1)
        required_level = self.ROLE_HIERARCHY[required_role]

        if user_level < required_level:
            raise AuthorizationError(
                f"User '{user.name}' has role '{user.role}', "
                f"but '{required_role}' is required"
            )
        return True

    def logout(self, token: str) -> None:
        """Invalidate an access token."""
        self._tokens.pop(token, None)
        self._token_expiry.pop(token, None)
