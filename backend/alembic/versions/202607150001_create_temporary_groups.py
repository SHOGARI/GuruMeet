"""create temporary groups

Revision ID: 202607150001
Revises: 6377a309937a
Create Date: 2026-07-15 00:00:01.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "202607150001"
down_revision: str | None = "6377a309937a"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "temporary_groups",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("code", sa.CHAR(length=5), nullable=False),
        sa.Column("creator_id", sa.String(length=128), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code", name="uq_temporary_groups_code"),
    )
    op.create_index(
        "ix_temporary_groups_code",
        "temporary_groups",
        ["code"],
        unique=False,
    )
    op.create_index(
        "ix_temporary_groups_expires_at",
        "temporary_groups",
        ["expires_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_temporary_groups_expires_at", table_name="temporary_groups")
    op.drop_index("ix_temporary_groups_code", table_name="temporary_groups")
    op.drop_table("temporary_groups")
