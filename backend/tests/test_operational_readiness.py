from datetime import UTC, datetime
import unittest
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient
from pydantic import SecretStr

from app.core.config import Settings, settings
from app.main import app
from app.services.temporary_group_cleanup_service import TemporaryGroupCleanupService


class OperationalReadinessTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(app)

    def test_request_body_size_limit_returns_413(self) -> None:
        original_limit = settings.request_body_max_bytes
        settings.request_body_max_bytes = 8
        try:
            response = self.client.post(
                "/temporary-groups",
                content=b'{"location":"shibuya"}',
                headers={"content-type": "application/json"},
            )
        finally:
            settings.request_body_max_bytes = original_limit

        self.assertEqual(response.status_code, 413)
        self.assertEqual(response.json()["detail"], "リクエストサイズが大きすぎます。")

    def test_internal_cleanup_requires_secret(self) -> None:
        original_secret = settings.internal_task_secret
        settings.internal_task_secret = SecretStr("test-secret")
        try:
            response = self.client.post(
                "/internal/cleanup-expired-temporary-groups",
            )
        finally:
            settings.internal_task_secret = original_secret

        self.assertEqual(response.status_code, 401)

    def test_internal_cleanup_rejects_empty_configured_secret(self) -> None:
        original_secret = settings.internal_task_secret
        settings.internal_task_secret = SecretStr("")
        try:
            response = self.client.post(
                "/internal/cleanup-expired-temporary-groups",
                headers={"X-Internal-Task-Secret": ""},
            )
        finally:
            settings.internal_task_secret = original_secret

        self.assertEqual(response.status_code, 401)

    def test_internal_cleanup_deletes_expired_groups_when_authorized(self) -> None:
        original_secret = settings.internal_task_secret
        settings.internal_task_secret = SecretStr("test-secret")
        try:
            with patch(
                "app.api.routes.internal.TemporaryGroupCleanupService"
            ) as cleanup_service:
                cleanup_service.return_value.delete_expired_groups.return_value = 3
                response = self.client.post(
                    "/internal/cleanup-expired-temporary-groups",
                    headers={"X-Internal-Task-Secret": "test-secret"},
                )
        finally:
            settings.internal_task_secret = original_secret

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"deleted_expired_temporary_groups": 3},
        )

    def test_cleanup_continues_when_summary_fails(self) -> None:
        db = MagicMock()
        service = TemporaryGroupCleanupService(db)
        service.repository = MagicMock()
        service.repository.expired_summary.side_effect = RuntimeError("summary failed")
        service.repository.delete_expired.return_value = 2
        service.repository.delete_expired_custom_locations.return_value = 1

        with patch(
            "app.services.temporary_group_cleanup_service.datetime"
        ) as datetime_mock:
            datetime_mock.now.return_value = datetime(2026, 8, 1, 12, 0, tzinfo=UTC)
            with patch(
                "app.services.temporary_group_cleanup_service.notify_cleanup_completed"
            ) as notify:
                deleted_count = service.delete_expired_groups()

        self.assertEqual(deleted_count, 2)
        db.rollback.assert_called_once()
        service.repository.delete_expired.assert_called_once()
        service.repository.delete_expired_custom_locations.assert_called_once()
        db.commit.assert_called_once()
        notify.assert_called_once()

    def test_cors_origins_accept_json_or_comma_separated_values(self) -> None:
        json_settings = Settings(
            _env_file=None,
            cors_allow_origins='["https://gurumeet.net","https://stg.gurumeet.net"]',
        )
        comma_settings = Settings(
            _env_file=None,
            cors_allow_origins="https://gurumeet.net,https://stg.gurumeet.net",
        )

        self.assertEqual(
            json_settings.cors_allow_origins,
            ["https://gurumeet.net", "https://stg.gurumeet.net"],
        )
        self.assertEqual(
            comma_settings.cors_allow_origins,
            ["https://gurumeet.net", "https://stg.gurumeet.net"],
        )

    def test_cors_origins_accept_single_environment_value(self) -> None:
        with patch.dict(
            "os.environ",
            {
                "CORS_ALLOW_ORIGINS": "https://gurumeet.net",
                "GURUMEET_ENABLE_MOCK_RESTAURANTS": "true",
                "INTERNAL_TASK_SECRET": "test-internal-secret",
                "PARTICIPANT_TOKEN_HASH_SECRET": "test-secret",
            },
            clear=True,
        ):
            loaded_settings = Settings(_env_file=None)

        self.assertEqual(
            loaded_settings.cors_allow_origins,
            ["https://gurumeet.net"],
        )
