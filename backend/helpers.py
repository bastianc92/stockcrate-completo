"""Cosas pequeñas que usan varios archivos."""
from flask import jsonify, request


class ErrorNegocio(Exception):
    """Para avisar un error de validación (ej: stock insuficiente).
    Se lanza dentro de una transacción para que se haga rollback y
    app.py lo convierte en una respuesta 400 con el mensaje."""


def error(mensaje, status=400):
    # El frontend lee el campo "mensaje" para mostrar las alertas
    return jsonify({'mensaje': mensaje}), status


def datos():
    # Si no llega JSON (o llega mal) devuelvo un diccionario vacío
    return request.get_json(silent=True) or {}
