"""Categorías, proveedores y clientes.
Los tres tienen el mismo CRUD, así que se arman con una sola función
y cada uno solo dice qué tabla y qué campos tiene."""
import pymysql
from flask import Blueprint, jsonify
from auth import requiere_login
from db import consultar_varios, ejecutar
from helpers import datos, error

bp = Blueprint('catalogos', __name__)

CATALOGOS = {
    'categorias': {
        'tabla': 'categorias', 'id': 'id_categoria',
        'campos': ['nombre', 'descripcion'],
        'obligatorios': ['nombre'],
    },
    'proveedores': {
        'tabla': 'proveedores', 'id': 'id_proveedor',
        'campos': ['nombre', 'nit', 'telefono', 'correo', 'direccion'],
        'obligatorios': ['nombre'],
    },
    'clientes': {
        # En clientes el id es el documento (texto), no es autoincrement
        'tabla': 'clientes', 'id': 'id_cliente',
        'campos': ['nombre_razon_social', 'apellido_paterno', 'apellido_materno',
                   'documento', 'telefono', 'correo', 'direccion'],
        'obligatorios': ['documento', 'nombre_razon_social'],
    },
}


def limpiar(valor):
    # Texto vacío se guarda como NULL
    if isinstance(valor, str):
        valor = valor.strip()
    return valor or None


def crear_rutas(recurso, cfg):
    tabla, id_col = cfg['tabla'], cfg['id']
    columnas = ', '.join([id_col] + cfg['campos'] + ['activo'])

    @bp.get('/' + recurso, endpoint=recurso + '_listar')
    @requiere_login()
    def listar():
        return jsonify(consultar_varios(f'SELECT {columnas} FROM {tabla} WHERE activo = 1 ORDER BY {id_col} DESC'))

    @bp.post('/' + recurso, endpoint=recurso + '_crear')
    @requiere_login('ADMIN')
    def crear():
        d = datos()
        if any(not limpiar(d.get(f)) for f in cfg['obligatorios']):
            return error('Faltan campos obligatorios.')

        campos = [f for f in cfg['campos'] if f in d]
        valores = [limpiar(d[f]) for f in campos]
        if recurso == 'clientes':
            campos.insert(0, 'id_cliente')
            valores.insert(0, str(d['documento']).strip())

        sql = f"INSERT INTO {tabla} ({', '.join(campos)}) VALUES ({', '.join(['%s'] * len(campos))})"
        try:
            nuevo_id = ejecutar(sql, valores)
        except pymysql.err.IntegrityError:
            return error('No se pudo crear: revisa que el nombre, documento, NIT o correo no estén duplicados.', 409)
        return jsonify({'mensaje': 'Registro creado.', 'id': nuevo_id}), 201

    @bp.put('/' + recurso + '/<id_registro>', endpoint=recurso + '_editar')
    @requiere_login('ADMIN')
    def editar(id_registro):
        d = datos()
        # El documento del cliente es su id, por eso no se deja cambiar
        campos = [f for f in cfg['campos'] if f in d and not (recurso == 'clientes' and f == 'documento')]
        if not campos:
            return error('No hay campos para actualizar.')

        sql = f"UPDATE {tabla} SET {', '.join(f + ' = %s' for f in campos)} WHERE {id_col} = %s"
        try:
            ejecutar(sql, [limpiar(d[f]) for f in campos] + [id_registro])
        except pymysql.err.IntegrityError:
            return error('Hay un valor duplicado o una relación inválida.', 409)
        return jsonify({'mensaje': 'Registro actualizado.'})


for nombre, config in CATALOGOS.items():
    crear_rutas(nombre, config)
