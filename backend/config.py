"""Configuración del backend. Todo sale del archivo .env (o de variables de entorno)."""
import os
import secrets
from dotenv import load_dotenv
from pymysql.cursors import DictCursor

load_dotenv()

SECRET_KEY = os.getenv('SECRET_KEY') or secrets.token_hex(32)
CORS_ORIGINS = os.getenv('CORS_ORIGINS', '*')
PORT = int(os.getenv('PORT', '5000'))

# Datos de conexión a MariaDB (XAMPP). La base se llama stockcrate.
DB = {
    'host': os.getenv('DB_HOST', '127.0.0.1'),
    'port': int(os.getenv('DB_PORT', '3306')),
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', ''),
    'database': os.getenv('DB_NAME', 'stockcrate'),
    'charset': 'utf8mb4',
    'cursorclass': DictCursor,
    'autocommit': False,
}

# Cuánto dura la sesión después de iniciar sesión
HORAS_SESION = 8
