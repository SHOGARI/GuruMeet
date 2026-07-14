from pydantic import BaseModel


class MeetingBase(BaseModel):
    title: str
