"""
Base repository class. All repositories inherit from this.
"""

from abc import ABC, abstractmethod
from typing import Generic, TypeVar, List, Optional, Any
from sqlalchemy.orm import Session
from sqlalchemy import func, and_

T = TypeVar("T")

class BaseRepository(ABC, Generic[T]):
    """Thin wrapper around SQLAlchemy session. No business logic."""

    def __init__(self, db: Session, model: Any):
        self.db = db
        self.model = model

    def get_all(self) -> List[T]:
        return self.db.query(self.model).all()

    def get_by_id(self, id: int) -> Optional[T]:
        return self.db.query(self.model).filter(self.model.id == id).first()

    def count(self) -> int:
        return self.db.query(func.count(self.model.id)).scalar()
