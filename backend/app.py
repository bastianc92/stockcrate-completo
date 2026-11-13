"""API REST de StockCrate (Flask + MariaDB). Para correrla: python app.py"""
from datetime import date, datetime
from decimal import Decimal
from flask import Flask, jsonify
from flask.json.provider import DefaultJSONProvider
from flask_cors import CORS

import config
import auth
from db import consultar_uno
from helpers import error, ErrorNegocio
from routes import productos, catalogos, movimientos, reportes


class ProveedorJSON(DefaultJSONProvider):
    # Los DECIMAL de MariaDB llegan como Decimal y Flask los manda como texto ("4500.00").
    # Los paso a número para que el frontend y los reportes reciban números de verdad.
    # Las fechas las mando como 2026-10-29T09:55:00 (sin "GMT"), porque la base guarda la
    # hora local y con GMT el navegador la mostraba 5 horas atrasada.
    ensure_ascii = False

    @staticmethod
    def default(o):
        if isinstance(o, Decimal):
            return float(o)
        if isinstance(o, (datetime, date)):
            return o.isoformat()
        return DefaultJSONProvider.default(o)


app = Flask(__name__)
app.json = ProveedorJSON(app)
app.config['SECRET_KEY'] = config.SECRET_KEY
CORS(app, resources={r'/api/*': {'origins': config.CORS_ORIGINS}})

# Todas las rutas cuelgan de /api
for modulo in (auth, productos, catalogos, movimientos, reportes):
    app.register_blueprint(modulo.bp, url_prefix='/api')


@app.get('/api/health')
def health():
    try:
        fila = consultar_uno('SELECT DATABASE() AS base, VERSION() AS version')
        return jsonify({'estado': 'ok', 'servicio': 'StockCrate API', 'base_datos': fila['base'], 'motor': fila['version']})
    except Exception:
        app.logger.exception('Health check falló')
        return error('API disponible, pero no se pudo conectar a la base de datos.', 503)


# ── Manejo de errores: siempre responden JSON con "mensaje" ──

@app.errorhandler(ErrorNegocio)
def error_de_negocio(e):
    return error(str(e), 400)


@app.errorhandler(404)
def no_encontrada(_):
    return error('Ruta de API no encontrada.', 404)


@app.errorhandler(405)
def metodo_no_permitido(_):
    return error('Método no permitido para esta ruta.', 405)


@app.errorhandler(500)
def error_interno(_):
    return error('Error interno del servidor.', 500)


if __name__ == '__main__':
    # Solo para desarrollo local; en producción no se usa el servidor integrado de Flask
    app.run(host='127.0.0.1', port=config.PORT, debug=False)
