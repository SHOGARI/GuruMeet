from typing import Literal

from pydantic import BaseModel, Field


class LocationSearchResult(BaseModel):
    id: str = Field(examples=["station:1132005"])
    type: Literal["municipality", "station"] = Field(examples=["station"])
    name: str = Field(examples=["北千住駅"])
    displayName: str = Field(examples=["北千住駅・東京都足立区"])
    prefecture: str = Field(examples=["東京都"])
    municipality: str | None = Field(default=None, examples=["足立区"])
    latitude: float = Field(examples=[35.7494])
    longitude: float = Field(examples=[139.805])
    lineName: str | None = Field(default=None, examples=["JR常磐線"])


class LocationCandidate(BaseModel):
    id: str = Field(examples=["station:1132005"])
    type: Literal["municipality", "station"] = Field(examples=["station"])
    name: str = Field(examples=["北千住駅"])
    kana: str | None = Field(default=None, examples=["キタセンジュ"])
    displayName: str = Field(examples=["北千住駅・東京都足立区"])
    prefecture: str = Field(examples=["東京都"])
    municipality: str | None = Field(default=None, examples=["足立区"])
    lineName: str | None = Field(default=None, examples=["JR常磐線"])
