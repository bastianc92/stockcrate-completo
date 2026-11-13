"""Funciones para hablar con la base de datos."""
from contextlib import contextmanager
import pymysql
from config import DB


def conectar():
    return pymysql.connect(**DB)


def consultar_uno(sql, params=()):
    conn = conectar()
    try:
        with conn.cursor() as c:
            c.execute(sql, params)
            return c.fetchone()
    finally:
        conn.close()


def consultar_varios(sql, params=()):
    conn = conectar()
    try:
        with conn.cursor() as c:
            c.execute(sql, params)
            return c.fetchall()
    finally:
        conn.close()


def ejecutar(sql, params=()):
    """INSERT, UPDATE o DELETE sueltos. Devuelve el id que generó (si hubo)."""
    conn = conectar()
    try:
        with conn.cursor() as c:
            c.execute(sql, params)
            nuevo_id = c.lastrowid
        conn.commit()
        return nuevo_id
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@contextmanager
def transaccion():
    """Para varias sentencias que deben guardarse juntas o ninguna.
    Uso:  with transaccion() as c:  c.execute(...)
    Si algo falla se hace rollback y el error sigue su camino."""
    conn = conectar()
    try:
        with conn.cursor() as c:
            yield c
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def siguiente_numero(c, prefijo, tabla, columna):
    """Genera COMP-0001, AJU-0001, etc. Bloquea la última fila (FOR UPDATE)
    para que dos registros al mismo tiempo no repitan el número.
    Ojo: tabla y columna solo se llaman desde el código, nunca vienen del usuario."""
    c.execute(f"SELECT {columna} FROM {tabla} WHERE {columna} LIKE %s ORDER BY {columna} DESC LIMIT 1 FOR UPDATE",
              (prefijo + '-%',))
    fila = c.fetchone()
    n = 1
    if fila:
        try:
            n = int(fila[columna].split('-')[-1]) + 1
        except (ValueError, AttributeError):
            pass
    return f'{prefijo}-{n:04d}'
