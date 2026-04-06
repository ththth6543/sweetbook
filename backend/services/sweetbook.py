import requests
import json
from typing import List, Dict, Any, Optional
from core.config import settings

class SweetbookService:
    def __init__(self):
        self.base_url = settings.SWEETBOOK_API_BASE_URL
        self.headers = {
            "Authorization": f"Bearer {settings.SWEETBOOK_API_KEY}"
        }

    def _make_request(self, method: str, endpoint: str, **kwargs) -> Dict[str, Any]:
        url = f"{self.base_url}{endpoint}"
        headers = self.headers.copy()
        
        # JSON 요청인 경우 매뉴얼 직렬화 및 Content-Type 설정
        if 'json' in kwargs:
            data = json.dumps(kwargs.pop('json')).encode('utf-8')
            headers["Content-Type"] = "application/json"
            kwargs['data'] = data
            
        # multipart/form-data인 경우 (requests가 자동으로 boundary를 설정하도록 유도)
        elif 'files' in kwargs:
            # Content-Type을 명시적으로 설정하지 않음 (requests가 multipart/form-data로 처리하게 함)
            pass

        try:
            print(f"[{method}] {url} 호출 시도...")
            response = requests.request(method, url, headers=headers, **kwargs)
            
            if not response.ok:
                print(f"Sweetbook API Error ({method} {url}): {response.status_code}")
                print(f"Response Body: '{response.text}'")
            
            response.raise_for_status()
            
            if response.status_code == 204:
                return {}
            return response.json()
        except Exception as e:
            print(f"Request failed: {e}")
            raise

    # 1. 판형 선택 (조회)
    def get_book_specs(self) -> Dict[str, Any]:
        return self._make_request("GET", "/book-specs")

    # 2. 템플릿 선택 (조회)
    def get_templates(self, 
                      book_spec_uid: Optional[str] = None, 
                      template_kind: Optional[str] = None,
                      scope: str = "all",
                      limit: int = 50,
                      offset: int = 0) -> List[Dict[str, Any]]:
        """
        템플릿 목록을 조회합니다.
        """
        params = {
            "scope": scope,
            "limit": limit,
            "offset": offset
        }
        if book_spec_uid:
            params["bookSpecUid"] = book_spec_uid
        if template_kind:
            params["templateKind"] = template_kind
        response = self._make_request("GET", "/templates", params=params)
        data = response.get("data", {})
        
        # 샌드박스 API 응답 구조: {"success": true, "data": {"templates": [...]}}
        if isinstance(data, dict):
            templates = data.get("templates")
            if templates is not None:
                return templates
            return data.get("items", []) # 기존 호환성 유지
            
        return data if isinstance(data, List) else []

    def get_template_details(self, template_uid: str) -> Dict[str, Any]:
        """
        특정 템플릿의 상세 정보(파라미터 정의 등)를 조회합니다.
        """
        return self._make_request("GET", f"/templates/{template_uid}")

    # 3. 책 생성
    def create_book(self, title: str, book_spec_uid: str = "PHOTOBOOK_A5_SC", creation_type: str = "TEST") -> Dict[str, Any]:
        payload = {
            "title": title,
            "bookSpecUid": book_spec_uid,
            "creationType": creation_type
        }
        return self._make_request("POST", "/books", json=payload)

    # 4. 사진 업로드
    def upload_photo(self, book_uid: str, file_content: bytes, filename: str) -> Dict[str, Any]:
        """
        갤러리 템플릿에 사용할 사진을 업로드하고 fileName을 반환받습니다.
        """
        files = {
            "file": (filename, file_content, "image/jpeg")
        }
        return self._make_request("POST", f"/books/{book_uid}/photos", files=files)

    # 5. 표지 추가
    def update_cover(self, book_uid: str, template_uid: str, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """
        책의 표지를 설정합니다.
        """
        form_data = {
            "templateUid": template_uid,
            "parameters": json.dumps(parameters)
        }
        # multipart/form-data 강제를 위해 빈 파일 포함
        dummy_files = {'dummy': ('', b'')}
        return self._make_request("POST", f"/books/{book_uid}/cover", data=form_data, files=dummy_files)

    # 6. 내지 추가
    def upload_contents(self, book_uid: str, template_uid: str, parameters: Dict[str, Any]) -> Dict[str, Any]:
        form_data = {
            "templateUid": template_uid,
            "parameters": json.dumps(parameters)
        }
        dummy_files = {'dummy': ('', b'')}
        return self._make_request("POST", f"/books/{book_uid}/contents", data=form_data, files=dummy_files)

    # 7. 최종화 (Finalization)
    def finalization_book(self, book_uid: str) -> Dict[str, Any]:
        """
        제작 데이터를 고정하고 주문 가능한 상태로 전환합니다.
        """
        return self._make_request("POST", f"/books/{book_uid}/finalization")

    # 8. 견적 조회
    def get_order_estimate(self, book_uid: str, quantity: int = 1) -> Dict[str, Any]:
        payload = {
            "items": [
                {"bookUid": book_uid, "quantity": quantity}
            ]
        }
        return self._make_request("POST", "/orders/estimate", json=payload)

    # 9. 주문 생성
    def create_order(self, book_uid: str, quantity: int, shipping_info: Dict[str, Any]) -> Dict[str, Any]:
        """
        실제 주문을 생성하고 충전금을 차감합니다.
        shipping_info 예시: recipientName, recipientPhone, postalCode, address1, address2
        """
        payload = {
            "items": [
                {"bookUid": book_uid, "quantity": quantity}
            ],
            "shipping": shipping_info
        }
        return self._make_request("POST", "/orders", json=payload)

    def get_bulk_order_estimate(self, items: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        여러 도서에 대한 주문 견적을 조회합니다.
        items 예시: [{"bookUid": "...", "quantity": 1}, ...]
        """
        payload = {"items": items}
        return self._make_request("POST", "/orders/estimate", json=payload)

    def create_bulk_order(self, items: List[Dict[str, Any]], shipping_info: Dict[str, Any]) -> Dict[str, Any]:
        """
        여러 권의 도서를 묶어서 한 번에 주문합니다.
        """
        payload = {
            "items": items,
            "shipping": shipping_info
        }
        return self._make_request("POST", "/orders", json=payload)

    def get_orders(self, limit: int = 50, offset: int = 0) -> Dict[str, Any]:
        """
        계정의 전체 주문 목록을 조회합니다.
        """
        params = {"limit": limit, "offset": offset}
        return self._make_request("GET", "/orders", params=params)

    def get_order_details(self, order_uid: str) -> Dict[str, Any]:
        """
        특정 주문의 상세 상세 정보를 조회합니다.
        """
        return self._make_request("GET", f"/orders/{order_uid}")

    def delete_book(self, book_uid: str) -> Dict[str, Any]:
        """
        스윗북 서버에서 책 프로젝트를 삭제합니다.
        """
        return self._make_request("DELETE", f"/books/{book_uid}")

    # 10. 웹훅 설정
    def configure_webhook(self, webhook_url: str, events: Optional[List[str]] = None) -> Dict[str, Any]:
        payload = {
            "webhookUrl": webhook_url,
            "events": events,
            "description": "My Travel Book Order Webhook"
        }
        return self._make_request("PUT", "/webhooks/config", json=payload)

    def get_book_details(self, book_uid: str) -> Dict[str, Any]:
        return self._make_request("GET", f"/books/{book_uid}")

    def get_credits(self) -> Dict[str, Any]:
        """
        현재 연동된 계정의 충전금 잔액을 조회합니다.
        """
        return self._make_request("GET", "/credits")

    def get_credit_transactions(self, limit: int = 20, offset: int = 0) -> Dict[str, Any]:
        """
        계정의 크레딧 거래 내역을 조회합니다.
        """
        params = {"limit": limit, "offset": offset}
        return self._make_request("GET", "/credits/transactions", params=params)

    def sandbox_charge(self, amount: int, memo: str = "테스트 충전") -> Dict[str, Any]:
        """
        [SANDBOX 전용] 테스트 목적으로 크레딧을 충전합니다.
        """
        payload = {"amount": amount, "memo": memo}
        return self._make_request("POST", "/credits/sandbox/charge", json=payload)

    def sandbox_deduct(self, amount: int, memo: str = "테스트 차감") -> Dict[str, Any]:
        """
        [SANDBOX 전용] 테스트 목적으로 크레딧을 차감합니다.
        """
        payload = {"amount": amount, "memo": memo}
        return self._make_request("POST", "/credits/sandbox/deduct", json=payload)

sweetbook_service = SweetbookService()
