import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import httpx
from pydantic import SecretStr

from app.core.config import Settings, settings
from app.services.hotpepper_service import (
    HotPepperAPIError,
    HotPepperConfigurationError,
    search_restaurants_by_location,
)


class SettingsTests(unittest.TestCase):
    def test_settings_allow_missing_hotpepper_api_key_when_mocks_enabled(
        self,
    ) -> None:
        with patch.dict(
            os.environ,
            {
                "GURUMEET_ENABLE_MOCK_RESTAURANTS": "true",
                "INTERNAL_TASK_SECRET": "test-internal-secret",
            },
            clear=True,
        ):
            loaded_settings = Settings(_env_file=None)

        self.assertIsNone(loaded_settings.hotpepper_api_key)

    def test_settings_reject_empty_hotpepper_api_key_when_mocks_disabled(
        self,
    ) -> None:
        with patch.dict(
            os.environ,
            {
                "HOTPEPPER_API_KEY": "",
                "GURUMEET_ENABLE_MOCK_RESTAURANTS": "false",
                "INTERNAL_TASK_SECRET": "test-internal-secret",
            },
            clear=True,
        ):
            with self.assertRaises(ValueError):
                Settings(_env_file=None)

    def test_api_docs_are_disabled_in_production(self) -> None:
        for environment in ("production", "product"):
            with self.subTest(environment=environment):
                with patch.dict(
                    os.environ,
                    {"ENVIRONMENT": environment},
                    clear=True,
                ):
                    loaded_settings = Settings(_env_file=None)

                self.assertFalse(loaded_settings.api_docs_enabled)

    def test_staging_uses_configured_api_root_path(self) -> None:
        with patch.dict(
            os.environ,
            {
                "ENVIRONMENT": "staging",
                "GURUMEET_API_ROOT_PATH": "/api",
            },
            clear=True,
        ):
            loaded_settings = Settings(_env_file=None)

        self.assertTrue(loaded_settings.api_docs_enabled)
        self.assertEqual(loaded_settings.api_root_path, "/api")

    def test_health_starts_without_hotpepper_api_key(self) -> None:
        backend_root = Path(__file__).resolve().parents[1]
        environment = os.environ.copy()
        environment.pop("HOTPEPPER_API_KEY", None)
        environment["GURUMEET_ENABLE_MOCK_RESTAURANTS"] = "true"
        environment["INTERNAL_TASK_SECRET"] = "test-internal-secret"
        environment["PYTHONPATH"] = os.pathsep.join(
            filter(
                None,
                (str(backend_root), environment.get("PYTHONPATH")),
            )
        )
        command = (
            "from fastapi.testclient import TestClient; "
            "from app.main import app; "
            "response = TestClient(app).get('/health'); "
            "assert response.status_code == 200, response.text"
        )

        with tempfile.TemporaryDirectory() as temporary_directory:
            result = subprocess.run(
                [sys.executable, "-c", command],
                cwd=temporary_directory,
                env=environment,
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )

        self.assertEqual(result.returncode, 0, result.stderr)


class RestaurantServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_missing_api_key_fails_only_when_search_is_called(
        self,
    ) -> None:
        for api_key in (None, SecretStr(""), SecretStr("   ")):
            with self.subTest(api_key=api_key):
                with (
                    patch.object(settings, "hotpepper_api_key", api_key),
                    patch(
                        "app.services.hotpepper_service.httpx.AsyncClient"
                    ) as client_class,
                ):
                    with self.assertRaises(HotPepperConfigurationError):
                        await search_restaurants_by_location("渋谷")

                client_class.assert_not_called()

    async def test_keyword_is_sent_with_params_and_missing_shop_is_empty(self) -> None:
        response = MagicMock()
        response.raise_for_status.return_value = None
        response.json.return_value = {"results": {}}

        client = AsyncMock()
        client.get.return_value = response
        client_context = MagicMock()
        client_context.__aenter__ = AsyncMock(return_value=client)
        client_context.__aexit__ = AsyncMock(return_value=None)

        with patch(
            "app.services.hotpepper_service.httpx.AsyncClient",
            return_value=client_context,
        ):
            result = await search_restaurants_by_location("  日本橋  ", count=5)

        self.assertEqual(result, {"success": True, "count": 0, "shops": []})
        request_params = client.get.await_args.kwargs["params"]
        self.assertEqual(request_params["keyword"], "日本橋")
        self.assertEqual(request_params["count"], 5)
        self.assertEqual(request_params["format"], "json")

    async def test_connection_failure_raises_service_error(self) -> None:
        client = AsyncMock()
        client.get.side_effect = httpx.ConnectError("connection failed")
        client_context = MagicMock()
        client_context.__aenter__ = AsyncMock(return_value=client)
        client_context.__aexit__ = AsyncMock(return_value=None)

        with patch(
            "app.services.hotpepper_service.httpx.AsyncClient",
            return_value=client_context,
        ):
            with self.assertRaises(HotPepperAPIError):
                await search_restaurants_by_location("渋谷")


if __name__ == "__main__":
    unittest.main()
