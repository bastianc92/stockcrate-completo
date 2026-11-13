# StockCrate

**Sistema web para la gestión de inventarios de una microempresa comercial.**

StockCrate es una aplicación web desarrollada como proyecto académico del programa Tecnología en Desarrollo de Software del ITM, en Medellín, Colombia.

Su propósito es facilitar el control y la administración de inventarios mediante una plataforma que permite gestionar productos, registrar movimientos de mercancía, consultar información y generar reportes para apoyar las actividades administrativas.

## Descripción general

El sistema permite administrar las operaciones principales de un inventario desde una interfaz web. Cuenta con dos roles de usuario:

- **Administrador (ADMIN):** tiene acceso a las funciones administrativas y a los reportes de gestión.
- **Empleado (EMPLEADO):** puede realizar las operaciones habilitadas para su rol, de acuerdo con los permisos establecidos en el sistema.

Entre sus principales funcionalidades se encuentran:

- Gestión de productos y catálogos.
- Administración de categorías, proveedores y clientes.
- Registro de compras y entradas de mercancía.
- Registro de ventas y salidas de inventario.
- Ajustes de existencias.
- Consulta del historial de movimientos.
- Alertas de productos con existencias bajas.
- Reportes e indicadores para apoyar la gestión del inventario.

## Tecnologías utilizadas

| Componente                     | Tecnología                       |
| ------------------------------ | -------------------------------- |
| Frontend                       | HTML5, CSS3 y JavaScript         |
| Backend                        | Python y Flask                   |
| API                            | Flask REST                       |
| Base de datos                  | MariaDB                          |
| Conexión a la base de datos    | PyMySQL                          |
| Entorno local de base de datos | XAMPP                            |
| Autenticación                  | Tokens Bearer y control de roles |

## Estructura del proyecto

```text
StockCrate/
│
├── backend/
│   ├── routes/
│   │   ├── catalogos.py
│   │   ├── movimientos.py
│   │   ├── productos.py
│   │   └── reportes.py
│   ├── app.py
│   ├── auth.py
│   ├── config.py
│   ├── db.py
│   ├── helpers.py
│   ├── requirements.txt
│   ├── .env.example
│   └── README.md
│
├── database/
│   └── stockcrate.sql
│
├── frontend/
│   ├── css/
│   │   └── estilos.css
│   ├── js/
│   │   └── main.js
│   ├── index.html
│   └── login.html
│
├── .gitignore
└── README.md
```

## Base de datos

El proyecto utiliza MariaDB y cuenta con una base de datos denominada `stockcrate`, organizada en 15 tablas relacionadas con la gestión del inventario y sus operaciones.

El archivo `database/stockcrate.sql` contiene el script para crear e inicializar la estructura de la base de datos y sus datos de demostración.

La base de datos debe importarse previamente en MariaDB antes de ejecutar la aplicación.

## Funcionamiento del backend

El backend está desarrollado con Python y Flask. Se encarga de procesar las solicitudes del frontend, consultar y modificar la información almacenada en MariaDB y aplicar las reglas de negocio correspondientes.

La API utiliza la dirección local:

```text
http://localhost:5000/api
```

La autenticación se realiza mediante tokens Bearer. Después de iniciar sesión, el token se utiliza en las solicitudes que requieren autenticación.

El sistema también valida los permisos de acuerdo con el rol del usuario, tanto en la interfaz como en las rutas protegidas del backend.

Para conocer los pasos de instalación, configuración y ejecución, consulta el archivo `backend/README.md`.

## Módulos y funcionalidades

| Módulo        | Funcionalidad                                                            |
| ------------- | ------------------------------------------------------------------------ |
| Autenticación | Inicio de sesión y control de acceso por roles.                          |
| Productos     | Consulta, creación, edición y desactivación de productos.                |
| Catálogos     | Administración de categorías, proveedores, clientes y motivos de ajuste. |
| Compras       | Registro de entradas de mercancía y actualización de existencias.        |
| Ventas        | Registro de salidas de mercancía y control de existencias.               |
| Ajustes       | Corrección de existencias mediante movimientos de ajuste.                |
| Historial     | Consulta de los movimientos registrados.                                 |
| Reportes      | Indicadores y consultas para apoyar la gestión administrativa.           |

Las existencias se actualizan mediante las operaciones de compras, ventas y ajustes, manteniendo la relación entre los movimientos y el inventario.

## Reportes

El módulo de reportes está orientado a proporcionar información útil para la toma de decisiones administrativas.

Incluye consultas relacionadas con:

- Resumen general del inventario.
- Productos con stock crítico.
- Valor del inventario.
- Rentabilidad.
- Clasificación ABC.
- Resumen mensual.
- Productos sin rotación.
- Cobertura de stock.
- Compras por proveedor.
- Comparativo de proveedores.
- Pérdidas por ajustes.
- Mejores clientes.
- Ventas por usuario.

El acceso a este módulo está restringido al rol administrador.

## Pruebas realizadas

Durante el desarrollo se realizaron pruebas funcionales en un entorno local con XAMPP y MariaDB.

Se verificaron, entre otros aspectos:

- Inicio de sesión con los roles administrador y empleado.
- Consulta, creación, modificación y eliminación de productos.
- Registro de compras y actualización de existencias.
- Registro de ventas y actualización de existencias.
- Registro de ajustes de inventario.
- Consulta del historial de movimientos.
- Acceso a los reportes según los permisos del usuario.
- Validación de restricciones de acceso para el rol empleado.

Estas verificaciones permitieron comprobar el funcionamiento de los principales módulos de la aplicación en el entorno local de desarrollo.

## Instalación y ejecución

Para ejecutar StockCrate localmente se requiere:

- Windows o un sistema operativo compatible.
- Python.
- XAMPP con MariaDB.
- Un navegador web.

Los pasos generales son:

1. Descargar o clonar el repositorio.
2. Iniciar el servicio de MariaDB desde XAMPP.
3. Crear e importar la base de datos utilizando `database/stockcrate.sql`.
4. Configurar las variables de conexión del backend a partir de `backend/.env.example`.
5. Instalar las dependencias de Python indicadas en `backend/requirements.txt`.
6. Iniciar el backend.
7. Abrir la interfaz web desde el navegador.

Los comandos y las instrucciones detalladas de configuración se encuentran en `backend/README.md`.

## Consideraciones técnicas

- La aplicación está preparada para ejecutarse en un entorno local de desarrollo.
- El backend utiliza PyMySQL para conectarse con MariaDB.
- La base de datos no se crea automáticamente al iniciar el backend; debe importarse previamente.
- Los tokens de sesión se almacenan en memoria y se pierden cuando se reinicia el backend.
- Para un despliegue en producción sería necesario fortalecer la configuración de seguridad, la gestión de sesiones y los parámetros del servidor.

## Autor

**Sebastián Castañeda Diosa**
