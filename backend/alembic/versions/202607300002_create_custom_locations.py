"""create custom locations

Revision ID: 202607300002
Revises: 202607300001
Create Date: 2026-07-30 00:00:02.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "202607300002"
down_revision: str | None = "202607300001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "custom_locations",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("display_name", sa.String(length=255), nullable=False),
        sa.Column("prefecture_name", sa.String(length=32), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("accuracy_meters", sa.Float(), nullable=True),
        sa.Column("source", sa.String(length=32), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "source IN ('current_location', 'map_pin')",
            name="ck_custom_locations_source",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_custom_locations_expires_at",
        "custom_locations",
        ["expires_at"],
        unique=False,
    )
    op.add_column(
        "temporary_groups",
        sa.Column("custom_location_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.create_index(
        "ix_temporary_groups_custom_location_id",
        "temporary_groups",
        ["custom_location_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_temporary_groups_custom_location_id_custom_locations",
        "temporary_groups",
        "custom_locations",
        ["custom_location_id"],
        ["id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_temporary_groups_custom_location_id_custom_locations",
        "temporary_groups",
        type_="foreignkey",
    )
    op.drop_index(
        "ix_temporary_groups_custom_location_id",
        table_name="temporary_groups",
    )
    op.drop_column("temporary_groups", "custom_location_id")
    op.drop_index("ix_custom_locations_expires_at", table_name="custom_locations")
    op.drop_table("custom_locations")
