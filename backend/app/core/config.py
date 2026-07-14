from pydantic import BaseModel


class Settings(BaseModel):
    app_name: str = "Gurumeet Backend"


settings = Settings()
