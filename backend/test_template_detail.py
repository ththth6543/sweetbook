import sys
import os
import json

# Add the current directory to sys.path to import local modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from services.sweetbook import sweetbook_service

def test_get_template_details(template_uid: str):
    print(f"--- 템플릿 상세 정보 조회 시작 (UID: {template_uid}) ---")
    try:
        details = sweetbook_service.get_template_details(template_uid)
        
        # 결과를 보기 좋게 출력
        print(json.dumps(details, indent=2, ensure_ascii=False))
        
        # 주요 정보 요약 출력
        if "data" in details:
            data = details["data"]
            print("\n--- 주요 정보 요약 ---")
            print(f"템플릿 이름: {data.get('name')}")
            print(f"UID: {data.get('uid')}")
            print(f"판형 UID: {data.get('bookSpecUid')}")
            print(f"레이아웃 규칙 수: {len(data.get('layoutRules', []))}")
            print(f"베이스 레이어 수: {len(data.get('baseLayers', []))}")
            print(f"파라미터 정의 수: {len(data.get('parameterDefinitions', {}))}")
            
    except Exception as e:
        print(f"에러 발생: {e}")

if __name__ == "__main__":
    # 사용자가 요청한 템플릿 UID
    target_template_uid = "4MY2fokVjkeY"
    test_get_template_details(target_template_uid)
