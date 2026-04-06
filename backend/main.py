from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from db import models
from db.database import engine
from api import books, orders
from core.config import settings

# Create database tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.PROJECT_NAME)

# Set up CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # 또는 ["http://localhost:5000", "http://127.0.0.1:5000", ...]
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Include Router
app.include_router(books.router, prefix=settings.API_V1_STR)
app.include_router(orders.router, prefix=settings.API_V1_STR)

@app.get("/")
def read_root():
    return {"message": "My Travel Book API is running"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
