from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from db.database import get_db
from db import models, schemas

router = APIRouter(
    prefix="/logs",
    tags=["Travel Logs"]
)

@router.post("/", response_model=schemas.TravelLog, status_code=status.HTTP_201_CREATED)
def create_log(log: schemas.TravelLogCreate, db: Session = Depends(get_db)):
    db_log = models.TravelLog(**log.dict())
    db.add(db_log)
    db.commit()
    db.refresh(db_log)
    return db_log

@router.get("/", response_model=List[schemas.TravelLog])
def read_logs(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    logs = db.query(models.TravelLog).offset(skip).limit(limit).all()
    return logs

@router.get("/{log_id}", response_model=schemas.TravelLog)
def read_log(log_id: int, db: Session = Depends(get_db)):
    db_log = db.query(models.TravelLog).filter(models.TravelLog.id == log_id).first()
    if db_log is None:
        raise HTTPException(status_code=404, detail="Travel Log not found")
    return db_log

@router.delete("/{log_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_log(log_id: int, db: Session = Depends(get_db)):
    db_log = db.query(models.TravelLog).filter(models.TravelLog.id == log_id).first()
    if db_log is None:
        raise HTTPException(status_code=404, detail="Travel Log not found")
    db.delete(db_log)
    db.commit()
    return None
