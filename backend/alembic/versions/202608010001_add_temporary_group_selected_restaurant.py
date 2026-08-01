"""add temporary group selected restaurant

Revision ID: 202608010001
Revises: 202607310001
Create Date: 2026-08-01 00:00:01.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202608010001"
down_revision: str | None = "202607310001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "temporary_groups",
        sa.Column("selected_restaurant_id", sa.String(length=128), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("temporary_groups", "selected_restaurant_id")
