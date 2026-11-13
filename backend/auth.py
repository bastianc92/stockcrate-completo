"""Inicio de sesión, tokens y permisos por rol."""
import secrets
from datetime import datetime, timedelta
from functools import wraps
from flask import Blueprint, request, jsonify, g
from werkzeug.security import check_password_hash
from config import HORAS_SESION
from db import consultar_uno
from helpers import error, datos

bp = Blueprint('auth', __name__)

# Los tokens se guardan en memoria: sirve para desarrollo local, pero
# se pierden si se reinicia el servidor (hay que volver a iniciar sesión)
TOKENS = {}


def usuario_del_token():
    cabecera = request.headers.get('Authorization', '')
    token = cabecera[7:] if cabecera.startswith('Bearer ') else ''
    sesion = TOKENS.get(token)
    if not sesion or sesion['vence'] < datetime.utcnow():
        return None
    return sesion['usuario']


def requiere_login(rol=None):
    """Decorador para las rutas. Sin argumento basta con estar logueado;
    con rol='ADMIN' solo deja pasar a los administradores."""
    def decorador(funcion):
        @wraps(funcion)
        def envoltura(*args, **kwargs):
            usuario = usuario_del_token()
            if not usuario:
                return error('Sesión inválida o vencida. Inicia sesión nuevamente.', 401)
            if rol and usuario['rol'] != rol:
                return error('No tienes permisos para realizar esta operación.', 403)
            g.usuario = usuario
            return funcion(*args, **kwargs)
        return envoltura
    return decorador


def clave_correcta(guardada, escrita):
    # La tabla usuarios tiene password varchar(20), así que las claves de
    # prueba están en texto plano. También acepto un hash por si más adelante
    # el profesor aprueba ampliar la columna.
    try:
        if check_password_hash(guardada, escrita):
            return True
    except (ValueError, TypeError):
        pass
    return secrets.compare_digest(guardada, escrita)


@bp.post('/auth/login')
def login():
    d = datos()
    correo = str(d.get('correo', '')).strip().lower()
    password = str(d.get('password', ''))
    if not correo or not password:
        return error('Ingresa correo y contraseña.')

    try:
        usuario = consultar_uno('''
            SELECT u.id_usuario, u.nombres, u.apellido_paterno, u.apellido_materno,
                   u.correo, u.password, u.estado, r.nombre AS rol
            FROM usuarios u JOIN roles r ON r.id_rol = u.id_rol
            WHERE LOWER(u.correo) = %s LIMIT 1''', (correo,))
    except Exception:
        return error('No se pudo validar el usuario. Verifica la configuración de la base de datos.', 503)

    if not usuario or not usuario['estado'] or not clave_correcta(usuario['password'] or '', password):
        return error('Correo o contraseña incorrectos.', 401)

    partes = [usuario['nombres'], usuario['apellido_paterno'], usuario['apellido_materno']]
    sesion = {
        'id_usuario': usuario['id_usuario'],
        'correo': usuario['correo'],
        'nombre': ' '.join(p for p in partes if p),
        'rol': usuario['rol'].upper(),
    }
    token = secrets.token_urlsafe(32)
    TOKENS[token] = {'usuario': sesion, 'vence': datetime.utcnow() + timedelta(hours=HORAS_SESION)}
    return jsonify({'token': token, **sesion})


@bp.post('/auth/logout')
@requiere_login()
def logout():
    TOKENS.pop(request.headers.get('Authorization', '')[7:], None)
    return '', 204
