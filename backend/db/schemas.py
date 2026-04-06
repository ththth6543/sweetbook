from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

# TravelLog Schemas
class TravelLogBase(BaseModel):
    title: str
    location: str
    content: str
    travelbook_id: Optional[int] = None

class TravelLogCreate(TravelLogBase):
    pass

class TravelLog(TravelLogBase):
    id: int
    created_at: datetime
    
    class Config:
        from_attributes = True

# BookPage Schemas
class BookPageBase(BaseModel):
    template_uid: str
    parameters: str
    order: int = 0
    price: int = 100

class BookPageCreate(BookPageBase):
    pass

class BookPageUpdate(BaseModel):
    template_uid: Optional[str] = None
    parameters: Optional[str] = None
    order: Optional[int] = None

class BookPage(BookPageBase):
    id: int
    travelbook_id: int
    template_name: Optional[str] = None # 프론트엔드 그리드 표시용
    template_thumbnail: Optional[str] = None # 프론트엔드 그리드 표시용
    
    class Config:
        from_attributes = True

# TravelBook Schemas
class TravelBookBase(BaseModel):
    title: str
    description: Optional[str] = None

class TravelBookCreate(TravelBookBase):
    log_ids: List[int] = [] # 선택된 여행 기록 ID 목록
    book_spec_uid: Optional[str] = "PHOTOBOOK_A5_SC" # 판형 선택 추가
    cover_template_id: Optional[str] = None # 표지 고르기 추가
    manual_edit: bool = False # 수동 편집 여부 추가

class TravelBook(TravelBookBase):
    id: int
    sweetbook_uid: Optional[str] = None
    status: str
    book_spec_uid: Optional[str] = None
    pdf_url: Optional[str] = None
    cover_template_id: Optional[str] = None
    cover_parameters: Optional[str] = None
    cover_template_name: Optional[str] = None # 표지 템플릿 이름 추가
    cover_thumbnail: Optional[str] = None # 표지 썸네일 추가
    price: int = 0
    created_at: datetime
    logs: List[TravelLog] = []
    pages: List[BookPage] = []
    total_pages: Optional[int] = 0 # 실시간 계산된 총 페이지 수
    min_pages: Optional[int] = 24
    max_pages: Optional[int] = 130
    page_increment: Optional[int] = 2
    
    class Config:
        from_attributes = True
# Template Metadata Schemas
class TemplateMetadataBase(BaseModel):
    template_uid: str
    template_name: Optional[str] = None
    template_kind: str
    thumbnail: Optional[str] = None # 썸네일 URL
    parameter_definitions: str # JSON string

class TemplateMetadataCreate(TemplateMetadataBase):
    pass

class TemplateMetadata(TemplateMetadataBase):
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
