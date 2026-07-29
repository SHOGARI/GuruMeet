"""create location search tables

Revision ID: 202607300001
Revises: 202607290001
Create Date: 2026-07-30 00:00:01.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202607300001"
down_revision: str | None = "202607290001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "municipalities",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("municipality_code", sa.String(length=16), nullable=False),
        sa.Column("prefecture_name", sa.String(length=32), nullable=False),
        sa.Column("municipality_name", sa.String(length=64), nullable=False),
        sa.Column("name_kana", sa.String(length=128), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "municipality_code",
            name="uq_municipalities_municipality_code",
        ),
    )
    op.create_index(
        "ix_municipalities_municipality_code",
        "municipalities",
        ["municipality_code"],
        unique=False,
    )

    op.create_table(
        "stations",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("station_code", sa.String(length=16), nullable=False),
        sa.Column("station_group_code", sa.String(length=16), nullable=True),
        sa.Column("station_name", sa.String(length=128), nullable=False),
        sa.Column("name_kana", sa.String(length=128), nullable=True),
        sa.Column("prefecture_name", sa.String(length=32), nullable=False),
        sa.Column("municipality_name", sa.String(length=64), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("line_name", sa.String(length=128), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("station_code", name="uq_stations_station_code"),
    )
    op.create_index(
        "ix_stations_station_code",
        "stations",
        ["station_code"],
        unique=False,
    )
    op.create_index(
        "ix_stations_station_group_code",
        "stations",
        ["station_group_code"],
        unique=False,
    )

    op.create_table(
        "location_search",
        sa.Column("id", sa.String(length=40), nullable=False),
        sa.Column("location_type", sa.String(length=32), nullable=False),
        sa.Column("source_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("name_kana", sa.String(length=128), nullable=True),
        sa.Column("normalized_name", sa.String(length=128), nullable=False),
        sa.Column("normalized_kana", sa.String(length=128), nullable=True),
        sa.Column("display_name", sa.String(length=255), nullable=False),
        sa.Column("prefecture_name", sa.String(length=32), nullable=False),
        sa.Column("municipality_name", sa.String(length=64), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("municipality_code", sa.String(length=16), nullable=True),
        sa.Column("station_code", sa.String(length=16), nullable=True),
        sa.Column("station_group_code", sa.String(length=16), nullable=True),
        sa.Column("line_name", sa.String(length=128), nullable=True),
        sa.CheckConstraint(
            "location_type IN ('municipality', 'station')",
            name="ck_location_search_location_type",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_location_search_location_type",
        "location_search",
        ["location_type"],
        unique=False,
    )
    op.create_index(
        "ix_location_search_source_id",
        "location_search",
        ["source_id"],
        unique=False,
    )
    op.create_index(
        "ix_location_search_normalized_name",
        "location_search",
        ["normalized_name"],
        unique=False,
    )
    op.create_index(
        "ix_location_search_normalized_kana",
        "location_search",
        ["normalized_kana"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_location_search_normalized_kana", table_name="location_search")
    op.drop_index("ix_location_search_normalized_name", table_name="location_search")
    op.drop_index("ix_location_search_source_id", table_name="location_search")
    op.drop_index("ix_location_search_location_type", table_name="location_search")
    op.drop_table("location_search")
    op.drop_index("ix_stations_station_group_code", table_name="stations")
    op.drop_index("ix_stations_station_code", table_name="stations")
    op.drop_table("stations")
    op.drop_index("ix_municipalities_municipality_code", table_name="municipalities")
    op.drop_table("municipalities")
