"""add selected location metadata to temporary groups

Revision ID: 202607300002
Revises: 202607290002, 202607300001
Create Date: 2026-07-30 00:00:02.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202607300002"
down_revision: str | Sequence[str] | None = ("202607290002", "202607300001")
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "temporary_groups",
        sa.Column("location_id", sa.String(length=40), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("location_type", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("location_prefecture_name", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("location_municipality_name", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("location_municipality_code", sa.String(length=16), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("location_station_code", sa.String(length=16), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("location_station_group_code", sa.String(length=16), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("location_latitude", sa.Float(), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("location_longitude", sa.Float(), nullable=True),
    )
    op.add_column(
        "temporary_groups",
        sa.Column("location_radius_meters", sa.Integer(), nullable=True),
    )
    op.create_index(
        "ix_temporary_groups_location_id",
        "temporary_groups",
        ["location_id"],
        unique=False,
    )
    op.create_check_constraint(
        "ck_temporary_groups_location_type",
        "temporary_groups",
        "location_type IS NULL OR location_type IN ('municipality', 'station')",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_temporary_groups_location_type",
        "temporary_groups",
        type_="check",
    )
    op.drop_index("ix_temporary_groups_location_id", table_name="temporary_groups")
    op.drop_column("temporary_groups", "location_radius_meters")
    op.drop_column("temporary_groups", "location_longitude")
    op.drop_column("temporary_groups", "location_latitude")
    op.drop_column("temporary_groups", "location_station_group_code")
    op.drop_column("temporary_groups", "location_station_code")
    op.drop_column("temporary_groups", "location_municipality_code")
    op.drop_column("temporary_groups", "location_municipality_name")
    op.drop_column("temporary_groups", "location_prefecture_name")
    op.drop_column("temporary_groups", "location_type")
    op.drop_column("temporary_groups", "location_id")
