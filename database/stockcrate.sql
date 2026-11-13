-- =====================================================
-- StockCrate - script completo (un solo archivo)
-- Motor: MariaDB 10.4 (XAMPP). Se importa de una vez, completo.
--   Parte 1: esquema de 15 tablas y datos de prueba base (version aprobada por el profesor)
--   Parte 2: datos de demostracion (agosto a noviembre 2026). OPCIONAL: se puede borrar
--            esta parte completa si solo se quieren los datos de la parte 1
--   Parte 3: vistas con las consultas para la gerencia (las usa /api/reportes)
-- OJO: borra y vuelve a crear las tablas. Usar solo con datos de prueba.
-- =====================================================

SET NAMES utf8mb4;

-- =====================================================
-- StockCrate - esquema actualizado (version 3)
-- Cambios aplicados segun las observaciones del profesor
-- Motor: MariaDB 10.4 (XAMPP)
-- =====================================================
-- OJO: este script borra y vuelve a crear las 15 tablas.
-- Solo usarlo si lo que hay en la base son datos de prueba.

CREATE DATABASE IF NOT EXISTS stockcrate
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE stockcrate;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS detalle_ajuste, ajuste_inventario, detalle_venta, ventas,
  detalle_compra, compras, producto_proveedor, productos, proveedores, clientes,
  usuarios, motivos_ajuste, categorias, estados, roles;
SET FOREIGN_KEY_CHECKS = 1;


-- ---------- tablas de apoyo ----------

CREATE TABLE roles (
  id_rol int NOT NULL AUTO_INCREMENT,
  nombre varchar(50) NOT NULL,
  descripcion varchar(200) DEFAULT NULL,
  PRIMARY KEY (id_rol),
  UNIQUE KEY uq_roles_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE estados (
  id_estado int NOT NULL AUTO_INCREMENT,
  nombre varchar(50) NOT NULL,
  descripcion varchar(200) DEFAULT NULL,
  PRIMARY KEY (id_estado),
  UNIQUE KEY uq_estados_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE motivos_ajuste (
  id_motivo int NOT NULL AUTO_INCREMENT,
  nombre varchar(50) NOT NULL,
  descripcion varchar(200) DEFAULT NULL,
  PRIMARY KEY (id_motivo),
  UNIQUE KEY uq_motivos_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE categorias (
  id_categoria bigint NOT NULL AUTO_INCREMENT,
  nombre varchar(100) NOT NULL,
  descripcion text DEFAULT NULL,
  activo tinyint(1) NOT NULL DEFAULT 1,
  fecha_registro timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (id_categoria),
  UNIQUE KEY uq_categorias_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------- personas ----------

-- id_usuario ahora es varchar(20) (el documento de la persona), por eso no es autoincrement
-- activo se renombro a estado (1 = activo, 0 = inactivo)
CREATE TABLE usuarios (
  id_usuario varchar(20) NOT NULL,
  nombres varchar(100) NOT NULL,
  apellido_paterno varchar(50) NOT NULL,
  apellido_materno varchar(50) NOT NULL,
  correo varchar(100) NOT NULL,
  -- varchar(20) segun la observacion del profesor (OJO: no cabe un hash, la clave queda en texto plano)
  password varchar(20) NOT NULL,
  id_rol int NOT NULL,
  telefono varchar(20) DEFAULT NULL,
  token_recuperacion varchar(255) DEFAULT NULL,
  token_expiracion datetime DEFAULT NULL,
  estado tinyint(1) NOT NULL DEFAULT 1,
  fecha_registro timestamp NOT NULL DEFAULT current_timestamp(),
  fecha_actualizacion timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (id_usuario),
  UNIQUE KEY uq_usuarios_correo (correo),
  KEY fk_usuario_rol (id_rol),
  CONSTRAINT fk_usuario_rol FOREIGN KEY (id_rol) REFERENCES roles (id_rol) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- id_cliente ahora es varchar(20); nombre pasa a nombre_razon_social
-- los apellidos no son obligatorios porque el cliente puede ser una empresa
CREATE TABLE clientes (
  id_cliente varchar(20) NOT NULL,
  nombre_razon_social varchar(150) NOT NULL,
  apellido_paterno varchar(50) DEFAULT NULL,
  apellido_materno varchar(50) DEFAULT NULL,
  documento varchar(20) DEFAULT NULL,
  telefono varchar(20) DEFAULT NULL,
  correo varchar(100) DEFAULT NULL,
  direccion varchar(200) DEFAULT NULL,
  activo tinyint(1) NOT NULL DEFAULT 1,
  fecha_registro timestamp NOT NULL DEFAULT current_timestamp(),
  fecha_actualizacion timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (id_cliente),
  UNIQUE KEY uq_clientes_documento (documento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- id_proveedor pasa de bigint a int
CREATE TABLE proveedores (
  id_proveedor int NOT NULL AUTO_INCREMENT,
  nombre varchar(150) NOT NULL,
  nit varchar(20) DEFAULT NULL,
  telefono varchar(20) DEFAULT NULL,
  correo varchar(100) DEFAULT NULL,
  direccion varchar(200) DEFAULT NULL,
  activo tinyint(1) NOT NULL DEFAULT 1,
  fecha_registro timestamp NOT NULL DEFAULT current_timestamp(),
  fecha_actualizacion timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (id_proveedor),
  UNIQUE KEY uq_proveedores_nit (nit)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------- productos ----------

CREATE TABLE productos (
  id_producto bigint NOT NULL AUTO_INCREMENT,
  codigo varchar(30) NOT NULL,
  nombre varchar(150) NOT NULL,
  descripcion text DEFAULT NULL,
  id_categoria bigint NOT NULL,
  precio_venta decimal(12,2) NOT NULL DEFAULT 0.00,
  precio_compra decimal(12,2) NOT NULL DEFAULT 0.00,
  stock int NOT NULL DEFAULT 0,
  stock_minimo int NOT NULL DEFAULT 5,
  activo tinyint(1) NOT NULL DEFAULT 1,
  fecha_registro timestamp NOT NULL DEFAULT current_timestamp(),
  fecha_actualizacion timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (id_producto),
  UNIQUE KEY uq_productos_codigo (codigo),
  KEY fk_prod_categoria (id_categoria),
  CONSTRAINT fk_prod_categoria FOREIGN KEY (id_categoria) REFERENCES categorias (id_categoria) ON UPDATE CASCADE,
  CONSTRAINT chk_prod_precio_venta CHECK (precio_venta >= 0),
  CONSTRAINT chk_prod_precio_compra CHECK (precio_compra >= 0),
  CONSTRAINT chk_prod_stock CHECK (stock >= 0),
  CONSTRAINT chk_prod_stock_minimo CHECK (stock_minimo >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE producto_proveedor (
  id_producto bigint NOT NULL,
  id_proveedor int NOT NULL,
  precio_compra decimal(12,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (id_producto, id_proveedor),
  KEY fk_pp_proveedor (id_proveedor),
  CONSTRAINT fk_pp_producto FOREIGN KEY (id_producto) REFERENCES productos (id_producto) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pp_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores (id_proveedor) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_pp_precio CHECK (precio_compra >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------- compras (entradas) ----------

-- id_compra pasa a int; se agregan total_iva, total_retencion y total_descuento
CREATE TABLE compras (
  id_compra int NOT NULL AUTO_INCREMENT,
  numero varchar(20) NOT NULL,
  id_proveedor int NOT NULL,
  id_usuario varchar(20) NOT NULL,
  id_estado int NOT NULL,
  fecha timestamp NOT NULL DEFAULT current_timestamp(),
  total decimal(14,2) NOT NULL DEFAULT 0.00,
  total_iva decimal(14,2) NOT NULL DEFAULT 0.00,
  total_retencion decimal(14,2) NOT NULL DEFAULT 0.00,
  total_descuento decimal(14,2) NOT NULL DEFAULT 0.00,
  observacion text DEFAULT NULL,
  PRIMARY KEY (id_compra),
  UNIQUE KEY uq_compras_numero (numero),
  KEY fk_compra_proveedor (id_proveedor),
  KEY fk_compra_usuario (id_usuario),
  KEY fk_compra_estado (id_estado),
  CONSTRAINT fk_compra_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores (id_proveedor) ON UPDATE CASCADE,
  CONSTRAINT fk_compra_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON UPDATE CASCADE,
  CONSTRAINT fk_compra_estado FOREIGN KEY (id_estado) REFERENCES estados (id_estado) ON UPDATE CASCADE,
  CONSTRAINT chk_compra_totales CHECK (total >= 0 AND total_iva >= 0 AND total_retencion >= 0 AND total_descuento >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE detalle_compra (
  id_detalle_compra int NOT NULL AUTO_INCREMENT,
  id_compra int NOT NULL,
  id_producto bigint NOT NULL,
  cantidad int NOT NULL,
  precio_unitario decimal(12,2) NOT NULL,
  subtotal decimal(14,2) NOT NULL,
  PRIMARY KEY (id_detalle_compra),
  KEY fk_dc_compra (id_compra),
  KEY fk_dc_producto (id_producto),
  CONSTRAINT fk_dc_compra FOREIGN KEY (id_compra) REFERENCES compras (id_compra) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_dc_producto FOREIGN KEY (id_producto) REFERENCES productos (id_producto) ON UPDATE CASCADE,
  CONSTRAINT chk_dc_cantidad CHECK (cantidad > 0),
  CONSTRAINT chk_dc_valores CHECK (precio_unitario >= 0 AND subtotal >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------- ventas (salidas) ----------

-- id_venta pasa a int, se elimina el campo numero y se agregan los totales de iva, retencion y descuento
CREATE TABLE ventas (
  id_venta int NOT NULL AUTO_INCREMENT,
  id_cliente varchar(20) DEFAULT NULL,
  id_usuario varchar(20) NOT NULL,
  id_estado int NOT NULL,
  fecha timestamp NOT NULL DEFAULT current_timestamp(),
  total decimal(14,2) NOT NULL DEFAULT 0.00,
  total_iva decimal(14,2) NOT NULL DEFAULT 0.00,
  total_retencion decimal(14,2) NOT NULL DEFAULT 0.00,
  total_descuento decimal(14,2) NOT NULL DEFAULT 0.00,
  observacion text DEFAULT NULL,
  PRIMARY KEY (id_venta),
  KEY fk_venta_cliente (id_cliente),
  KEY fk_venta_usuario (id_usuario),
  KEY fk_venta_estado (id_estado),
  CONSTRAINT fk_venta_cliente FOREIGN KEY (id_cliente) REFERENCES clientes (id_cliente) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_venta_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON UPDATE CASCADE,
  CONSTRAINT fk_venta_estado FOREIGN KEY (id_estado) REFERENCES estados (id_estado) ON UPDATE CASCADE,
  CONSTRAINT chk_venta_totales CHECK (total >= 0 AND total_iva >= 0 AND total_retencion >= 0 AND total_descuento >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE detalle_venta (
  id_detalle_venta int NOT NULL AUTO_INCREMENT,
  id_venta int NOT NULL,
  id_producto bigint NOT NULL,
  cantidad int NOT NULL,
  precio_unitario decimal(12,2) NOT NULL,
  subtotal decimal(14,2) NOT NULL,
  PRIMARY KEY (id_detalle_venta),
  KEY fk_dv_venta (id_venta),
  KEY fk_dv_producto (id_producto),
  CONSTRAINT fk_dv_venta FOREIGN KEY (id_venta) REFERENCES ventas (id_venta) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_dv_producto FOREIGN KEY (id_producto) REFERENCES productos (id_producto) ON UPDATE CASCADE,
  CONSTRAINT chk_dv_cantidad CHECK (cantidad > 0),
  CONSTRAINT chk_dv_valores CHECK (precio_unitario >= 0 AND subtotal >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------- ajustes de inventario ----------

-- id_ajuste pasa a int (y id_detalle_ajuste tambien)
CREATE TABLE ajuste_inventario (
  id_ajuste int NOT NULL AUTO_INCREMENT,
  numero varchar(20) NOT NULL,
  id_usuario varchar(20) NOT NULL,
  id_motivo int NOT NULL,
  fecha timestamp NOT NULL DEFAULT current_timestamp(),
  observacion text DEFAULT NULL,
  PRIMARY KEY (id_ajuste),
  UNIQUE KEY uq_ajuste_numero (numero),
  KEY fk_ajuste_usuario (id_usuario),
  KEY fk_ajuste_motivo (id_motivo),
  CONSTRAINT fk_ajuste_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON UPDATE CASCADE,
  CONSTRAINT fk_ajuste_motivo FOREIGN KEY (id_motivo) REFERENCES motivos_ajuste (id_motivo) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- se eliminaron cantidad_anterior y cantidad_nueva, la cantidad queda con signo (negativa = baja)
CREATE TABLE detalle_ajuste (
  id_detalle_ajuste int NOT NULL AUTO_INCREMENT,
  id_ajuste int NOT NULL,
  id_producto bigint NOT NULL,
  cantidad int NOT NULL,
  PRIMARY KEY (id_detalle_ajuste),
  KEY fk_da_ajuste (id_ajuste),
  KEY fk_da_producto (id_producto),
  CONSTRAINT fk_da_ajuste FOREIGN KEY (id_ajuste) REFERENCES ajuste_inventario (id_ajuste) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_da_producto FOREIGN KEY (id_producto) REFERENCES productos (id_producto) ON UPDATE CASCADE,
  CONSTRAINT chk_da_cantidad CHECK (cantidad <> 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- Datos de prueba
-- =====================================================

INSERT INTO roles (id_rol, nombre, descripcion) VALUES
(1, 'ADMIN', 'Acceso completo a todos los módulos del sistema'),
(2, 'EMPLEADO', 'Acceso limitado a operaciones básicas de inventario');

INSERT INTO estados (id_estado, nombre, descripcion) VALUES
(1, 'PENDIENTE', 'El registro fue iniciado pero no se ha completado'),
(2, 'COMPLETADA', 'La operación fue finalizada correctamente'),
(3, 'ANULADA', 'La operación fue cancelada y revertida');

INSERT INTO motivos_ajuste (id_motivo, nombre, descripcion) VALUES
(1, 'DAÑO', 'Unidades dañadas físicamente y fuera de uso'),
(2, 'ROBO', 'Unidades perdidas por hurto'),
(3, 'VENCIMIENTO', 'Productos vencidos o con fecha de caducidad cumplida'),
(4, 'CORRECCION', 'Corrección de error en el conteo físico'),
(5, 'OTRO', 'Motivo diferente a los anteriores');

INSERT INTO categorias (id_categoria, nombre, descripcion) VALUES
(1, 'Papelería', 'Útiles de escritorio, cuadernos y materiales de oficina'),
(2, 'Tecnología', 'Equipos electrónicos y accesorios'),
(3, 'Alimentos', 'Productos alimenticios no perecederos'),
(4, 'Limpieza', 'Productos de aseo e higiene personal y del hogar');

-- claves de prueba en texto plano porque password es varchar(20): admin123 y 123456
INSERT INTO usuarios (id_usuario, nombres, apellido_paterno, apellido_materno, correo, password, id_rol) VALUES
('1000000001', 'Sebastian', 'Gómez', 'Restrepo', 'admin@stockcrate.com', 'admin123', 1),
('1000000002', 'Andrés', 'Pérez', 'Londoño', 'empleado@stockcrate.com', '123456', 2);

INSERT INTO clientes (id_cliente, nombre_razon_social, apellido_paterno, apellido_materno, documento, telefono, correo) VALUES
('1001234567', 'Juan', 'García', NULL, '1001234567', '3001112233', 'juan@gmail.com'),
('900123456', 'Empresa ABC S.A.S', NULL, NULL, '900123456', '6044445566', 'compras@abc.com');

INSERT INTO proveedores (id_proveedor, nombre, nit, telefono, correo) VALUES
(1, 'Distribuidora El Sol', '800123456-1', '3009998877', 'ventas@elsol.com'),
(2, 'Papeles y Más S.A.S', '900654321-2', '3108887766', 'pedidos@papelesmas.co');

-- stock de prueba = movimientos de prueba: P001 = +50 compra -5 venta -3 ajuste = 42; P003 = +85 compra = 85
INSERT INTO productos (id_producto, codigo, nombre, descripcion, id_categoria, precio_venta, precio_compra, stock, stock_minimo) VALUES
(1, 'P001', 'Cuaderno universitario', 'Cuaderno 100 hojas doble línea', 1, 4500.00, 2800.00, 42, 10),
(2, 'P002', 'Resma papel carta', 'Papel bond 75g x 500 hojas', 1, 16800.00, 11000.00, 20, 5),
(3, 'P003', 'Esfero azul', NULL, 1, 800.00, 400.00, 85, 20),
(4, 'P004', 'Mouse inalámbrico', 'Mouse USB con receptor nano', 2, 35000.00, 22000.00, 8, 3);

INSERT INTO producto_proveedor (id_producto, id_proveedor, precio_compra) VALUES
(1, 1, 2800.00),
(1, 2, 3000.00),
(2, 2, 11000.00),
(3, 1, 400.00);

INSERT INTO compras (id_compra, numero, id_proveedor, id_usuario, id_estado, total, observacion) VALUES
(1, 'COMP-0001', 1, '1000000001', 2, 225000.00, NULL);

INSERT INTO detalle_compra (id_detalle_compra, id_compra, id_producto, cantidad, precio_unitario, subtotal) VALUES
(1, 1, 1, 50, 2800.00, 140000.00),
(2, 1, 3, 85, 400.00, 85000.00);

INSERT INTO ventas (id_venta, id_cliente, id_usuario, id_estado, total, observacion) VALUES
(1, '1001234567', '1000000002', 2, 22500.00, NULL);

INSERT INTO detalle_venta (id_detalle_venta, id_venta, id_producto, cantidad, precio_unitario, subtotal) VALUES
(1, 1, 1, 5, 4500.00, 22500.00);

INSERT INTO ajuste_inventario (id_ajuste, numero, id_usuario, id_motivo, observacion) VALUES
(1, 'AJU-0001', '1000000001', 1, 'Se encontraron 3 cuadernos dañados por humedad en la bodega');

INSERT INTO detalle_ajuste (id_detalle_ajuste, id_ajuste, id_producto, cantidad) VALUES
(1, 1, 1, -3);

-- 
-- PARTE 2: datos de demostracion (opcional)
-- 

-- productos nuevos (P009 y P010 no se venden nunca, sirven para ver la rotacion)
INSERT INTO productos (id_producto, codigo, nombre, descripcion, id_categoria, precio_venta, precio_compra, stock, stock_minimo) VALUES
(5,  'P005', 'Marcador permanente', NULL, 1, 2500.00, 1400.00, 0, 15),
(6,  'P006', 'Teclado USB', 'Teclado en español con cable', 2, 48000.00, 31000.00, 0, 3),
(7,  'P007', 'Arroz 1 kg', NULL, 3, 4200.00, 3200.00, 0, 20),
(8,  'P008', 'Jabón líquido 1 L', NULL, 4, 9500.00, 6200.00, 0, 10),
(9,  'P009', 'Calculadora científica', NULL, 2, 62000.00, 45000.00, 0, 2),
(10, 'P010', 'Agenda 2025', 'Quedó de la temporada pasada', 1, 18000.00, 5000.00, 0, 3);

INSERT INTO producto_proveedor (id_producto, id_proveedor, precio_compra) VALUES
(2, 1, 11800.00),
(4, 1, 22000.00), (4, 2, 23500.00),
(5, 2, 1400.00),
(6, 1, 31000.00),
(7, 1, 3100.00), (7, 2, 3350.00),
(8, 1, 6200.00), (8, 2, 6000.00),
(9, 2, 45000.00),
(10, 2, 5000.00);

-- productos ya existentes: el precio de compra queda con el de la ultima compra
UPDATE productos SET precio_compra = 3000.00 WHERE id_producto = 1;
UPDATE productos SET precio_compra = 420.00 WHERE id_producto = 3;

-- ---------- compras ----------
INSERT INTO compras (id_compra, numero, id_proveedor, id_usuario, id_estado, fecha, total) VALUES
(2, 'COMP-0002', 2, '1000000001', 2, '2026-08-12 09:15:00', 580000.00),
(3, 'COMP-0003', 1, '1000000001', 2, '2026-08-20 10:30:00', 636000.00),
(4, 'COMP-0004', 1, '1000000001', 2, '2026-09-15 08:50:00', 558000.00),
(5, 'COMP-0005', 2, '1000000001', 2, '2026-10-10 14:00:00', 390000.00),
(6, 'COMP-0006', 1, '1000000001', 2, '2026-10-25 11:20:00', 208800.00),
(7, 'COMP-0007', 2, '1000000001', 3, '2026-10-28 16:40:00', 575000.00);  -- anulada

INSERT INTO detalle_compra (id_compra, id_producto, cantidad, precio_unitario, subtotal) VALUES
(2, 2, 40, 11000.00, 440000.00), (2, 5, 100, 1400.00, 140000.00),
(3, 4, 12, 22000.00, 264000.00), (3, 7, 120, 3100.00, 372000.00),
(4, 8, 40, 6200.00, 248000.00),  (4, 6, 10, 31000.00, 310000.00),
(5, 1, 30, 3000.00, 90000.00),   (5, 9, 5, 45000.00, 225000.00), (5, 10, 15, 5000.00, 75000.00),
(6, 7, 60, 3200.00, 192000.00),  (6, 3, 40, 420.00, 16800.00),
(7, 2, 50, 11500.00, 575000.00);

-- ---------- ventas ----------
INSERT INTO ventas (id_venta, id_cliente, id_usuario, id_estado, fecha, total) VALUES
(2,  '900123456',  '1000000002', 2, '2026-08-25 10:05:00', 243000.00),
(3,  NULL,         '1000000002', 2, '2026-08-30 15:10:00', 121000.00),
(4,  '1001234567', '1000000002', 2, '2026-09-05 11:45:00', 168000.00),
(5,  '900123456',  '1000000001', 2, '2026-09-18 09:30:00', 264400.00),
(6,  NULL,         '1000000002', 2, '2026-09-27 17:00:00', 238500.00),
(7,  '1001234567', '1000000002', 2, '2026-10-03 12:25:00', 146000.00),
(8,  '900123456',  '1000000001', 2, '2026-10-14 10:10:00', 325000.00),
(9,  NULL,         '1000000002', 2, '2026-10-22 16:35:00', 62000.00),
(10, '900123456',  '1000000001', 2, '2026-10-29 09:55:00', 345600.00),
(11, '1001234567', '1000000002', 3, '2026-10-30 13:00:00', 175000.00),  -- anulada
(12, NULL,         '1000000002', 2, '2026-11-02 11:15:00', 181000.00),
(13, '1001234567', '1000000002', 2, '2026-11-03 15:45:00', 45000.00);

INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario, subtotal) VALUES
(2, 2, 10, 16800.00, 168000.00), (2, 5, 30, 2500.00, 75000.00),
(3, 4, 3, 35000.00, 105000.00),  (3, 3, 20, 800.00, 16000.00),
(4, 7, 40, 4200.00, 168000.00),
(5, 1, 15, 4500.00, 67500.00),   (5, 5, 25, 2500.00, 62500.00), (5, 2, 8, 16800.00, 134400.00),
(6, 8, 15, 9500.00, 142500.00),  (6, 6, 2, 48000.00, 96000.00),
(7, 7, 30, 4200.00, 126000.00),  (7, 3, 25, 800.00, 20000.00),
(8, 1, 20, 4500.00, 90000.00),   (8, 4, 4, 35000.00, 140000.00), (8, 8, 10, 9500.00, 95000.00),
(9, 5, 20, 2500.00, 50000.00),   (9, 3, 15, 800.00, 12000.00),
(10, 2, 12, 16800.00, 201600.00),(10, 6, 3, 48000.00, 144000.00),
(11, 4, 5, 35000.00, 175000.00),
(12, 7, 25, 4200.00, 105000.00), (12, 8, 8, 9500.00, 76000.00),
(13, 1, 10, 4500.00, 45000.00);

-- ---------- ajustes ----------
INSERT INTO ajuste_inventario (id_ajuste, numero, id_usuario, id_motivo, fecha, observacion) VALUES
(2, 'AJU-0002', '1000000001', 2, '2026-09-30 18:00:00', 'Faltaron 2 mouse en el conteo, se presume hurto'),
(3, 'AJU-0003', '1000000001', 3, '2026-10-20 08:30:00', 'Arroz con fecha vencida'),
(4, 'AJU-0004', '1000000001', 1, '2026-10-31 09:10:00', 'Marcadores secos por mala tapa');

INSERT INTO detalle_ajuste (id_ajuste, id_producto, cantidad) VALUES
(2, 4, -2),
(3, 7, -6),
(4, 5, -4);

-- ---------- recalcular el stock con los movimientos ----------
-- stock = compras completadas - ventas completadas + ajustes (los ajustes ya traen el signo)
UPDATE productos p SET p.stock =
    COALESCE((SELECT SUM(dc.cantidad) FROM detalle_compra dc
              JOIN compras c ON c.id_compra = dc.id_compra
              WHERE dc.id_producto = p.id_producto AND c.id_estado = 2), 0)
  - COALESCE((SELECT SUM(dv.cantidad) FROM detalle_venta dv
              JOIN ventas v ON v.id_venta = dv.id_venta
              WHERE dv.id_producto = p.id_producto AND v.id_estado = 2), 0)
  + COALESCE((SELECT SUM(da.cantidad) FROM detalle_ajuste da
              WHERE da.id_producto = p.id_producto), 0);

-- 
-- PARTE 3: consultas para la gerencia (vistas)
-- 

-- 1. Que hay que reponer ya? ----------------------------------------
-- Productos en el stock minimo o por debajo, cuanto pedir y a que proveedor
-- (el que tenga el precio mas barato en producto_proveedor).
-- La cantidad sugerida deja el stock en el doble del minimo.
CREATE OR REPLACE VIEW v_stock_critico AS
SELECT
  p.id_producto,
  p.codigo,
  p.nombre,
  c.nombre AS categoria,
  p.stock,
  p.stock_minimo,
  CASE WHEN p.stock = 0 THEN 'SIN STOCK'
       WHEN p.stock <= p.stock_minimo THEN 'CRITICO'
  END AS nivel,
  (p.stock_minimo * 2 - p.stock) AS unidades_sugeridas,
  (SELECT pr.nombre
     FROM producto_proveedor pp JOIN proveedores pr ON pr.id_proveedor = pp.id_proveedor
    WHERE pp.id_producto = p.id_producto AND pr.activo = 1
    ORDER BY pp.precio_compra ASC LIMIT 1) AS proveedor_sugerido,
  COALESCE((SELECT MIN(pp.precio_compra)
              FROM producto_proveedor pp JOIN proveedores pr ON pr.id_proveedor = pp.id_proveedor
             WHERE pp.id_producto = p.id_producto AND pr.activo = 1),
           p.precio_compra) AS precio_unitario,
  (p.stock_minimo * 2 - p.stock) * COALESCE((SELECT MIN(pp.precio_compra)
              FROM producto_proveedor pp JOIN proveedores pr ON pr.id_proveedor = pp.id_proveedor
             WHERE pp.id_producto = p.id_producto AND pr.activo = 1),
           p.precio_compra) AS costo_reposicion
FROM productos p
JOIN categorias c ON c.id_categoria = p.id_categoria
WHERE p.activo = 1 AND p.stock <= p.stock_minimo;


-- 2. Cuanta plata hay metida en el inventario? ---------------------
-- Por categoria: unidades, lo que costo y lo que valdria si se vende todo.
CREATE OR REPLACE VIEW v_valor_inventario AS
SELECT
  c.id_categoria,
  c.nombre AS categoria,
  COUNT(p.id_producto) AS productos,
  COALESCE(SUM(p.stock), 0) AS unidades,
  COALESCE(SUM(p.stock * p.precio_compra), 0) AS valor_costo,
  COALESCE(SUM(p.stock * p.precio_venta), 0) AS valor_venta,
  COALESCE(SUM(p.stock * (p.precio_venta - p.precio_compra)), 0) AS utilidad_potencial,
  ROUND(100 * COALESCE(SUM(p.stock * p.precio_compra), 0) /
        NULLIF((SELECT SUM(stock * precio_compra) FROM productos WHERE activo = 1), 0), 1) AS porcentaje_del_total
FROM categorias c
LEFT JOIN productos p ON p.id_categoria = c.id_categoria AND p.activo = 1
WHERE c.activo = 1
GROUP BY c.id_categoria, c.nombre;


-- 3. Que productos dejan mas ganancia? -----------------------------
-- Ingresos, costo y utilidad por producto. El costo se calcula con el
-- precio_compra actual del producto (es una aproximacion, la BD no guarda
-- el costo al momento de cada venta).
CREATE OR REPLACE VIEW v_rentabilidad_producto AS
SELECT
  p.id_producto,
  p.codigo,
  p.nombre,
  c.nombre AS categoria,
  SUM(dv.cantidad) AS unidades_vendidas,
  SUM(dv.subtotal) AS ingresos,
  SUM(dv.cantidad * p.precio_compra) AS costo_estimado,
  SUM(dv.subtotal) - SUM(dv.cantidad * p.precio_compra) AS utilidad,
  ROUND(100 * (SUM(dv.subtotal) - SUM(dv.cantidad * p.precio_compra)) / NULLIF(SUM(dv.subtotal), 0), 1) AS margen_porcentaje
FROM detalle_venta dv
JOIN ventas v ON v.id_venta = dv.id_venta
JOIN estados e ON e.id_estado = v.id_estado AND e.nombre = 'COMPLETADA'
JOIN productos p ON p.id_producto = dv.id_producto
JOIN categorias c ON c.id_categoria = p.id_categoria
GROUP BY p.id_producto, p.codigo, p.nombre, c.nombre;


-- 4. Clasificacion ABC (Pareto) ------------------------------------
-- A = los productos que juntos hacen el 80% de las ventas,
-- B = el siguiente 15%, C = el 5% restante.
-- Sirve para decidir en cuales productos hay que cuidar mas el stock.
CREATE OR REPLACE VIEW v_clasificacion_abc AS
SELECT
  t.*,
  CASE WHEN t.porcentaje_acumulado - t.porcentaje <= 80 THEN 'A'
       WHEN t.porcentaje_acumulado - t.porcentaje <= 95 THEN 'B'
       ELSE 'C' END AS clase
FROM (
  SELECT
    r.id_producto, r.codigo, r.nombre, r.ingresos,
    ROUND(100 * r.ingresos / SUM(r.ingresos) OVER (), 2) AS porcentaje,
    ROUND(100 * SUM(r.ingresos) OVER (ORDER BY r.ingresos DESC, r.id_producto) / SUM(r.ingresos) OVER (), 2) AS porcentaje_acumulado
  FROM v_rentabilidad_producto r
) t;


-- 5. Como van las ventas mes a mes? --------------------------------
-- Ventas y compras por mes, utilidad de caja (ventas - compras) y la
-- variacion de las ventas frente al mes anterior.
CREATE OR REPLACE VIEW v_resumen_mensual AS
SELECT
  m.mes,
  m.ventas,
  m.total_vendido,
  m.total_comprado,
  m.total_vendido - m.total_comprado AS diferencia,
  ROUND(m.total_vendido / NULLIF(m.ventas, 0), 0) AS ticket_promedio,
  ROUND(100 * (m.total_vendido - LAG(m.total_vendido) OVER (ORDER BY m.mes))
        / NULLIF(LAG(m.total_vendido) OVER (ORDER BY m.mes), 0), 1) AS variacion_ventas_porcentaje
FROM (
  SELECT meses.mes,
         (SELECT COUNT(*) FROM ventas v JOIN estados e ON e.id_estado = v.id_estado
           WHERE e.nombre = 'COMPLETADA' AND DATE_FORMAT(v.fecha, '%Y-%m') = meses.mes) AS ventas,
         (SELECT COALESCE(SUM(v.total), 0) FROM ventas v JOIN estados e ON e.id_estado = v.id_estado
           WHERE e.nombre = 'COMPLETADA' AND DATE_FORMAT(v.fecha, '%Y-%m') = meses.mes) AS total_vendido,
         (SELECT COALESCE(SUM(c.total), 0) FROM compras c JOIN estados e ON e.id_estado = c.id_estado
           WHERE e.nombre = 'COMPLETADA' AND DATE_FORMAT(c.fecha, '%Y-%m') = meses.mes) AS total_comprado
  FROM (
    SELECT DATE_FORMAT(fecha, '%Y-%m') AS mes FROM ventas
    UNION
    SELECT DATE_FORMAT(fecha, '%Y-%m') FROM compras
  ) meses
) m;


-- 6. Que productos estan "durmiendo" en bodega? --------------------
-- Productos con stock que no se venden hace 90 dias o mas (o nunca se han
-- vendido). La plata inmovilizada es stock * precio de compra.
CREATE OR REPLACE VIEW v_sin_rotacion AS
SELECT
  p.id_producto,
  p.codigo,
  p.nombre,
  c.nombre AS categoria,
  p.stock,
  (SELECT MAX(v.fecha)
     FROM detalle_venta dv JOIN ventas v ON v.id_venta = dv.id_venta
     JOIN estados e ON e.id_estado = v.id_estado AND e.nombre = 'COMPLETADA'
    WHERE dv.id_producto = p.id_producto) AS ultima_venta,
  DATEDIFF(CURDATE(), (SELECT MAX(v.fecha)
     FROM detalle_venta dv JOIN ventas v ON v.id_venta = dv.id_venta
     JOIN estados e ON e.id_estado = v.id_estado AND e.nombre = 'COMPLETADA'
    WHERE dv.id_producto = p.id_producto)) AS dias_sin_vender,
  p.stock * p.precio_compra AS capital_inmovilizado
FROM productos p
JOIN categorias c ON c.id_categoria = p.id_categoria
WHERE p.activo = 1 AND p.stock > 0
  AND NOT EXISTS (
    SELECT 1 FROM detalle_venta dv JOIN ventas v ON v.id_venta = dv.id_venta
    JOIN estados e ON e.id_estado = v.id_estado AND e.nombre = 'COMPLETADA'
    WHERE dv.id_producto = p.id_producto AND v.fecha >= DATE_SUB(CURDATE(), INTERVAL 90 DAY));


-- 7. Para cuantos dias alcanza el stock? ---------------------------
-- Con el promedio de ventas de los ultimos 30 dias calcula los dias de
-- cobertura. Si un producto no se vendio en 30 dias, la cobertura queda NULL.
CREATE OR REPLACE VIEW v_cobertura_stock AS
SELECT
  p.id_producto,
  p.codigo,
  p.nombre,
  p.stock,
  COALESCE(SUM(dv.cantidad), 0) AS vendido_30_dias,
  ROUND(COALESCE(SUM(dv.cantidad), 0) / 30, 2) AS promedio_diario,
  ROUND(p.stock / NULLIF(SUM(dv.cantidad) / 30, 0), 0) AS dias_de_cobertura
FROM productos p
LEFT JOIN (
  SELECT dv.id_producto, dv.cantidad
    FROM detalle_venta dv JOIN ventas v ON v.id_venta = dv.id_venta
    JOIN estados e ON e.id_estado = v.id_estado AND e.nombre = 'COMPLETADA'
   WHERE v.fecha >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
) dv ON dv.id_producto = p.id_producto
WHERE p.activo = 1
GROUP BY p.id_producto, p.codigo, p.nombre, p.stock;


-- 8. A que proveedores se les compra mas? --------------------------
CREATE OR REPLACE VIEW v_compras_proveedor AS
SELECT
  pr.id_proveedor,
  pr.nombre AS proveedor,
  COUNT(c.id_compra) AS compras,
  COALESCE(SUM(c.total), 0) AS total_comprado,
  ROUND(COALESCE(AVG(c.total), 0), 0) AS compra_promedio,
  MAX(c.fecha) AS ultima_compra,
  ROUND(100 * COALESCE(SUM(c.total), 0) / NULLIF(SUM(SUM(c.total)) OVER (), 0), 1) AS porcentaje_del_gasto
FROM proveedores pr
LEFT JOIN compras c ON c.id_proveedor = pr.id_proveedor
  AND c.id_estado = (SELECT id_estado FROM estados WHERE nombre = 'COMPLETADA')
WHERE pr.activo = 1
GROUP BY pr.id_proveedor, pr.nombre;


-- 9. Quien vende mas barato? ---------------------------------------
-- Cada producto con los precios de sus proveedores y cuanto mas caro es
-- cada uno frente al mejor precio.
CREATE OR REPLACE VIEW v_comparativo_proveedores AS
SELECT
  p.id_producto,
  p.codigo,
  p.nombre AS producto,
  pr.nombre AS proveedor,
  pp.precio_compra,
  MIN(pp.precio_compra) OVER (PARTITION BY p.id_producto) AS mejor_precio,
  pp.precio_compra - MIN(pp.precio_compra) OVER (PARTITION BY p.id_producto) AS sobrecosto,
  CASE WHEN pp.precio_compra = MIN(pp.precio_compra) OVER (PARTITION BY p.id_producto)
       THEN 'SI' ELSE 'NO' END AS es_el_mejor
FROM producto_proveedor pp
JOIN productos p ON p.id_producto = pp.id_producto
JOIN proveedores pr ON pr.id_proveedor = pp.id_proveedor
WHERE p.activo = 1 AND pr.activo = 1;


-- 10. Cuanto se pierde por danos, robos y vencimientos? ------------
-- Solo los ajustes que bajan stock, valorizados al precio de compra.
CREATE OR REPLACE VIEW v_perdidas_ajustes AS
SELECT
  m.nombre AS motivo,
  COUNT(DISTINCT a.id_ajuste) AS ajustes,
  SUM(-da.cantidad) AS unidades_perdidas,
  SUM(-da.cantidad * p.precio_compra) AS valor_perdido
FROM ajuste_inventario a
JOIN motivos_ajuste m ON m.id_motivo = a.id_motivo
JOIN detalle_ajuste da ON da.id_ajuste = a.id_ajuste
JOIN productos p ON p.id_producto = da.id_producto
WHERE da.cantidad < 0
GROUP BY m.nombre;


-- 11. Quienes son los mejores clientes? ----------------------------
-- Las ventas sin cliente se agrupan como "Mostrador".
CREATE OR REPLACE VIEW v_mejores_clientes AS
SELECT
  COALESCE(cl.id_cliente, '-') AS id_cliente,
  COALESCE(NULLIF(TRIM(CONCAT_WS(' ', cl.nombre_razon_social, cl.apellido_paterno, cl.apellido_materno)), ''), 'Mostrador (sin cliente)') AS cliente,
  COUNT(v.id_venta) AS compras,
  SUM(v.total) AS total_comprado,
  ROUND(AVG(v.total), 0) AS ticket_promedio,
  MAX(v.fecha) AS ultima_compra
FROM ventas v
JOIN estados e ON e.id_estado = v.id_estado AND e.nombre = 'COMPLETADA'
LEFT JOIN clientes cl ON cl.id_cliente = v.id_cliente
GROUP BY cl.id_cliente, cl.nombre_razon_social, cl.apellido_paterno, cl.apellido_materno;


-- 12. Como le va a cada empleado? ----------------------------------
CREATE OR REPLACE VIEW v_ventas_por_usuario AS
SELECT
  u.id_usuario,
  CONCAT(u.nombres, ' ', u.apellido_paterno) AS usuario,
  r.nombre AS rol,
  COUNT(v.id_venta) AS ventas,
  COALESCE(SUM(v.total), 0) AS total_vendido,
  ROUND(COALESCE(AVG(v.total), 0), 0) AS ticket_promedio
FROM usuarios u
JOIN roles r ON r.id_rol = u.id_rol
LEFT JOIN ventas v ON v.id_usuario = u.id_usuario
  AND v.id_estado = (SELECT id_estado FROM estados WHERE nombre = 'COMPLETADA')
WHERE u.estado = 1
GROUP BY u.id_usuario, u.nombres, u.apellido_paterno, r.nombre;


-- 13. Resumen para la pantalla de inicio (una sola fila) -----------
-- Los indicadores principales del mes actual y del inventario.
CREATE OR REPLACE VIEW v_resumen_gerencial AS
SELECT
  (SELECT COALESCE(SUM(v.total), 0) FROM ventas v JOIN estados e ON e.id_estado = v.id_estado
    WHERE e.nombre = 'COMPLETADA' AND DATE_FORMAT(v.fecha, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m')) AS ventas_mes,
  (SELECT COALESCE(SUM(c.total), 0) FROM compras c JOIN estados e ON e.id_estado = c.id_estado
    WHERE e.nombre = 'COMPLETADA' AND DATE_FORMAT(c.fecha, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m')) AS compras_mes,
  (SELECT COALESCE(SUM(stock * precio_compra), 0) FROM productos WHERE activo = 1) AS valor_inventario,
  (SELECT COUNT(*) FROM productos WHERE activo = 1 AND stock <= stock_minimo) AS productos_en_alerta,
  (SELECT COALESCE(SUM(capital_inmovilizado), 0) FROM v_sin_rotacion) AS capital_inmovilizado,
  (SELECT COALESCE(SUM(valor_perdido), 0) FROM v_perdidas_ajustes) AS perdidas_por_ajustes,
  (SELECT ROUND(100 * SUM(e.nombre = 'ANULADA') / NULLIF(COUNT(*), 0), 1)
     FROM ventas v JOIN estados e ON e.id_estado = v.id_estado) AS ventas_anuladas_porcentaje;
