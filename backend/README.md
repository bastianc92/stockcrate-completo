# Backend StockCrate (Flask + MariaDB)

API REST para el frontend de StockCrate. Trabaja con la base `stockcrate` (no crea ni borra tablas).

## Estructura

```
backend/
  app.py            arranca Flask, registra las rutas y maneja los errores
  config.py         lee el .env (conexión a la base, puerto, etc.)
  db.py             funciones para consultar y para hacer transacciones
  auth.py           login, logout, tokens y permisos por rol
  helpers.py        respuesta de error y lectura del JSON
  routes/
    productos.py    CRUD de productos
    catalogos.py    categorías, proveedores y clientes
    movimientos.py  compras, ventas, ajustes, anulaciones e historial
    reportes.py     reportes para la gerencia (solo ADMIN)
```

## Instalación en Windows (PowerShell)
1. Importa en XAMPP el archivo `database/stockcrate.sql`. Es un solo script con todo: el esquema, los datos de prueba, datos de demostración (Parte 2, opcional: se puede borrar esa parte) y las vistas de los reportes (Parte 3).
2. Abre una terminal en la carpeta `backend`.
3. Crea el entorno virtual: `py -m venv .venv` y actívalo: `.\.venv\Scripts\Activate.ps1`
4. Instala: `python -m pip install -r requirements.txt`
5. Copia `.env.example` como `.env` y ajusta `DB_USER` y `DB_PASSWORD` si no usas root sin clave.
6. Ejecuta `python app.py` y revisa `http://127.0.0.1:5000/api/health`.
7. Abre el frontend (Live Server) y entra con `admin@stockcrate.com` / `admin123` (ojo con las minúsculas) o `empleado@stockcrate.com` / `123456`.

## Rutas
Todas empiezan con `/api` y piden `Authorization: Bearer <token>` (menos login y health).

| Método | Ruta | Rol |
|--------|------|-----|
| GET | /health | público |
| POST | /auth/login, /auth/logout | público / logueado |
| GET | /productos | todos |
| POST, PUT, DELETE | /productos, /productos/{id} | ADMIN |
| GET | /categorias, /proveedores, /clientes | todos |
| POST, PUT | /categorias, /proveedores, /clientes (y /{id}) | ADMIN |
| GET | /motivos-ajuste, /historial | todos |
| POST | /compras, /ventas | todos |
| POST | /ajustes | ADMIN |
| PATCH | /compras/{id}/anular, /ventas/{id}/anular | ADMIN |
| GET | /reportes y /reportes/{nombre} | ADMIN |

### Reportes para la gerencia
Salen de las vistas de `database/stockcrate.sql` (Parte 3). `GET /api/reportes` devuelve la lista de nombres.

| Reporte | Qué responde |
|---------|--------------|
| resumen | indicadores del mes (ventas, compras, inventario, alertas, pérdidas) |
| stock-critico | qué reponer, cuánto y a qué proveedor |
| valor-inventario | plata en bodega por categoría |
| rentabilidad | ingresos, utilidad y margen por producto |
| clasificacion-abc | productos que hacen el 80% de las ventas |
| resumen-mensual | ventas vs compras por mes y variación |
| sin-rotacion | productos sin venta en 90 días y capital inmovilizado |
| cobertura-stock | para cuántos días alcanza el stock |
| compras-proveedor | en qué proveedores se concentra el gasto |
| comparativo-proveedores | quién vende más barato cada producto |
| perdidas-ajustes | pérdidas por daño, robo y vencimiento |
| mejores-clientes | clientes que más compran |
| ventas-usuario | ventas por empleado |

## Frontend
El frontend (carpeta `frontend/`) usa estas rutas. Para la gerencia tiene la sección **Reportes** (menú Gerencia) y 4 indicadores en el inicio; ambos solo los ve el administrador, y el backend además valida el rol.

## Cómo funciona el stock
Compras, ventas y ajustes guardan el documento, sus detalles y el cambio de stock en una sola transacción. Si algo falla (por ejemplo, stock insuficiente) no se guarda nada. Al anular una compra o venta se devuelve el stock. Una compra también actualiza el precio de compra del producto y el precio de ese proveedor (`producto_proveedor`), que usa el comparativo de proveedores.

## Pendientes y limitaciones
- Los tokens viven en memoria: al reiniciar el backend hay que volver a iniciar sesión.
- `usuarios.password` es `VARCHAR(20)`, por eso las claves de prueba están en texto plano. El backend también acepta hashes si algún día se amplía la columna.
- `CORS_ORIGINS=*` es solo para desarrollo local.
- IVA, retención y descuento se guardan en 0 (el backend todavía no los calcula).
- La anulación cambia el estado y devuelve el stock, pero no deja una fila aparte de auditoría.
