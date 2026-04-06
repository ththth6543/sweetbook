from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "My Travel Book"
    API_V1_STR: str = "/api/v1"
    
    # SQLite
    DATABASE_URL: str = "sqlite:///./my_travelbook.db"
    
    # Sweetbook API
    SWEETBOOK_API_BASE_URL: str = "https://api-sandbox.sweetbook.com/v1"
    SWEETBOOK_API_KEY: str = "" # .env 파일에서 로드됨
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True
    )

settings = Settings()
