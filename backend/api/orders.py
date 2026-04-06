from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Dict, Any
from pydantic import BaseModel, Field
import requests
import json
import math
from db.database import get_db
from db import models, schemas
from services.sweetbook import sweetbook_service

class OrderItemReq(BaseModel):
    book_id: int
    quantity: int = Field(..., ge=1, le=100)

class BulkEstimateRequest(BaseModel):
    items: List[OrderItemReq]

class BulkOrderRequest(BaseModel):
    items: List[OrderItemReq]
    shipping: Dict[str, Any]

class SandboxCreditRequest(BaseModel):
    amount: int = Field(..., gt=0)
    memo: str = "테스트 충전"

router = APIRouter(
    prefix="/orders",
    tags=["Orders"]
)

def _parse_sweetbook_error(he: requests.exceptions.HTTPError) -> str:
    """스윗북 API 에러 응답에서 구체적인 사유를 추출합니다."""
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
            if he.response.text:
                detail = he.response.text[:200]
    return detail

def _calculate_price_breakdown(items_sum: int, shipping_fee: int = 3000) -> Dict[str, int]:
    """
    공급가액, 부가세(10%), 배송비 및 합계를 계산합니다.
    부가세는 책값(items_sum)에 대해서만 10% 추가됩니다.
    """
    subtotal = items_sum
    vat = math.floor(subtotal * 0.1)
    total_product = subtotal + vat
    grand_total = total_product + shipping_fee
    
    return {
        "subtotal": subtotal,
        "vat": vat,
        "totalProductAmount": total_product,
        "shippingFee": shipping_fee,
        "totalAmount": grand_total
    }

@router.post("/estimate")
def get_order_estimate(book_id: int, quantity: int = 1, db: Session = Depends(get_db)):
    """특정 책에 대한 주문 견적을 조회합니다."""
    if not (1 <= quantity <= 100):
        raise HTTPException(status_code=400, detail="주문 수량은 1권에서 100권 사이여야 합니다.")
    
    db_book = db.query(models.TravelBook).filter(models.TravelBook.id == book_id).first()
    if not db_book or not db_book.sweetbook_uid:
        raise HTTPException(status_code=404, detail="Travel Book not found or not synchronized")
    
    try:
        estimate = sweetbook_service.get_order_estimate(db_book.sweetbook_uid, quantity)
        
        # 상세 가격 계산 (책 기본가 * 수량)
        items_sum = (db_book.price or 0) * quantity
        breakdown = _calculate_price_breakdown(items_sum)
        
        if "data" in estimate:
            # 기존 필드 및 상세 필드 주입
            estimate["data"].update(breakdown)
            # 호환성 필드
            estimate["data"]["totalPrice"] = breakdown["totalAmount"]
            
        return estimate
    except requests.exceptions.HTTPError as he:
        raise HTTPException(status_code=he.response.status_code if he.response else 400, detail=_parse_sweetbook_error(he))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/")
def create_order(book_id: int, quantity: int, shipping: Dict[str, Any], db: Session = Depends(get_db)):
    """실제 주문을 생성하고 충전금을 차감합니다."""
    if not (1 <= quantity <= 100):
        raise HTTPException(status_code=400, detail="주문 수량은 1권에서 100권 사이여야 합니다.")
    
    db_book = db.query(models.TravelBook).filter(models.TravelBook.id == book_id).first()
    if not db_book or not db_book.sweetbook_uid:
        raise HTTPException(status_code=404, detail="Travel Book not found or not synchronized")
    
    try:
        order = sweetbook_service.create_order(db_book.sweetbook_uid, quantity, shipping)
        return order
    except requests.exceptions.HTTPError as he:
        raise HTTPException(status_code=he.response.status_code if he.response else 400, detail=_parse_sweetbook_error(he))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/bulk-estimate")
def get_bulk_order_estimate(req: BulkEstimateRequest, db: Session = Depends(get_db)):
    sweetbook_items = []
    items_sum = 0
    for item in req.items:
        db_book = db.query(models.TravelBook).filter(models.TravelBook.id == item.book_id).first()
        if not db_book or not db_book.sweetbook_uid:
            raise HTTPException(status_code=404, detail=f"Book {item.book_id} not found or not synchronized")
        sweetbook_items.append({"bookUid": db_book.sweetbook_uid, "quantity": item.quantity})
        items_sum += (db_book.price or 0) * item.quantity
        
    try:
        estimate = sweetbook_service.get_bulk_order_estimate(sweetbook_items)
        breakdown = _calculate_price_breakdown(items_sum)
        
        if "data" in estimate:
            estimate["data"].update(breakdown)
            estimate["data"]["totalPrice"] = breakdown["totalAmount"]
        return estimate
    except requests.exceptions.HTTPError as he:
        raise HTTPException(status_code=he.response.status_code if he.response else 400, detail=_parse_sweetbook_error(he))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/bulk")
def create_bulk_order(req: BulkOrderRequest, db: Session = Depends(get_db)):
    sweetbook_items = []
    for item in req.items:
        db_book = db.query(models.TravelBook).filter(models.TravelBook.id == item.book_id).first()
        if not db_book or not db_book.sweetbook_uid:
            raise HTTPException(status_code=404, detail=f"Book {item.book_id} not found or not synchronized")
        sweetbook_items.append({"bookUid": db_book.sweetbook_uid, "quantity": item.quantity})
        
    try:
        order = sweetbook_service.create_bulk_order(sweetbook_items, req.shipping)
        return order
    except requests.exceptions.HTTPError as he:
        raise HTTPException(status_code=he.response.status_code if he.response else 400, detail=_parse_sweetbook_error(he))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/")
def get_orders(limit: int = 50, offset: int = 0, db: Session = Depends(get_db)):
    try:
        orders_res = sweetbook_service.get_orders(limit, offset)
        if orders_res.get("success") and "data" in orders_res:
            data = orders_res["data"]
            orders_list = data.get("orders", []) if isinstance(data, dict) else (data if isinstance(data, list) else [])
            for order in orders_list:
                # 주문 목록에서도 총액 보정
                items = order.get("items", [])
                items_sum = 0
                for item in items:
                    book_uid = item.get("bookUid")
                    qty = item.get("quantity") or 1
                    db_book = db.query(models.TravelBook).filter(models.TravelBook.sweetbook_uid == book_uid).first()
                    unit_p = db_book.price if db_book else 1000
                    items_sum += unit_p * qty
                
                breakdown = _calculate_price_breakdown(items_sum)
                order.update(breakdown)
                # totalPrice 필드 유지
                order["totalPrice"] = breakdown["totalAmount"]
        return orders_res
    except requests.exceptions.HTTPError as he:
        raise HTTPException(status_code=he.response.status_code if he.response else 400, detail=_parse_sweetbook_error(he))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/credits")
def get_account_credits():
    try:
        credits_info = sweetbook_service.get_credits()
        return credits_info
    except requests.exceptions.HTTPError as he:
        raise HTTPException(status_code=he.response.status_code if he.response else 400, detail=_parse_sweetbook_error(he))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))

@router.get("/credits/transactions")
def get_credit_transactions(limit: int = 20, offset: int = 0):
    try:
        transactions = sweetbook_service.get_credit_transactions(limit, offset)
        return transactions
    except requests.exceptions.HTTPError as he:
        raise HTTPException(status_code=he.response.status_code if he.response else 400, detail=_parse_sweetbook_error(he))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/credits/sandbox/charge")
def sandbox_credit_charge(req: SandboxCreditRequest):
    try:
        res = sweetbook_service.sandbox_charge(req.amount, req.memo)
        return res
    except requests.exceptions.HTTPError as he:
        raise HTTPException(status_code=he.response.status_code if he.response else 400, detail=_parse_sweetbook_error(he))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/credits/sandbox/deduct")
def sandbox_credit_deduct(req: SandboxCreditRequest):
    try:
        res = sweetbook_service.sandbox_deduct(req.amount, req.memo)
        return res
    except requests.exceptions.HTTPError as he:
        raise HTTPException(status_code=he.response.status_code if he.response else 400, detail=_parse_sweetbook_error(he))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/webhook")
def configure_webhook(webhook_url: str, events: List[str] = None):
    try:
        config = sweetbook_service.configure_webhook(webhook_url, events)
        return config
    except requests.exceptions.HTTPError as he:
        raise HTTPException(status_code=he.response.status_code if he.response else 400, detail=_parse_sweetbook_error(he))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{order_uid}")
def get_order_details(order_uid: str, db: Session = Depends(get_db)):
    try:
        res = sweetbook_service.get_order_details(order_uid)
        if res.get("success") and "data" in res:
            order = res["data"]
            items = order.get("items", [])
            items_sum = 0
            for item in items:
                book_uid = item.get("bookUid")
                qty = item.get("quantity") or 1
                db_book = db.query(models.TravelBook).filter(models.TravelBook.sweetbook_uid == book_uid).first()
                if db_book:
                    unit_p = db_book.price or 0
                    item["bookTitle"] = db_book.title # 실제 책 제목 주입
                    item["unitPrice"] = unit_p
                    item["itemAmount"] = unit_p * qty
                    items_sum += item["itemAmount"]
                else:
                    item["bookTitle"] = "트래블북"
                    items_sum += 1000 * qty
            
            breakdown = _calculate_price_breakdown(items_sum)
            order.update(breakdown)
            order["totalPrice"] = breakdown["totalAmount"] # 호환성
            
        return res
    except requests.exceptions.HTTPError as he:
        raise HTTPException(status_code=he.response.status_code if he.response else 400, detail=_parse_sweetbook_error(he))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
