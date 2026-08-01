"""add temporary group voting completed at

Revision ID: 202607310001
Revises: 202607300002
Create Date: 2026-07-31 00:00:01.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202607310001"
down_revision: str | None = "202607300002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "temporary_groups",
        sa.Column("voting_completed_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("temporary_groups", "voting_completed_at")
