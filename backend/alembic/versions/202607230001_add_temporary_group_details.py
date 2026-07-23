"""add temporary group details and participants

Revision ID: 202607230001
Revises: 202607150001
Create Date: 2026-07-23 00:00:01.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "202607230001"
down_revision: str | None = "202607150001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "temporary_groups",
        sa.Column("participant_count", sa.Integer(), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("location", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("budget_min", sa.Integer(), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("budget_max", sa.Integer(), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("restaurant", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )
    op.create_table(
        "anonymous_users",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("participant_token_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "last_seen_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "participant_token_hash",
            name="uq_anonymous_users_participant_token_hash",
        ),
    )
    op.create_table(
        "temporary_group_participants",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("temporary_group_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("anonymous_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "joined_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "last_seen_at",
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
            name="uq_temporary_group_participants_group_user",
        ),
    )
    op.create_index(
        "ix_temporary_group_participants_temporary_group_id",
        "temporary_group_participants",
        ["temporary_group_id"],
        unique=False,
    )
    op.create_index(
        "ix_temporary_group_participants_anonymous_user_id",
        "temporary_group_participants",
        ["anonymous_user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_temporary_group_participants_anonymous_user_id",
        table_name="temporary_group_participants",
    )
    op.drop_index(
        "ix_temporary_group_participants_temporary_group_id",
        table_name="temporary_group_participants",
    )
    op.drop_table("temporary_group_participants")
    op.drop_table("anonymous_users")
    op.drop_column("temporary_groups", "restaurant")
    op.drop_column("temporary_groups", "budget_max")
    op.drop_column("temporary_groups", "budget_min")
    op.drop_column("temporary_groups", "location")
    op.drop_column("temporary_groups", "participant_count")
