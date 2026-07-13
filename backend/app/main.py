from fastapi import FastAPI

app = FastAPI(title="MoguMeet Backend")


@app.get("/")
def read_root() -> dict[str, str]:
    return {"status": "ok", "service": "mogumeet-backend"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "healthy"}
