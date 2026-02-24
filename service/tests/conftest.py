"""Pytest configuration.

Disable the OpenTelemetry SDK during tests so the app never attempts to reach a
(non-existent) OTLP collector. Set before ``svc`` is imported.
"""

from __future__ import annotations

import os

os.environ.setdefault("OTEL_SDK_DISABLED", "true")
