from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from db.database import Base

class TravelBook(Base):
    __tablename__ = "travelbooks"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True)
    description = Column(Text, nullable=True)
    sweetbook_uid = Column(String, index=True, nullable=True)  # Sweetbook bookUid
    status = Column(String, default="draft")  # draft, created, manual_editing, finalized
    book_spec_uid = Column(String, index=True, nullable=True) # 도서 판형 ID
    pdf_url = Column(String, nullable=True)
    cover_template_id = Column(String, nullable=True) # 선택된 표지 템플릿 ID
    cover_parameters = Column(Text, nullable=True) # 표지 파라미터(제목, 부제 등) JSON
    price = Column(Integer, default=0) # 총 정산 예정 금액
    created_at = Column(DateTime, default=datetime.utcnow)
    
    logs = relationship("TravelLog", back_populates="travelbook", cascade="all, delete-orphan")
    pages = relationship("BookPage", back_populates="travelbook", cascade="all, delete-orphan", order_by="BookPage.order")

class BookPage(Base):
    __tablename__ = "bookpages"
    
    id = Column(Integer, primary_key=True, index=True)
    travelbook_id = Column(Integer, ForeignKey("travelbooks.id"))
    template_uid = Column(String)
    parameters = Column(Text)  # JSON string of template parameters
    order = Column(Integer, default=0)
    price = Column(Integer, default=100) # 페이지별 비용
    is_synced = Column(Integer, default=0) # 0: False, 1: True (SQLite 호환성)
    
    travelbook = relationship("TravelBook", back_populates="pages")

class TravelLog(Base):
    __tablename__ = "travellogs"
    
    id = Column(Integer, primary_key=True, index=True)
    travelbook_id = Column(Integer, ForeignKey("travelbooks.id"), nullable=True)
    title = Column(String, index=True)
    location = Column(Text)  # 장소/위치
    content = Column(Text)   # 여행 기록 내용
    created_at = Column(DateTime, default=datetime.utcnow)
    
    travelbook = relationship("TravelBook", back_populates="logs")
class TemplateMetadataEntry(Base):
    __tablename__ = "template_metadata"
    
    template_uid = Column(String, primary_key=True, index=True)
    template_name = Column(String, nullable=True)
    template_kind = Column(String, index=True) # content, divider, publish, cover
    thumbnail = Column(String, nullable=True) # 썸네일 URL 추가
    parameter_definitions = Column(Text) # JSON string of list of field objects
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
