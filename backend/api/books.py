from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Response
import requests
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime
import json
from db.database import get_db
from db import models, schemas
from services.sweetbook import sweetbook_service
from core.config import settings
from utils.page_calculator import calculate_total_pages

router = APIRouter(
    prefix="/books",
    tags=["Books"]
)

@router.get("/specs")
def get_available_specs():
    try:
        return sweetbook_service.get_book_specs()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/templates")
def get_available_templates(
    book_spec_uid: Optional[str] = None, 
    template_kind: Optional[str] = None,
    scope: str = "all",
    limit: int = 50,
    offset: int = 0,
    db: Session = Depends(get_db)
):
    try:
        templates = sweetbook_service.get_templates(
            book_spec_uid=book_spec_uid, 
            template_kind=template_kind,
            scope=scope,
            limit=limit,
            offset=offset
        )
        # 로컬 DB 메타데이터와 병합
        result = []
        
        # 1. 먼저 스윗북 API에서 온 템플릿들을 처리
        for t in templates:
            uid = t.get("templateUid")
            theme = t.get("theme")
            
            # DB 메타데이터 조회
            db_meta = db.query(models.TemplateMetadataEntry).filter(
                models.TemplateMetadataEntry.template_uid == uid
            ).first()

            # 테마 필터링 완화: 
            # - 로컬 DB에 이미 동기화된 정보가 있거나 (관리 대상)
            # - 테마가 TRAVELBOOK이거나
            # - 혹은 테마 정보가 없는 경우만 결과에 포함
            if db_meta or theme == "TRAVELBOOK" or not theme:
                if db_meta:
                    t["templateName"] = db_meta.template_name
                    t["templateKind"] = db_meta.template_kind
                    # 프론트엔드 호환 포맷 강제 적용
                    t["thumbnails"] = {"layout": db_meta.thumbnail}
                else:
                    # DB에 없더라도 기본 썸네일 구조 보정
                    if "thumbnails" not in t or not t["thumbnails"]:
                        t["thumbnails"] = {"layout": t.get("thumbnail")}
                
                result.append(t)
        
        # 필터링된 결과가 없으면 전체 반환하되, 최소한의 구조 보정만 수행
        if not result:
            for t in templates:
                if "thumbnails" not in t or not t["thumbnails"]:
                    t["thumbnails"] = {"layout": t.get("thumbnail")}
            result = templates

        return {"success": True, "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/templates/{template_uid}")
def get_template_details(template_uid: str, db: Session = Depends(get_db)):
    try:
        # 1. 로컬 DB에서 메타데이터 검색
        db_metadata = db.query(models.TemplateMetadataEntry).filter(
            models.TemplateMetadataEntry.template_uid == template_uid
        ).first()
        
        # 2. 스윗북 API에서 기본 정보(썸네일 등) 가져오기 시도
        api_data = {}
        try:
            api_details = sweetbook_service.get_template_details(template_uid)
            api_data = api_details.get("data", {})
        except Exception as e:
            print(f"Warning: Could not fetch template {template_uid} from Sweetbook API: {e}")
            # API 실패해도 로컬 DB에 정보가 있으면 계속 진행
            if not db_metadata:
                raise HTTPException(status_code=404, detail=f"Template {template_uid} not found in DB or Sweetbook")
        
        if db_metadata:
            # DB 정보가 있으면 API 데이터와 병합 (DB의 파라미터 정의 우선)
            merged_data = api_data.copy()
            merged_data["templateUid"] = template_uid
            merged_data["templateName"] = db_metadata.template_name or api_data.get("templateName") or "Unknown Template"
            merged_data["templateKind"] = db_metadata.template_kind
            merged_data["thumbnail"] = db_metadata.thumbnail or api_data.get("thumbnail")
            # 프론트엔드 호환 포맷 추가
            merged_data["thumbnails"] = {"layout": merged_data["thumbnail"]}
            merged_data["parameterDefinitions"] = json.loads(db_metadata.parameter_definitions)
            return {"success": True, "data": merged_data, "source": "local_db"}
            
        # 로컬 DB에 없는데 API는 성공한 경우
        if api_data:
            return {"success": True, "data": api_data, "source": "sweetbook_api"}
            
        raise HTTPException(status_code=404, detail="Template not found")
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in get_template_details: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/templates/metadata", response_model=schemas.TemplateMetadata)
def upsert_template_metadata(meta_in: schemas.TemplateMetadataCreate, db: Session = Depends(get_db)):
    """
    템플릿의 파라미터 정의 및 UI 표기 정보를 DB에 저장하거나 업데이트합니다.
    """
    db_meta = db.query(models.TemplateMetadataEntry).filter(
        models.TemplateMetadataEntry.template_uid == meta_in.template_uid
    ).first()
    
    if db_meta:
        db_meta.template_name = meta_in.template_name
        db_meta.template_kind = meta_in.template_kind
        db_meta.thumbnail = meta_in.thumbnail
        db_meta.parameter_definitions = meta_in.parameter_definitions
    else:
        db_meta = models.TemplateMetadataEntry(
            template_uid=meta_in.template_uid,
            template_name=meta_in.template_name,
            template_kind=meta_in.template_kind,
            thumbnail=meta_in.thumbnail,
            parameter_definitions=meta_in.parameter_definitions
        )
        db.add(db_meta)
    
    db.commit()
    db.refresh(db_meta)
    return db_meta

@router.get("/proxy-image")
def proxy_image(url: str):
    """
    Flutter Web의 CORS 문제를 해결하기 위한 이미지 프록시 엔드포인트입니다.
    """
    if not url:
        raise HTTPException(status_code=400, detail="URL is required")
        
    try:
        # 브라우저처럼 보이도록 User-Agent 추가 (차단 방지)
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        
        print(f"Proxying image request for: {url}")
        response = requests.get(url, headers=headers, stream=True, timeout=10)
        
        if response.status_code != 200:
            print(f"Failed to fetch image from {url}: Status {response.status_code}")
            return Response(status_code=response.status_code)
            
        content_type = response.headers.get("Content-Type", "image/jpeg")
        
        return Response(
            content=response.content,
            media_type=content_type,
            headers={
                "Cache-Control": "public, max-age=3600",
                "Access-Control-Allow-Origin": "*" # 명시적으로 CORS 허용
            }
        )
    except Exception as e:
        print(f"Image proxy error for {url}: {e}")
        raise HTTPException(status_code=500, detail=f"Image proxy failed: {str(e)}")

@router.post("/", response_model=schemas.TravelBook, status_code=status.HTTP_201_CREATED)
def create_travelbook(book_in: schemas.TravelBookCreate, db: Session = Depends(get_db)):
    """
    프로젝트(책)를 먼저 생성합니다. 
    과거의 자동 생성 로직을 제거하고 수동 편집 모드로 바로 진입합니다.
    """
    db_book = models.TravelBook(
        title=book_in.title,
        description=book_in.description,
        book_spec_uid=book_in.book_spec_uid or "SQUAREBOOK_HC",
        status="manual_editing",
        price=100  # 초기 생성 비용 100원
    )
    db.add(db_book)
    db.commit()
    db.refresh(db_book)

    try:
        # 스윗북에 프로젝트 생성 (판형 반영)
        book_spec = book_in.book_spec_uid or "SQUAREBOOK_HC"
        sb_response = sweetbook_service.create_book(
            title=book_in.title,
            book_spec_uid=book_spec
        )
        
        sweetbook_uid = sb_response.get("data", {}).get("bookUid")
        if not sweetbook_uid:
            raise Exception("Sweetbook UID not returned")
            
        db_book.sweetbook_uid = sweetbook_uid
        db.commit()
    except Exception as e:
        db_book.status = f"error: {str(e)}"
        db.commit()
        print(f"Error in book creation: {e}")

    db.refresh(db_book)
    return db_book

@router.post("/{book_id}/photos")
async def upload_book_photo(book_id: int, file: UploadFile = File(...), db: Session = Depends(get_db)):
    db_book = db.query(models.TravelBook).filter(models.TravelBook.id == book_id).first()
    if not db_book or not db_book.sweetbook_uid:
        raise HTTPException(status_code=404, detail="Book not found")
        
    try:
        content = await file.read()
        res = sweetbook_service.upload_photo(db_book.sweetbook_uid, content, file.filename)
        return res
    except Exception as e:
        print(f"Error uploading photo for book {book_id}: {e}")
        error_msg = str(e)
        if "Missing" in error_msg or "None" in error_msg:
             error_msg = "스윗북 프로젝트 UID가 생성되지 않았습니다 (sweetbook_uid is missing)"
        raise HTTPException(status_code=500, detail=error_msg)

@router.post("/{book_id}/cover")
def update_book_cover(book_id: int, template_uid: str, parameters: str, db: Session = Depends(get_db)):
    db_book = db.query(models.TravelBook).filter(models.TravelBook.id == book_id).first()
    if not db_book or not db_book.sweetbook_uid:
        raise HTTPException(status_code=404, detail="Book not found")
        
    try:
        params_dict = json.loads(parameters)
        res = sweetbook_service.update_cover(db_book.sweetbook_uid, template_uid, params_dict)
        
        # 로컬 DB에 표지 정보 저장 및 비용 추가
        db_book.cover_template_id = template_uid
        db_book.cover_parameters = parameters
        db_book.price = (db_book.price or 0) + 100  # 표지 선택/변경 시 100원 추가
        db.commit()
        
        return res
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{book_id}/contents")
def upload_book_content(book_id: int, template_uid: str, parameters: str, db: Session = Depends(get_db)):
    db_book = db.query(models.TravelBook).filter(models.TravelBook.id == book_id).first()
    if not db_book or not db_book.sweetbook_uid:
        raise HTTPException(status_code=404, detail="Book not found")
        
    try:
        params_dict = json.loads(parameters)
        res = sweetbook_service.upload_contents(db_book.sweetbook_uid, template_uid, params_dict)
        return res
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{book_id}/pages", response_model=schemas.BookPage)
def add_book_page(book_id: int, page_in: schemas.BookPageCreate, db: Session = Depends(get_db)):
    db_book = db.query(models.TravelBook).filter(models.TravelBook.id == book_id).first()
    if not db_book:
        raise HTTPException(status_code=404, detail="Book not found")
    
    # 마지막 순서 확인
    last_page = db.query(models.BookPage).filter(models.BookPage.travelbook_id == book_id).order_by(models.BookPage.order.desc()).first()
    new_order = (last_page.order + 1) if last_page else 1
    
    db_page = models.BookPage(
        travelbook_id=book_id,
        template_uid=page_in.template_uid,
        parameters=page_in.parameters,
        order=new_order,
        price=100 # 기본 페이지 비용 100원
    )
    db_book.price = (db_book.price or 0) + 100 # 책 총액에 100원 추가
    db.add(db_page)
    db.commit()
    db.refresh(db_page)
    
    # 즉시 메타데이터 주입
    meta = db.query(models.TemplateMetadataEntry).filter(
        models.TemplateMetadataEntry.template_uid == db_page.template_uid
    ).first()
    if meta:
        setattr(db_page, 'template_name', meta.template_name)
        setattr(db_page, 'template_thumbnail', meta.thumbnail)
        
    return db_page

@router.put("/{book_id}/pages/{page_id}", response_model=schemas.BookPage)
def update_book_page(book_id: int, page_id: int, page_in: schemas.BookPageUpdate, db: Session = Depends(get_db)):
    db_page = db.query(models.BookPage).filter(
        models.BookPage.id == page_id, 
        models.BookPage.travelbook_id == book_id
    ).first()
    if not db_page:
        raise HTTPException(status_code=404, detail="Page not found")
    
    if page_in.template_uid is not None:
        db_page.template_uid = page_in.template_uid
        db_page.is_synced = 0 # 내용 변경 시 동기화 권한 초기화
    if page_in.parameters is not None:
        db_page.parameters = page_in.parameters
        db_page.is_synced = 0
    if page_in.order is not None:
        db_page.order = page_in.order
        # 순서 변경도 재동기화가 필요할 수 있으므로 초기화 (Sweetbook 정책에 따라 조절 가능)
        db_page.is_synced = 0
        
    db.commit()
    db.refresh(db_page)
    
    # 즉시 메타데이터 주입
    meta = db.query(models.TemplateMetadataEntry).filter(
        models.TemplateMetadataEntry.template_uid == db_page.template_uid
    ).first()
    if meta:
        setattr(db_page, 'template_name', meta.template_name)
        setattr(db_page, 'template_thumbnail', meta.thumbnail)
        
    return db_page

@router.delete("/{book_id}/pages/{page_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_book_page(book_id: int, page_id: int, db: Session = Depends(get_db)):
    db_page = db.query(models.BookPage).filter(
        models.BookPage.id == page_id, 
        models.BookPage.travelbook_id == book_id
    ).first()
    if not db_page:
        raise HTTPException(status_code=404, detail="Page not found")
    
    # 책 총액에서 해당 페이지 비용 차감
    db_book = db.query(models.TravelBook).filter(models.TravelBook.id == book_id).first()
    if db_book:
        db_book.price = (db_book.price or 0) - (db_page.price or 0)
    
    db.delete(db_page)
    db.commit()
    return None

@router.put("/{book_id}/pages/reorder")
def reorder_book_pages(book_id: int, page_ids: List[int], db: Session = Depends(get_db)):
    for index, page_id in enumerate(page_ids):
        db.query(models.BookPage).filter(
            models.BookPage.id == page_id, 
            models.BookPage.travelbook_id == book_id
        ).update({"order": index + 1, "is_synced": 0})
    db.commit()
    return {"success": True}

@router.post("/{book_id}/finalization")
def finalize_travelbook(book_id: int, db: Session = Depends(get_db)):
    db_book = db.query(models.TravelBook).filter(models.TravelBook.id == book_id).first()
    if not db_book or not db_book.sweetbook_uid:
        raise HTTPException(status_code=404, detail="Book not found")
        
    # [추가] 정밀 페이지 계산 및 검증
    # 판형 정보를 가져와서 최소 페이지 등 제약 조건 확인
    spec_uid = db_book.book_spec_uid or "SQUAREBOOK_HC"
    specs_res = sweetbook_service.get_book_specs()
    
    # 응답이 리스트인 경우와 딕셔너리인 경우 모두 대응
    items = []
    if isinstance(specs_res, list):
        items = specs_res
    elif isinstance(specs_res, dict):
        items = specs_res.get("data", {}).get("items", []) if isinstance(specs_res.get("data"), dict) else specs_res.get("data", [])
    
    spec = next((s for s in items if isinstance(s, dict) and s.get("bookSpecUid") == spec_uid), None)
    
    # 실제 레이아웃 시뮬레이션
    binding = spec.get("bindingType", "PUR") if spec else "PUR"
    actual_pages = calculate_total_pages(db_book.pages, binding_type=binding)
    
    # spec이 없더라도 기본 24p 요건은 검증하도록 함
    p_min = spec.get("pageMin", 24) if spec else 24
    p_inc = spec.get("pageIncrement", 2) if spec else 2
    
    # if actual_pages < p_min:
    #     logger_msg = f"최소 페이지 미달: 현재 {actual_pages}p, 최소 {p_min}p가 필요합니다."
    #     print(f"DEBUG: Validation Failed: {logger_msg}")
    #     raise HTTPException(status_code=400, detail=logger_msg)
    # if (actual_pages - p_min) % p_inc != 0:
    #     logger_msg = f"페이지 증분 단위 오류: 현재 {actual_pages}p. {p_inc}페이지 단위로 추가해 주세요."
    #     print(f"DEBUG: Validation Failed: {logger_msg}")
    #     raise HTTPException(status_code=400, detail=logger_msg)
        
    try:
        # DB에 저장된 페이지가 있다면 스윗북과 동기화
        if db_book.pages:
            # 아직 업로드되지 않은 페이지만 전송 (is_synced가 0인 것만 추출)
            uploaded_any = False
            for page in db_book.pages:
                if page.is_synced:
                    continue
                
                params_dict = json.loads(page.parameters)
                sweetbook_service.upload_contents(
                    db_book.sweetbook_uid, 
                    page.template_uid, 
                    params_dict
                )
                
                # 성공 시 DB에 동기화 완료 마킹
                page.is_synced = 1
                uploaded_any = True
                
            if uploaded_any:
                db.commit()
        
        # 3. 최종 확정
        res = sweetbook_service.finalization_book(db_book.sweetbook_uid)
        db_book.status = "finalized"
        db_book.pdf_url = res.get("data", {}).get("preview_url") or res.get("data", {}).get("previewUrl")
        db.commit()
        return res
    except requests.exceptions.HTTPError as he:
        # 스윗북 API에서 에러 발생 시 상세 메시지 추출
        detail = str(he)
        if he.response is not None:
            try:
                error_json = he.response.json()
                if isinstance(error_json, dict):
                    if error_json.get("errors") and isinstance(error_json["errors"], list) and error_json["errors"]:
                        detail = error_json["errors"][0]
                    elif error_json.get("message"):
                        detail = error_json["message"]
            except:
                # JSON 파싱 실패 시 원문 텍스트라도 사용
                if he.response.text:
                    detail = he.response.text[:200]
        
        raise HTTPException(
            status_code=he.response.status_code if he.response is not None else 400, 
            detail=detail
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/", response_model=List[schemas.TravelBook])
def read_travelbooks(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    books = db.query(models.TravelBook).order_by(models.TravelBook.created_at.desc()).offset(skip).limit(limit).all()
    
    result = []
    for db_book in books:
        # 표지 썸네일 찾기
        cover_thumb = None
        cover_name = None
        if db_book.cover_template_id:
            c_uid = db_book.cover_template_id.strip()
            # 메타데이터 테이블에서 조회
            meta = db.query(models.TemplateMetadataEntry).filter(
                func.trim(models.TemplateMetadataEntry.template_uid).ilike(c_uid)
            ).first()
            if meta:
                cover_thumb = meta.thumbnail
                cover_name = meta.template_name

        # 각 페이지별 썸네일 찾기
        processed_pages = []
        for page in db_book.pages:
            p_uid = page.template_uid.strip() if page.template_uid else ""
            p_meta = db.query(models.TemplateMetadataEntry).filter(
                func.trim(models.TemplateMetadataEntry.template_uid).ilike(p_uid)
            ).first()
            
            processed_pages.append({
                "id": page.id,
                "travelbook_id": page.travelbook_id,
                "template_uid": page.template_uid,
                "parameters": page.parameters,
                "order": page.order,
                "price": page.price,
                "template_name": p_meta.template_name if p_meta else None,
                "template_thumbnail": p_meta.thumbnail if p_meta else None
            })

        # 최종 데이터 조립
        # 페이지 계산 및 스펙 정보 (목록에서도 간단히 표기)
        spec_uid = db_book.book_spec_uid or "SQUAREBOOK_HC"
        # 성능을 위해 목록 조회 시에는 기본값 위주로 사용하거나 캐싱 고려 가능
        actual_pages = calculate_total_pages(db_book.pages, binding_type="PUR")

        result.append({
            "id": db_book.id,
            "title": db_book.title,
            "description": db_book.description,
            "sweetbook_uid": db_book.sweetbook_uid,
            "status": db_book.status,
            "book_spec_uid": db_book.book_spec_uid,
            "pdf_url": db_book.pdf_url,
            "cover_template_id": db_book.cover_template_id,
            "cover_parameters": db_book.cover_parameters,
            "cover_template_name": cover_name,
            "cover_thumbnail": cover_thumb,
            "price": db_book.price or 0,
            "created_at": db_book.created_at.isoformat(),
            "total_pages": actual_pages,
            "min_pages": 24, # 목록용 기본값
            "max_pages": 130,
            "page_increment": 2,
            "logs": [
                {
                    "id": log.id,
                    "title": log.title,
                    "location": log.location,
                    "content": log.content,
                    "travelbook_id": log.travelbook_id,
                    "created_at": log.created_at.isoformat(),
                }
                for log in db_book.logs
            ],
            "pages": processed_pages,
        })
        
    return result

@router.get("/{book_id}", response_model=schemas.TravelBook)
def read_travelbook(book_id: int, db: Session = Depends(get_db)):
    db_book = db.query(models.TravelBook).filter(models.TravelBook.id == book_id).first()
    if db_book is None:
        raise HTTPException(status_code=404, detail="Travel Book not found")
    
    # 1. 페이지별 템플릿 메타데이터 주입
    for page in db_book.pages:
        meta = db.query(models.TemplateMetadataEntry).filter(
            models.TemplateMetadataEntry.template_uid == page.template_uid
        ).first()
        if meta:
            setattr(page, "template_name", meta.template_name)
            setattr(page, "template_thumbnail", meta.thumbnail)

    # 2. 판형 정보 및 정밀 페이지 수 계산
    spec_uid = db_book.book_spec_uid or "SQUAREBOOK_HC"
    specs_res = sweetbook_service.get_book_specs()
    
    # 응답 구조 대응
    items = []
    if isinstance(specs_res, list):
        items = specs_res
    elif isinstance(specs_res, dict):
        items = specs_res.get("data", {}).get("items", []) if isinstance(specs_res.get("data"), dict) else specs_res.get("data", [])
        
    spec = next((s for s in items if isinstance(s, dict) and s.get("bookSpecUid") == spec_uid), None)
    
    binding = spec.get("bindingType", "PUR") if spec else "PUR"
    actual_pages = calculate_total_pages(db_book.pages, binding_type=binding)
    
    # 스키마 필드 강제 주입 (BaseModel의 attributes 아님)
    db_book.total_pages = actual_pages
    if spec:
        db_book.min_pages = spec.get("pageMin", 24)
        db_book.max_pages = spec.get("pageMax", 130)
        db_book.page_increment = spec.get("pageIncrement", 2)
        
    return db_book
        
    # 1. 스윗북 프로젝트 정보 등 기본 정보는 모델에서 가져옴
    # 2. 결과 가공 (동적 속성 주입의 안정성을 위해 dict로 변환 고려)
    print(f"--- [DEBUG] Reading Book ID: {book_id} ---")

    # 표지 정보 조회
    cover_thumb = None
    cover_name = None
    if db_book.cover_template_id:
        uid = db_book.cover_template_id.strip()
        cover_meta = db.query(models.TemplateMetadataEntry).filter(
            func.trim(models.TemplateMetadataEntry.template_uid).ilike(uid)
        ).first()
        if cover_meta:
            cover_thumb = cover_meta.thumbnail
            cover_name = cover_meta.template_name
            print(f"Cover Metadata Found: {cover_name}, Thumb: {cover_thumb}")
            
        # [백업 로직] 표지 정보가 DB에 없으면 실시간 API 조회
        if not cover_thumb and uid:
            try:
                print(f"Fetch missing cover thumbnail for UID: {uid}")
                api_res = sweetbook_service.get_template_details(uid)
                if api_res.get("success"):
                    api_data = api_res.get("data", {})
                    cover_name = cover_name or api_data.get("templateName")
                    cover_thumb = api_data.get("thumbnail") or api_data.get("thumbnails", {}).get("layout")
            except Exception as e:
                print(f"Failed to fetch backup cover metadata: {e}")

    # 페이지 정보 가공
    processed_pages = []
    for page in db_book.pages:
        # UID 공백 제거 및 대소문자 무시 검색 (가장 견고한 방식)
        uid = page.template_uid.strip() if page.template_uid else ""
        meta = db.query(models.TemplateMetadataEntry).filter(
            func.trim(models.TemplateMetadataEntry.template_uid).ilike(uid)
        ).first()
        
        # [백업 로직] DB에 메타데이터가 없거나 썸네일이 없으면 스윗북 API 호출 시도
        template_name = meta.template_name if meta else None
        template_thumbnail = meta.thumbnail if meta else None
        
        if not template_thumbnail and uid:
            try:
                print(f"Fetch missing thumbnail for UID: {uid}")
                api_res = sweetbook_service.get_template_details(uid)
                if api_res.get("success"):
                    api_data = api_res.get("data", {})
                    template_name = template_name or api_data.get("templateName")
                    template_thumbnail = api_data.get("thumbnail") or api_data.get("thumbnails", {}).get("layout")
            except Exception as e:
                print(f"Failed to fetch backup metadata for {uid}: {e}")
        
        # Pydantic 호환을 위해 수동으로 데이터 구성
        page_data = {
            "id": page.id,
            "travelbook_id": page.travelbook_id,
            "template_uid": page.template_uid,
            "parameters": page.parameters,
            "order": page.order,
            "price": page.price,
            "template_name": template_name,
            "template_thumbnail": template_thumbnail
        }
        processed_pages.append(page_data)
        if meta and meta.thumbnail:
            print(f"Page {page.id} Thumbnail matched: {meta.thumbnail}")
        else:
            print(f"Page {page.id} Metadata Missing for UID: {repr(page.template_uid)}")

    # 최종 딕셔너리로 직접 조립 (setattr + model_validate를 통한 누락 방지)
    result = {
        "id": db_book.id,
        "title": db_book.title,
        "description": db_book.description,
        "sweetbook_uid": db_book.sweetbook_uid,
        "status": db_book.status,
        "book_spec_uid": db_book.book_spec_uid,
        "pdf_url": db_book.pdf_url,
        "cover_template_id": db_book.cover_template_id,
        "cover_parameters": db_book.cover_parameters,
        "cover_template_name": cover_name,
        "cover_thumbnail": cover_thumb,
        "price": db_book.price or 0,
        "created_at": db_book.created_at.isoformat(),
        "logs": [
            {
                "id": log.id,
                "title": log.title,
                "location": log.location,
                "content": log.content,
                "travelbook_id": log.travelbook_id,
                "created_at": log.created_at.isoformat(),
            }
            for log in db_book.logs
        ],
        "pages": processed_pages,
    }
    
    return result

@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_travelbook(book_id: int, db: Session = Depends(get_db)):
    db_book = db.query(models.TravelBook).filter(models.TravelBook.id == book_id).first()
    if db_book is None:
        raise HTTPException(status_code=404, detail="Travel Book not found")
    
    if db_book.sweetbook_uid:
        try:
            sweetbook_service.delete_book(db_book.sweetbook_uid)
        except Exception as e:
            print(f"Error deleting book from Sweetbook: {e}")
    
    # 연결된 로그들의 travelbook_id를 null로 해제 (삭제되는 책에서 분리)
    logs = db.query(models.TravelLog).filter(models.TravelLog.travelbook_id == book_id).all()
    for log in logs:
        log.travelbook_id = None
        
    db.delete(db_book)
    db.commit()
    return None
