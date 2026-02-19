"""
Tests for the Authentication Module
"""

from src.auth import AuthService, AuthenticationError, AuthorizationError, User
import pytest


@pytest.fixture
def auth_service() -> AuthService:
    """Create a fresh AuthService instance for each test."""
    return AuthService()


@pytest.fixture
def registered_user(auth_service: AuthService) -> User:
    """Register and return a test user."""
    return auth_service.register_user(
        email="test@example.com",
        name="Test User",
        password="secure123",
        role="editor",
    )


class TestRegistration:
    """Tests for user registration."""

    def test_register_user_success(self, auth_service: AuthService) -> None:
        user = auth_service.register_user(
            email="alice@example.com",
            name="Alice",
            password="pass123",
        )
        assert user.email == "alice@example.com"
        assert user.name == "Alice"
        assert user.role == "viewer"

    def test_register_duplicate_email(self, auth_service: AuthService) -> None:
        auth_service.register_user("a@b.com", "A", "pass")
        with pytest.raises(ValueError, match="already exists"):
            auth_service.register_user("a@b.com", "B", "pass")

    def test_register_invalid_role(self, auth_service: AuthService) -> None:
        with pytest.raises(ValueError, match="Invalid role"):
            auth_service.register_user("x@y.com", "X", "p", role="superadmin")


class TestLogin:
    """Tests for user login."""

    def test_login_success(
        self, auth_service: AuthService, registered_user: User
    ) -> None:
        token = auth_service.login("test@example.com", "secure123")
        assert isinstance(token, str)
        assert len(token) > 0

    def test_login_invalid_email(self, auth_service: AuthService) -> None:
        with pytest.raises(AuthenticationError):
            auth_service.login("nobody@example.com", "pass")


class TestPermissions:
    """Tests for role-based access control."""

    def test_editor_has_viewer_access(
        self, auth_service: AuthService, registered_user: User
    ) -> None:
        assert auth_service.check_permission(registered_user, "viewer") is True

    def test_editor_lacks_admin_access(
        self, auth_service: AuthService, registered_user: User
    ) -> None:
        with pytest.raises(AuthorizationError):
            auth_service.check_permission(registered_user, "admin")
