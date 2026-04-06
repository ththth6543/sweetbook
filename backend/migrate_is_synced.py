import sqlite3
import os

db_path = os.path.join(os.getcwd(), "my_travelbook.db")

def migrate():
    if not os.path.exists(db_path):
        print(f"Database not found at {db_path}")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    try:
        # 컬럼 존재 여부 확인
        cursor.execute("PRAGMA table_info(bookpages)")
        columns = [col[1] for col in cursor.fetchall()]
        
        if "is_synced" not in columns:
            print("Adding 'is_synced' column to 'bookpages' table...")
            cursor.execute("ALTER TABLE bookpages ADD COLUMN is_synced BOOLEAN DEFAULT 0")
            conn.commit()
            print("Successfully added 'is_synced' column.")
        else:
            print("'is_synced' column already exists.")
            
    except Exception as e:
        print(f"Error during migration: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()
