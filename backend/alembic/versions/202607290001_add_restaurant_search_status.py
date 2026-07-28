"""add restaurant search status to temporary groups

Revision ID: 202607290001
Revises: 202607230001
Create Date: 2026-07-29 00:00:01.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202607290001"
down_revision: str | None = "202607230001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "temporary_groups",
        sa.Column(
            "restaurant_search_status",
            sa.String(length=32),
            server_default="not_requested",
            nullable=False,
        ),
    )
    op.create_check_constraint(
        "ck_temporary_groups_restaurant_search_status",
        "temporary_groups",
        "restaurant_search_status IN "
        "('not_requested', 'succeeded', 'no_results')",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_temporary_groups_restaurant_search_status",
        "temporary_groups",
        type_="check",
    )
    op.drop_column("temporary_groups", "restaurant_search_status")
