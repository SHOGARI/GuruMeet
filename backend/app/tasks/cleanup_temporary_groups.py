from app.db.database import SessionLocal
from app.services.temporary_group_cleanup_service import TemporaryGroupCleanupService


def main() -> None:
    with SessionLocal() as db:
        deleted_count = TemporaryGroupCleanupService(db).delete_expired_groups()
    print(f"deleted_expired_temporary_groups={deleted_count}")


if __name__ == "__main__":
    main()
