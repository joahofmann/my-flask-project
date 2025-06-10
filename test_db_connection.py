# test_db_connection.py
import psycopg2
from psycopg2 import OperationalError
import os

# --- Database Connection Details ---
# IMPORTANT: Replace these placeholders with your actual values.
# You can get YOUR_CLOUD_SQL_PUBLIC_IP from the output of your deploy_vm.sh script.
# YOUR_FLASK_DB_PASSWORD is the password you set in deploy_vm.sh and setup_nginx_gunicorn.sh.

DB_HOST = "34.9.236.250"
DB_NAME = "my_flask_db"
DB_USER = "flask_user"
DB_PASSWORD = "FlaskAppSecurePass#Abc"

# Alternatively, if you have these set as environment variables in Cloud Shell:
# DB_HOST = os.environ.get('DB_HOST')
# DB_NAME = os.environ.get('DB_NAME')
# DB_USER = os.environ.get('DB_USER')
# DB_PASSWORD = os.environ.get('DB_PASSWORD')


def test_connection():
    conn = None
    try:
        print(f"Attempting to connect to database '{DB_NAME}' on host '{DB_HOST}' with user '{DB_USER}'...")
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        cur = conn.cursor()
        cur.execute('SELECT version();')
        db_version = cur.fetchone()[0]
        cur.close()
        print("\n--- Connection Successful! ---")
        print(f"Connected to PostgreSQL version: {db_version}")

        # Example: Fetching messages from the 'messages' table
        print("\n--- Fetching messages (if 'messages' table exists) ---")
        try:
            cur = conn.cursor()
            cur.execute('SELECT id, content, created_at FROM messages ORDER BY created_at DESC LIMIT 5;')
            messages = cur.fetchall()
            if messages:
                print("Found messages:")
                for msg_id, content, created_at in messages:
                    print(f"  ID: {msg_id}, Content: '{content}', Created At: {created_at}")
            else:
                print("No messages found in the 'messages' table.")
        except OperationalError as e:
            print(f"Warning: Could not query 'messages' table. It might not exist or there's a permissions issue: {e}")
        finally:
            if cur:
                cur.close()


    except OperationalError as e:
        print("\n--- Connection Failed! ---")
        print(f"Error: Could not connect to database. Check your connection details and IP authorization.")
        print(f"Details: {e}")
    except Exception as e:
        print("\n--- An unexpected error occurred! ---")
        print(f"Error: {e}")
    finally:
        if conn:
            conn.close()
            print("\nDatabase connection closed.")

if __name__ == "__main__":
    test_connection()

