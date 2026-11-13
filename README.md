# StockCrate

Sistema web de gestión de inventario desarrollado como proyecto de grado del programa Tecnología en Desarrollo de Software del ITM (Medellín).

## Descripción

StockCrate permite registrar productos, gestionar entradas y salidas de inventario, administrar categorías, proveedores y clientes, con alertas automáticas de stock mínimo. El sistema cuenta con dos roles de usuario: administrador y empleado.

## Tecnologías

- **Base de datos:** MariaDB (incluido en XAMPP)
- **Backend:** Python + Flask + PyMySQL (implementación inicial; pendiente de pruebas locales)
- **Frontend:** HTML5, CSS3, JavaScript

## Estructura del proyecto

frontend/ Interfaz de usuario (HTML, CSS, JS)
backend/ API REST (Flask), organizada en modulos (ver backend/README.md)
database/ Un solo script (stockcrate.sql): esquema, datos de prueba y demo, y vistas para la gerencia
docs/ Documentacion y diagramas

## Estado del proyecto

- [x] Diseño de base de datos (15 tablas, restricciones y FKs)
- [x] Diagramas UML y ER
- [x] Interfaz de usuario (HTML/CSS/JS)
- [x] Backend API implementada y organizada en modulos (probada con 60 casos automaticos)
- [x] Consultas de valor para la gerencia (vistas SQL + rutas /api/reportes)
- [x] Frontend: seccion Reportes y indicadores de gerencia en el inicio (solo administrador)
- [x] Conexión frontend configurada para usar el backend
- [ ] Pruebas funcionales completas en XAMPP
- [ ] Revisión de seguridad y despliegue

## Rutas que espera el frontend

Todas cuelgan de `http://localhost:5000/api` (se cambia en `API_URL`). Si el login devuelve un `token`, se envía como `Authorization: Bearer <token>`. Los campos siguen el esquema de `stockcrate_db_v2.sql`.

| Método | Ruta | Qué recibe o devuelve |
|--------|------|-----------------------|
| POST | /auth/login | Devuelve `{ token, correo, nombre, rol }`. El rol es `ADMIN` o `EMPLEADO`. Se activa con `USAR_BACKEND` en login.html |
| GET, POST | /productos | Campos: codigo, nombre, id_categoria, precio_compra, precio_venta, stock, stock_minimo, descripcion. El GET agrega `categoria_nombre` |
| PUT, DELETE | /productos/{id} | Editar y desactivar (poner `activo = 0`) |
| GET, POST, PUT | /categorias | nombre, descripcion, activo |
| GET, POST, PUT | /proveedores | nombre, nit, telefono, correo, direccion |
| GET, POST, PUT | /clientes | id_cliente (= documento, texto), nombre_razon_social, apellido_paterno, apellido_materno, documento, telefono, correo, direccion |
| POST | /compras | `{ id_proveedor, observacion, detalles: [{ id_producto, cantidad, precio_unitario }] }` |
| POST | /ventas | `{ id_cliente?, observacion, detalles: [{ id_producto, cantidad, precio_unitario }] }` |
| POST | /ajustes | `{ id_motivo, observacion, detalles: [{ id_producto, cantidad }] }` (cantidad negativa baja el stock) |
| GET | /motivos-ajuste | Lista de `{ id_motivo, nombre }` |
| PATCH | /compras/{id}/anular, /ventas/{id}/anular | Pone el estado en ANULADA y devuelve el stock |
| GET | /historial | Una fila por detalle: `{ id, tipo (compra, venta o ajuste), producto, cantidad, detalle, estado, fecha, usuario }` |

Notas para el backend:
- El número de compra y de ajuste (`COMP-0001`, `AJU-0001`), el usuario (sale del token) y el estado (COMPLETADA) los pone el backend. IVA, retención y descuento quedan en 0.
- La base de datos no tiene triggers: el backend debe actualizar `productos.stock` al registrar o anular compras, ventas y ajustes, dentro de una transacción. El `CHECK (stock >= 0)` rechaza ventas sin stock suficiente.
- Hace falta `flask-cors` y validar el rol en cada ruta (el front solo esconde botones: el empleado no ve editar, desactivar, anular ni ajustes).
- Antes de entregar hay que borrar `USUARIOS_PRUEBA` de login.html.

## Autor

**Sebastián Castañeda Diosa**
Tecnología en Desarrollo de Software - ITM Medellín


## Backend local
Consulta `backend/README.md` para instalar dependencias, configurar la conexión y ejecutar la API. La API usa la base `stockcrate` y no crea ni elimina tablas automáticamente. Antes de probar, inicia MySQL/MariaDB en XAMPP. Si importas los .sql por consola, usa `--default-character-set=utf8mb4` para que las tildes queden bien (en phpMyAdmin se importan bien con UTF-8). Esta versión inicial requiere pruebas locales y ajustes según los errores que aparezcan.
