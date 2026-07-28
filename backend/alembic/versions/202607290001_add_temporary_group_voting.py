"""add temporary group voting

Revision ID: 202607290001
Revises: 202607230001
Create Date: 2026-07-29 00:00:01.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "202607290001"
down_revision: str | None = "202607230001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "temporary_groups",
        sa.Column("voting_started_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_table(
        "temporary_group_votes",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("temporary_group_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("anonymous_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("restaurant_id", sa.String(length=128), nullable=False),
        sa.Column("liked", sa.Boolean(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["anonymous_user_id"],
            ["anonymous_users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["temporary_group_id"],
            ["temporary_groups.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "temporary_group_id",
            "anonymous_user_id",
            "restaurant_id",
            name="uq_temporary_group_votes_group_user_restaurant",
        ),
    )
    op.create_index(
        "ix_temporary_group_votes_temporary_group_id",
        "temporary_group_votes",
        ["temporary_group_id"],
        unique=False,
    )
    op.create_index(
        "ix_temporary_group_votes_anonymous_user_id",
        "temporary_group_votes",
        ["anonymous_user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_temporary_group_votes_anonymous_user_id",
        table_name="temporary_group_votes",
    )
    op.drop_index(
        "ix_temporary_group_votes_temporary_group_id",
        table_name="temporary_group_votes",
    )
    op.drop_table("temporary_group_votes")
    op.drop_column("temporary_groups", "voting_started_at")
