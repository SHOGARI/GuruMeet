"""create locations

Revision ID: 202607300001
Revises: 202607290002
Create Date: 2026-07-30 00:00:01.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202607300001"
down_revision: str | None = "202607290002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "locations",
        sa.Column("id", sa.String(length=40), nullable=False),
        sa.Column("location_type", sa.String(length=32), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("name_kana", sa.String(length=128), nullable=True),
        sa.Column("normalized_name", sa.String(length=128), nullable=False),
        sa.Column("normalized_kana", sa.String(length=128), nullable=True),
        sa.Column("display_name", sa.String(length=255), nullable=False),
        sa.Column("prefecture_name", sa.String(length=32), nullable=False),
        sa.Column("municipality_name", sa.String(length=64), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("source", sa.String(length=32), nullable=False),
        sa.Column("source_updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "location_type IN ('municipality', 'station')",
            name="ck_locations_location_type",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_locations_location_type",
        "locations",
        ["location_type"],
        unique=False,
    )
    op.create_index(
        "ix_locations_prefecture_name",
        "locations",
        ["prefecture_name"],
        unique=False,
    )
    op.create_index(
        "ix_locations_normalized_name",
        "locations",
        ["normalized_name"],
        unique=False,
    )
    op.create_index(
        "ix_locations_normalized_kana",
        "locations",
        ["normalized_kana"],
        unique=False,
    )

    op.create_table(
        "municipality_locations",
        sa.Column("location_id", sa.String(length=40), nullable=False),
        sa.Column("municipality_code", sa.String(length=16), nullable=False),
        sa.ForeignKeyConstraint(
            ["location_id"],
            ["locations.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("location_id"),
        sa.UniqueConstraint(
            "municipality_code",
            name="uq_municipality_locations_municipality_code",
        ),
    )
    op.create_index(
        "ix_municipality_locations_municipality_code",
        "municipality_locations",
        ["municipality_code"],
        unique=False,
    )

    op.create_table(
        "station_locations",
        sa.Column("location_id", sa.String(length=40), nullable=False),
        sa.Column("station_code", sa.String(length=16), nullable=False),
        sa.Column("station_group_code", sa.String(length=16), nullable=True),
        sa.Column("line_name", sa.String(length=128), nullable=True),
        sa.ForeignKeyConstraint(
            ["location_id"],
            ["locations.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("location_id"),
        sa.UniqueConstraint("station_code", name="uq_station_locations_station_code"),
    )
    op.create_index(
        "ix_station_locations_station_code",
        "station_locations",
        ["station_code"],
        unique=False,
    )
    op.create_index(
        "ix_station_locations_station_group_code",
        "station_locations",
        ["station_group_code"],
        unique=False,
    )

    op.add_column(
        "temporary_groups",
        sa.Column("location_id", sa.String(length=40), nullable=True),
    )
    op.create_index(
        "ix_temporary_groups_location_id",
        "temporary_groups",
        ["location_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_temporary_groups_location_id_locations",
        "temporary_groups",
        "locations",
        ["location_id"],
        ["id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_temporary_groups_location_id_locations",
        "temporary_groups",
        type_="foreignkey",
    )
    op.drop_index("ix_temporary_groups_location_id", table_name="temporary_groups")
    op.drop_column("temporary_groups", "location_id")

    op.drop_index(
        "ix_station_locations_station_group_code",
        table_name="station_locations",
    )
    op.drop_index("ix_station_locations_station_code", table_name="station_locations")
    op.drop_table("station_locations")

    op.drop_index(
        "ix_municipality_locations_municipality_code",
        table_name="municipality_locations",
    )
    op.drop_table("municipality_locations")

    op.drop_index("ix_locations_normalized_kana", table_name="locations")
    op.drop_index("ix_locations_normalized_name", table_name="locations")
    op.drop_index("ix_locations_prefecture_name", table_name="locations")
    op.drop_index("ix_locations_location_type", table_name="locations")
    op.drop_table("locations")
