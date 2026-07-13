from pydantic import BaseModel


class Settings(BaseModel):
    app_name: str = "MoguMeet Backend"


settings = Settings()
