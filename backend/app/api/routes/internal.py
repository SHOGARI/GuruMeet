from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db
from app.services.temporary_group_cleanup_service import (
    TemporaryGroupCleanupService,
)

router = APIRouter(prefix="/internal", tags=["internal"])


@router.post("/cleanup-expired-temporary-groups")
def cleanup_expired_temporary_groups(
    x_internal_task_secret: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> dict[str, int]:
    configured_secret = settings.internal_task_secret
    if configured_secret is None or (
        x_internal_task_secret != configured_secret.get_secret_value()
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="認証が必要です。",
        )

    deleted_count = TemporaryGroupCleanupService(db).delete_expired_groups()
    return {"deleted_expired_temporary_groups": deleted_count}
