"""Reportes para la gerencia (solo administrador).
Cada reporte es una vista que está en database/stockcrate.sql (Parte 3),
así que aquí solo se leen. Si falta la vista, hay que correr ese script."""
import pymysql
from flask import Blueprint, jsonify
from auth import requiere_login
from db import consultar_uno, consultar_varios
from helpers import error

bp = Blueprint('reportes', __name__)

# nombre en la URL -> (vista, orden). Los nombres de vista son fijos, no vienen del usuario.
REPORTES = {
    'stock-critico':           ('v_stock_critico', 'stock ASC'),
    'valor-inventario':        ('v_valor_inventario', 'valor_costo DESC'),
    'rentabilidad':            ('v_rentabilidad_producto', 'utilidad DESC'),
    'clasificacion-abc':       ('v_clasificacion_abc', 'ingresos DESC'),
    'resumen-mensual':         ('v_resumen_mensual', 'mes ASC'),
    'sin-rotacion':            ('v_sin_rotacion', 'capital_inmovilizado DESC'),
    'cobertura-stock':         ('v_cobertura_stock', 'dias_de_cobertura IS NULL, dias_de_cobertura ASC'),
    'compras-proveedor':       ('v_compras_proveedor', 'total_comprado DESC'),
    'comparativo-proveedores': ('v_comparativo_proveedores', 'producto ASC, precio_compra ASC'),
    'perdidas-ajustes':        ('v_perdidas_ajustes', 'valor_perdido DESC'),
    'mejores-clientes':        ('v_mejores_clientes', 'total_comprado DESC'),
    'ventas-usuario':          ('v_ventas_por_usuario', 'total_vendido DESC'),
}


@bp.get('/reportes')
@requiere_login('ADMIN')
def indice():
    # Lista de reportes disponibles (sirve para armar el menú del frontend)
    return jsonify(['resumen'] + list(REPORTES))


@bp.get('/reportes/resumen')
@requiere_login('ADMIN')
def resumen():
    # Una sola fila con los indicadores principales
    try:
        return jsonify(consultar_uno('SELECT * FROM v_resumen_gerencial'))
    except pymysql.err.ProgrammingError:
        return error('Falta crear las vistas. Ejecuta database/stockcrate.sql (Parte 3).', 500)


@bp.get('/reportes/<nombre>')
@requiere_login('ADMIN')
def reporte(nombre):
    if nombre not in REPORTES:
        return error('Ese reporte no existe.', 404)
    vista, orden = REPORTES[nombre]
    try:
        return jsonify(consultar_varios(f'SELECT * FROM {vista} ORDER BY {orden}'))
    except pymysql.err.ProgrammingError:
        return error('Falta crear las vistas. Ejecuta database/stockcrate.sql (Parte 3).', 500)
