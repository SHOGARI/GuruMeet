from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.db.database_url import build_database_url


engine = create_engine(build_database_url())

SessionLocal = sessionmaker(
    bind=engine,
    class_=Session,
    autoflush=False,
    expire_on_commit=False,
)
