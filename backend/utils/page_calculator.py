import json
from typing import List, Dict, Any

def calculate_total_pages(pages: List[Any], binding_type: str = 'PUR') -> int:
    """
    스윗북의 Special Page Rules를 시뮬레이션하여 최종 인쇄 페이지 수를 계산합니다.
    
    :param pages: db_book.pages 리스트 (각 객체는 template_kind와 parameters를 가짐)
    :param binding_type: 제본 방식 (PUR인 경우 첫 페이지가 1p-Right에서 시작)
    :return: 최종 페이지 번호 (pagenum * 2)
    """
    if not pages:
        return 0

    # 초기 상태: 0번 시트의 오른쪽 면에서 시작한다고 가정하면, 
    # 첫 번째 배치는 1번 시트의 오른쪽(Right) 면이 됨 (PUR 제본 특징)
    current_pagenum = 0
    current_side = 'right' # pagenum=0의 right (다음 배치는 pagenum=1, side=right)

    for i, page in enumerate(pages):
        # 1. 템플릿 종류 및 파라미터 파싱
        # page 객체가 SQLAlchemy 모델일 수도 있고 Dict일 수도 있으므로 호환성 유지
        template_kind = getattr(page, 'template_kind', 'content')
        if not template_kind:
            template_kind = 'content'
            
        params_str = getattr(page, 'parameters', '{}')
        params = json.loads(params_str) if isinstance(params_str, str) else params_str
        
        # pageSide 옵션 (left/right/auto)
        req_side = params.get('pageSide', 'auto')

        # 2. 배치 시뮬레이션
        if template_kind == 'content':
            # 일반 내지는 Flow 엔진에 의해 자연스럽게 다음 면에 배치됨
            if i == 0 and binding_type == 'PUR':
                # 첫 번째 페이지는 무조건 1p-Right
                current_pagenum = 1
                current_side = 'right'
            else:
                # 일반적인 흐름: Right -> (Next Sheet) Left -> Right
                if current_side == 'right':
                    current_pagenum += 1
                    current_side = 'left'
                else:
                    current_side = 'right'
        
        else: # divider (간지) 또는 publish (발행면)
            # 특수 페이지는 독립 페이지로 취급되며 pageSide를 엄격히 따름
            if i == 0 and binding_type == 'PUR':
                if req_side == 'left':
                    # 1p-Right를 건너뛰고 2p-Left에 배치
                    current_pagenum = 2
                    current_side = 'left'
                else: # auto / right
                    current_pagenum = 1
                    current_side = 'right'
            else:
                # 기존 커서 위치에서 이동 계산
                if req_side == 'left':
                    # 항상 다음 시트의 왼쪽으로 이동
                    current_pagenum += 1
                    current_side = 'left'
                elif req_side == 'right':
                    if current_side == 'left':
                        # 같은 시트의 오른쪽으로 이동
                        current_side = 'right'
                    else: # current_side == 'right'
                        # 다음 시트의 오른쪽으로 이동 (중간 Left는 빈 페이지)
                        current_pagenum += 1
                        current_side = 'right'
                else: # auto
                    # 다음 가용한 면에 배치
                    if current_side == 'right':
                        current_pagenum += 1
                        current_side = 'left'
                    else:
                        current_side = 'right'

    # 최종 페이지 수는 마지막 시트 번호의 2배 (양면 기준)
    # 마지막 면이 Left에서 끝났더라도 실제 제본 시에는 짝을 맞추기 위해 Right면까지 포함함
    return current_pagenum * 2

if __name__ == "__main__":
    # 간단한 테스트 시나리오
    class MockPage:
        def __init__(self, kind, params="{}"):
            self.template_kind = kind
            self.parameters = params

    test_pages = [
        MockPage('content'), # 1p Right
        MockPage('content'), # 2p Left
        MockPage('divider', '{"pageSide": "right"}'), # 2p Right
        MockPage('content'), # 3p Left
    ]
    print(f"Total Pages: {calculate_total_pages(test_pages)}") # 예시: 6p (3시트)
