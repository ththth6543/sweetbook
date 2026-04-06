import json
from sqlalchemy.orm import Session
from db.database import SessionLocal
from db import models

def seed_templates():
    db = SessionLocal()
    templates = [
        {
            "template_uid": "Rb0vtvfx7eaf",
            "template_name": "SQUAREBOOK_HC 본문 2",
            "template_kind": "content",
            "thumbnail": "https://img.sweetbook.com/img/templates/SquareBook_HC_Contents_02.jpg",
            "parameter_definitions": [
                {
                    "key": "photo",
                    "label": "① 사진을 넣어주세요",   
                    "type": "image"
                }
            ]
        },
        {
            "template_uid": "6juocTzGnh5l",
            "template_name": "SQUAREBOOK_HC 본문",
            "template_kind": "content",
            "thumbnail": "https://img.sweetbook.com/img/templates/SquareBook_HC_Contents_01.jpg",
            "parameter_definitions": [
                {
                    "key": "photo1",
                    "label": "① 사진을 넣어주세요",
                    "type": "image"
                },
                {
                    "key": "photo2",
                    "label": "② 사진을 넣어주세요",
                    "type": "image"
                },
                {
                    "key": "photo3",
                    "label": "③ 사진을 넣어주세요",
                    "type": "image"
                },
                {
                    "key": "photo4",
                    "label": "④ 사진을 넣어주세요",
                    "type": "image"
                },
                {
                    "key": "photo5",
                    "label": "⑤ 사진을 넣어주세요",
                    "type": "image"
                },
                {
                    "key": "photo6",
                    "label": "⑥ 사진을 넣어주세요",
                    "type": "image"
                }
            ]
        },
        {
            "template_uid": "65fVe8zLOjZe",
            "template_name": "빈 내지",
            "template_kind": "content",
            "thumbnail": "https://img.sweetbook.com/img/templates/Empty_Page.jpg",
            "parameter_definitions": [
                {
                    "label": "빈 내지입니다.",
                },
            ]
        },
        {
            "template_uid": "5aZ14XP46ZRC",
            "template_name": "발행면",
            "template_kind": "publish",
            "thumbnail": "https://img.sweetbook.com/img/templates/Publish_Page.jpg",
            "parameter_definitions": [
                {
                    "key": "photo",
                    "label": "① 사진을 넣어주세요",   
                    "type": "image"
                },
                {
                    "key": "title",
                    "label": "② 제목을 넣어주세요",
                    "type": "text"
                },
                {
                    "key": "publishDate",
                    "label": "③ 발행일을 넣어주세요",
                    "type": "text",
                    "hint": "2026.04.01"
                },
                {
                    "key": "author",
                    "label": "④ 저자를 넣어주세요",
                    "type": "text"
                },
                {
                    "key": "publisher",
                    "label": "⑤ 발행사를 넣어주세요",
                    "type": "text"
                },
            ]
        },
        {
            "template_uid": "6o2ZRPsaurK1",
            "template_name": "간지-보라",
            "template_kind": "divider",
            "thumbnail": "https://img.sweetbook.com/img/templates/Publish_Page.jpg",
            "parameter_definitions": [
                {
                    "key": "yearMonthDayTitle",
                    "label": "① 여행간 날짜를 넣어주세요",   
                    "type": "text",
                    "hint": "2026.04.01"
                },
                {
                    "key": "location",
                    "label": "② 여행지를 넣어주세요",
                    "type": "text"
                },
            ]
        },
        {
            "template_uid": "5PbuiKDuDRQ2",
            "template_name": "간지-로즈",
            "template_kind": "divider",
            "thumbnail": "https://img.sweetbook.com/img/templates/Publish_Page.jpg",
            "parameter_definitions": [
                {
                    "key": "yearMonthDayTitle",
                    "label": "① 여행간 날짜를 넣어주세요",   
                    "type": "text",
                    "hint": "2026.04.01"
                },
                {
                    "key": "location",
                    "label": "② 여행지를 넣어주세요",
                    "type": "text"
                },
            ]
        },
        {
            "template_uid": "yrmDCt0PgJp9",
            "template_name": "겉표지",
            "template_kind": "cover",
            "thumbnail": "https://img.sweetbook.com/img/templates/Publish_Page.jpg",
            "parameter_definitions": [
                {
                    "key": "dateRange",
                    "label": "① 여행간 날짜를 넣어주세요",   
                    "type": "text",
                    "hint": "2026.04.01 ~ 2026.04.01"
                },
                {
                    "key": "title",
                    "label": "② 책 제목을 넣어주세요",
                    "type": "text"
                },
                {
                    "key": "coverPhoto",
                    "label": "③ 표지 사진을 넣어주세요",   
                    "type": "image"
                },
            ]
        },
    ]
    
    for t in templates:
        params_json = json.dumps(t["parameter_definitions"])
        
        # 이미 존재하는지 확인
        db_meta = db.query(models.TemplateMetadataEntry).filter(
            models.TemplateMetadataEntry.template_uid == t["template_uid"]
        ).first()
        
        if db_meta:
            # 업데이트: 이름, 종류, 파라미터는 업데이트하되 
            # 썸네일은 이미 DB에 값이 있고 새로 넣으려는 값이 플레이스홀더 성격이면 유지함
            db_meta.template_name = t["template_name"]
            db_meta.template_kind = t["template_kind"]
            db_meta.parameter_definitions = params_json
            db_meta.thumbnail = t.get("thumbnail")  # 항상 최신값으로 업데이트
                
            print(f"Updated: {t['template_uid']} ({t['template_name']}) thumb={db_meta.thumbnail}")
        else:
            # 신규 삽입
            db_meta = models.TemplateMetadataEntry(
                template_uid=t["template_uid"],
                template_name=t["template_name"],
                template_kind=t["template_kind"],
                thumbnail=t.get("thumbnail"),
                parameter_definitions=params_json
            )
            db.add(db_meta)
            print(f"Added: {t['template_uid']} ({t['template_name']})")
            
    db.commit()
    db.close()
    print("Seeding complete. Custom parameter definitions restored while keeping synced thumbnails.")

if __name__ == "__main__":
    seed_templates()
