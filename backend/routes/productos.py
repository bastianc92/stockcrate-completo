"""Rutas de productos."""
import pymysql
from flask import Blueprint, jsonify, g
from auth import requiere_login
from db import consultar_varios, ejecutar, transaccion, siguiente_numero
from helpers import datos, error

bp = Blueprint('productos', __name__)

# Campos que se pueden cambiar al editar (el stock NO: eso solo cambia con
# compras, ventas y ajustes para que siempre quede registrado)
CAMPOS_EDITABLES = ['codigo', 'nombre', 'descripcion', 'id_categoria',
                    'precio_venta', 'precio_compra', 'stock_minimo']
CAMPOS_NUMERICOS = ['precio_venta', 'precio_compra', 'stock_minimo']


@bp.get('/productos')
@requiere_login()
def listar():
    return jsonify(consultar_varios('''
        SELECT p.id_producto, p.codigo, p.nombre, p.descripcion, p.id_categoria,
               p.precio_venta, p.precio_compra, p.stock, p.stock_minimo, p.activo,
               c.nombre AS categoria_nombre
        FROM productos p JOIN categorias c ON c.id_categoria = p.id_categoria
        WHERE p.activo = 1
        ORDER BY p.id_producto DESC'''))


@bp.post('/productos')
@requiere_login('ADMIN')
def crear():
    d = datos()
    try:
        codigo = str(d.get('codigo', '')).strip()
        nombre = str(d.get('nombre', '')).strip()
        categoria = int(d.get('id_categoria'))
        venta = float(d.get('precio_venta'))
        compra = float(d.get('precio_compra') or 0)
        stock = int(d.get('stock', 0))
        minimo = int(d.get('stock_minimo', 5))
        if not codigo or not nombre or min(venta, compra, stock, minimo) < 0:
            raise ValueError()
    except (ValueError, TypeError):
        return error('Verifica los campos del producto; precios y existencias no pueden ser negativos.')

    try:
        with transaccion() as c:
            c.execute('''INSERT INTO productos (codigo, nombre, descripcion, id_categoria,
                         precio_venta, precio_compra, stock, stock_minimo)
                         VALUES (%s, %s, %s, %s, %s, %s, %s, %s)''',
                      (codigo, nombre, d.get('descripcion'), categoria, venta, compra, stock, minimo))
            id_producto = c.lastrowid

            # El stock inicial se deja registrado como un ajuste de CORRECCION
            # para que aparezca en el historial
            if stock > 0:
                c.execute("SELECT id_motivo FROM motivos_ajuste WHERE nombre = 'CORRECCION' LIMIT 1")
                motivo = c.fetchone()
                if motivo:
                    numero = siguiente_numero(c, 'AJU', 'ajuste_inventario', 'numero')
                    c.execute('INSERT INTO ajuste_inventario (numero, id_usuario, id_motivo, observacion) VALUES (%s, %s, %s, %s)',
                              (numero, g.usuario['id_usuario'], motivo['id_motivo'], 'Stock inicial al crear producto ' + codigo))
                    c.execute('INSERT INTO detalle_ajuste (id_ajuste, id_producto, cantidad) VALUES (%s, %s, %s)',
                              (c.lastrowid, id_producto, stock))
    except pymysql.err.IntegrityError:
        return error('No se pudo registrar: el código puede estar duplicado o la categoría no existe.')

    return jsonify({'mensaje': 'Producto registrado.', 'id_producto': id_producto}), 201


@bp.put('/productos/<int:id_producto>')
@requiere_login('ADMIN')
def editar(id_producto):
    d = datos()
    campos = [f for f in CAMPOS_EDITABLES if f in d]
    if not campos:
        return error('No se recibieron campos para actualizar.')

    for f in CAMPOS_NUMERICOS:
        if f in campos:
            try:
                if float(d[f]) < 0:
                    raise ValueError()
            except (ValueError, TypeError):
                return error('Los precios y el stock mínimo no pueden ser negativos.')

    sql = 'UPDATE productos SET ' + ', '.join(f + ' = %s' for f in campos) + ' WHERE id_producto = %s AND activo = 1'
    try:
        ejecutar(sql, [d[f] for f in campos] + [id_producto])
    except pymysql.err.IntegrityError:
        return error('No se pudo actualizar el producto. Verifica código y categoría.')
    return jsonify({'mensaje': 'Producto actualizado.'})


@bp.delete('/productos/<int:id_producto>')
@requiere_login('ADMIN')
def desactivar(id_producto):
    # Borrado lógico: el producto puede estar en compras o ventas viejas
    ejecutar('UPDATE productos SET activo = 0 WHERE id_producto = %s', (id_producto,))
    return '', 204
