from pydantic import BaseModel


class Settings(BaseModel):
    app_name: str = "GuruMeet Backend"


settings = Settings()
