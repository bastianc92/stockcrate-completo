"""Compras (entradas), ventas (salidas), ajustes, anulaciones e historial.
Cada documento se guarda con sus detalles y el cambio de stock en UNA
sola transacción: o se guarda todo o no se guarda nada."""
from flask import Blueprint, jsonify, g
from auth import requiere_login
from db import consultar_varios, transaccion, siguiente_numero
from helpers import datos, error, ErrorNegocio

bp = Blueprint('movimientos', __name__)


# ── Funciones de apoyo ──────────────────────────────

def leer_detalles(d, es_ajuste=False):
    """Valida la lista de productos que manda el frontend.
    Devuelve una lista de (id_producto, cantidad, precio_unitario)."""
    lineas = d.get('detalles') or []
    if not lineas:
        raise ErrorNegocio('Agrega al menos un producto al documento.')

    limpias = []
    for linea in lineas:
        try:
            id_producto = int(linea['id_producto'])
            cantidad = int(linea['cantidad'])
            precio = float(linea.get('precio_unitario') or 0)
        except (KeyError, ValueError, TypeError):
            raise ErrorNegocio('Los datos de un producto no son válidos.')

        if es_ajuste and cantidad == 0:
            raise ErrorNegocio('La cantidad del ajuste no puede ser cero.')
        # En los ajustes la cantidad lleva signo (negativa = baja), en compras y ventas no
        if not es_ajuste and cantidad <= 0:
            raise ErrorNegocio('Las cantidades deben ser mayores que cero.')
        if precio < 0:
            raise ErrorNegocio('Los precios no pueden ser negativos.')
        limpias.append((id_producto, cantidad, precio))
    return limpias


def id_estado(c, nombre):
    c.execute('SELECT id_estado FROM estados WHERE nombre = %s', (nombre,))
    fila = c.fetchone()
    if not fila:
        raise ErrorNegocio('No existe el estado ' + nombre)
    return fila['id_estado']


def cambiar_stock(c, id_producto, cambio):
    """Suma o resta al stock. Bloquea la fila para que dos ventas al mismo
    tiempo no dejen el stock en negativo."""
    c.execute('SELECT nombre, stock FROM productos WHERE id_producto = %s AND activo = 1 FOR UPDATE', (id_producto,))
    producto = c.fetchone()
    if not producto:
        raise ErrorNegocio(f'El producto {id_producto} no existe o está inactivo.')
    nuevo = int(producto['stock']) + cambio
    if nuevo < 0:
        raise ErrorNegocio(f'Stock insuficiente de "{producto["nombre"]}". Disponible: {producto["stock"]}.')
    c.execute('UPDATE productos SET stock = %s WHERE id_producto = %s', (nuevo, id_producto))


def respuesta_creado(id_documento):
    return jsonify({'mensaje': 'Documento registrado.', 'id': id_documento}), 201


# ── Compras ─────────────────────────────────────────

@bp.post('/compras')
@requiere_login()
def crear_compra():
    d = datos()
    lineas = leer_detalles(d)
    try:
        id_proveedor = int(d.get('id_proveedor') or 0)
    except (ValueError, TypeError):
        raise ErrorNegocio('Selecciona un proveedor válido.')
    total = sum(cantidad * precio for _, cantidad, precio in lineas)

    with transaccion() as c:
        c.execute('SELECT id_proveedor FROM proveedores WHERE id_proveedor = %s AND activo = 1', (id_proveedor,))
        if not c.fetchone():
            raise ErrorNegocio('Selecciona un proveedor válido.')

        numero = siguiente_numero(c, 'COMP', 'compras', 'numero')
        c.execute('''INSERT INTO compras (numero, id_proveedor, id_usuario, id_estado, total, observacion)
                     VALUES (%s, %s, %s, %s, %s, %s)''',
                  (numero, id_proveedor, g.usuario['id_usuario'], id_estado(c, 'COMPLETADA'), total, d.get('observacion')))
        id_compra = c.lastrowid

        for id_producto, cantidad, precio in lineas:
            cambiar_stock(c, id_producto, cantidad)
            c.execute('''INSERT INTO detalle_compra (id_compra, id_producto, cantidad, precio_unitario, subtotal)
                         VALUES (%s, %s, %s, %s, %s)''', (id_compra, id_producto, cantidad, precio, cantidad * precio))
            # El último precio pagado queda como precio de compra del producto
            c.execute('UPDATE productos SET precio_compra = %s WHERE id_producto = %s', (precio, id_producto))
            # Y también se guarda lo que cobra este proveedor por el producto
            # (de ahí sale el comparativo de proveedores de los reportes)
            c.execute('''INSERT INTO producto_proveedor (id_producto, id_proveedor, precio_compra)
                         VALUES (%s, %s, %s) ON DUPLICATE KEY UPDATE precio_compra = VALUES(precio_compra)''',
                      (id_producto, id_proveedor, precio))
    return respuesta_creado(id_compra)


# ── Ventas ──────────────────────────────────────────

@bp.post('/ventas')
@requiere_login()
def crear_venta():
    d = datos()
    lineas = leer_detalles(d)
    id_cliente = str(d['id_cliente']).strip() if d.get('id_cliente') else None  # puede ir sin cliente
    total = sum(cantidad * precio for _, cantidad, precio in lineas)

    with transaccion() as c:
        if id_cliente:
            c.execute('SELECT id_cliente FROM clientes WHERE id_cliente = %s AND activo = 1', (id_cliente,))
            if not c.fetchone():
                raise ErrorNegocio('El cliente seleccionado no existe o está inactivo.')

        c.execute('''INSERT INTO ventas (id_cliente, id_usuario, id_estado, total, observacion)
                     VALUES (%s, %s, %s, %s, %s)''',
                  (id_cliente, g.usuario['id_usuario'], id_estado(c, 'COMPLETADA'), total, d.get('observacion')))
        id_venta = c.lastrowid

        for id_producto, cantidad, precio in lineas:
            cambiar_stock(c, id_producto, -cantidad)
            c.execute('''INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario, subtotal)
                         VALUES (%s, %s, %s, %s, %s)''', (id_venta, id_producto, cantidad, precio, cantidad * precio))
    return respuesta_creado(id_venta)


# ── Ajustes de inventario (solo administrador) ──────

@bp.get('/motivos-ajuste')
@requiere_login()
def motivos():
    return jsonify(consultar_varios('SELECT id_motivo, nombre, descripcion FROM motivos_ajuste ORDER BY id_motivo'))


@bp.post('/ajustes')
@requiere_login('ADMIN')
def crear_ajuste():
    d = datos()
    lineas = leer_detalles(d, es_ajuste=True)
    try:
        id_motivo = int(d.get('id_motivo') or 0)
    except (ValueError, TypeError):
        raise ErrorNegocio('Selecciona un motivo válido.')

    with transaccion() as c:
        c.execute('SELECT id_motivo FROM motivos_ajuste WHERE id_motivo = %s', (id_motivo,))
        if not c.fetchone():
            raise ErrorNegocio('Selecciona un motivo válido.')

        numero = siguiente_numero(c, 'AJU', 'ajuste_inventario', 'numero')
        c.execute('INSERT INTO ajuste_inventario (numero, id_usuario, id_motivo, observacion) VALUES (%s, %s, %s, %s)',
                  (numero, g.usuario['id_usuario'], id_motivo, d.get('observacion')))
        id_ajuste = c.lastrowid

        for id_producto, cantidad, _ in lineas:
            cambiar_stock(c, id_producto, cantidad)
            c.execute('INSERT INTO detalle_ajuste (id_ajuste, id_producto, cantidad) VALUES (%s, %s, %s)',
                      (id_ajuste, id_producto, cantidad))
    return respuesta_creado(id_ajuste)


# ── Anular compras y ventas (solo administrador) ────

# Para una compra, anular RESTA lo que había entrado; para una venta, SUMA lo que había salido
ANULACION = {
    'compra': {'tabla': 'compras', 'id': 'id_compra', 'detalle': 'detalle_compra', 'signo': -1},
    'venta': {'tabla': 'ventas', 'id': 'id_venta', 'detalle': 'detalle_venta', 'signo': 1},
}


def anular(tipo, id_documento):
    cfg = ANULACION[tipo]
    with transaccion() as c:
        c.execute(f'''SELECT e.nombre AS estado FROM {cfg['tabla']} d
                      JOIN estados e ON e.id_estado = d.id_estado
                      WHERE d.{cfg['id']} = %s FOR UPDATE''', (id_documento,))
        doc = c.fetchone()
        if not doc:
            raise ErrorNegocio('No se encontró el documento.')
        if doc['estado'] == 'ANULADA':
            raise ErrorNegocio('Este documento ya está anulado.')

        c.execute(f"SELECT id_producto, cantidad FROM {cfg['detalle']} WHERE {cfg['id']} = %s", (id_documento,))
        for linea in c.fetchall():
            cambiar_stock(c, linea['id_producto'], cfg['signo'] * linea['cantidad'])

        c.execute(f"UPDATE {cfg['tabla']} SET id_estado = %s WHERE {cfg['id']} = %s",
                  (id_estado(c, 'ANULADA'), id_documento))
    return jsonify({'mensaje': 'Documento anulado y stock revertido.'})


@bp.patch('/compras/<int:id_documento>/anular')
@requiere_login('ADMIN')
def anular_compra(id_documento):
    return anular('compra', id_documento)


@bp.patch('/ventas/<int:id_documento>/anular')
@requiere_login('ADMIN')
def anular_venta(id_documento):
    return anular('venta', id_documento)


# ── Historial ───────────────────────────────────────

# Una fila por cada producto de cada compra, venta y ajuste
SQL_HISTORIAL = '''
SELECT id, tipo, producto, cantidad, detalle, estado, fecha, usuario FROM (
  SELECT c.id_compra AS id, 'compra' AS tipo, p.nombre AS producto, dc.cantidad AS cantidad,
         CONCAT('Compra ', c.numero, ' - Proveedor: ', pr.nombre) AS detalle,
         e.nombre AS estado, c.fecha AS fecha, CONCAT(u.nombres, ' ', u.apellido_paterno) AS usuario
  FROM compras c
  JOIN detalle_compra dc ON dc.id_compra = c.id_compra
  JOIN productos p ON p.id_producto = dc.id_producto
  JOIN proveedores pr ON pr.id_proveedor = c.id_proveedor
  JOIN estados e ON e.id_estado = c.id_estado
  JOIN usuarios u ON u.id_usuario = c.id_usuario
  UNION ALL
  SELECT v.id_venta, 'venta', p.nombre, -dv.cantidad, CONCAT('Venta #', v.id_venta),
         e.nombre, v.fecha, CONCAT(u.nombres, ' ', u.apellido_paterno)
  FROM ventas v
  JOIN detalle_venta dv ON dv.id_venta = v.id_venta
  JOIN productos p ON p.id_producto = dv.id_producto
  JOIN estados e ON e.id_estado = v.id_estado
  JOIN usuarios u ON u.id_usuario = v.id_usuario
  UNION ALL
  SELECT a.id_ajuste, 'ajuste', p.nombre, da.cantidad, CONCAT('Ajuste ', a.numero, ' - ', m.nombre),
         'COMPLETADA', a.fecha, CONCAT(u.nombres, ' ', u.apellido_paterno)
  FROM ajuste_inventario a
  JOIN detalle_ajuste da ON da.id_ajuste = a.id_ajuste
  JOIN productos p ON p.id_producto = da.id_producto
  JOIN motivos_ajuste m ON m.id_motivo = a.id_motivo
  JOIN usuarios u ON u.id_usuario = a.id_usuario
) h ORDER BY fecha DESC, id DESC'''


@bp.get('/historial')
@requiere_login()
def historial():
    return jsonify(consultar_varios(SQL_HISTORIAL))
