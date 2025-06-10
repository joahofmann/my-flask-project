from flask import Flask
import os
import psycopg2
from psycopg2 import OperationalError

app = Flask(__name__)

@app.route('/')
def hello_world():
    return '<h1>Hello, World from Flask!</h1><p>Running with Gunicorn and Nginx on Google Cloud.</p>'

@app.route('/db_test')
def db_test():
    db_host = os.environ.get('DB_HOST')
    db_name = os.environ.get('DB_NAME')
    db_user = os.environ.get('DB_USER')
    db_password = os.environ.get('DB_PASSWORD')

    if not all([db_host, db_name, db_user, db_password]):
        return "<h1>Database Test Failed</h1><p>Database environment variables (DB_HOST, DB_NAME, DB_USER, DB_PASSWORD) are not set.</p>"

    conn = None
    try:
        conn = psycopg2.connect(
            host=db_host,
            database=db_name,
            user=db_user,
            password=db_password
        )
        cur = conn.cursor()
        cur.execute('SELECT version();')
        db_version = cur.fetchone()[0]
        cur.close()
        return f"<h1>Database Test Succeeded!</h1><p>Connected to PostgreSQL version: {db_version}</p>"
    except OperationalError as e:
        return f"<h1>Database Test Failed</h1><p>Could not connect to database: {e}</p>"
    except Exception as e:
        return f"<h1>An unexpected error occurred:</h1><p>{e}</p>"
    finally:
        if conn:
            conn.close()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(debug=True, host='0.0.0.0', port=port)
