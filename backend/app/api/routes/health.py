from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/")
def read_root() -> dict[str, str]:
    return {"status": "ok", "service": "gurumeet-backend"}


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "healthy"}
