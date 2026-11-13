// =====================================================
// StockCrate - JavaScript principal
// Sistema de Gestión de Inventarios
// =====================================================

// URL base del backend Flask. La cambio aquí y afecta todo el archivo.
const API_URL = "http://localhost:5000/api";

// Variables globales de la sesión y los datos
let sesion = null;
let productos = [];
let categorias = [];
let proveedores = [];
let clientes = [];


// ── Utilidades ──────────────────────────────────────

// Cambia los caracteres especiales de HTML para que lo que venga de la
// base de datos no se ejecute como código (evita XSS)
function escapar(texto) {
  return String(texto ?? "").replace(/[&<>"']/g, c => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[c]));
}

// Un solo fetch para todo: pone el token si existe, convierte la
// respuesta a JSON y lanza un Error con el mensaje del backend si falla
async function api(ruta, opciones = {}) {
  const headers = { "Content-Type": "application/json" };
  if (sesion && sesion.token) headers.Authorization = "Bearer " + sesion.token;

  const respuesta = await fetch(API_URL + ruta, { ...opciones, headers });

  // Token vencido o inválido: toca volver a iniciar sesión
  if (respuesta.status === 401) {
    localStorage.removeItem("sesion");
    window.location.href = "login.html";
    throw new Error("Sesión expirada");
  }

  if (!respuesta.ok) {
    let mensaje = "Error en el servidor";
    try {
      const err = await respuesta.json();
      mensaje = err.mensaje || mensaje;
    } catch (e) { /* la respuesta no era JSON */ }
    throw new Error(mensaje);
  }

  return respuesta.status === 204 ? null : respuesta.json();
}

// En la base de datos el rol viene como ADMIN o EMPLEADO (mayúsculas),
// por eso lo paso a minúscula antes de comparar
function esAdmin() {
  const rol = String((sesion && sesion.rol) || "").toLowerCase();
  return rol === "admin" || rol === "administrador";
}

// En clientes el nombre está partido en nombre_razon_social y apellidos
function nombreCliente(c) {
  return [c.nombre_razon_social, c.apellido_paterno, c.apellido_materno].filter(Boolean).join(" ");
}

function formatearFecha(fecha) {
  const d = new Date(fecha);
  return isNaN(d) ? "-" : d.toLocaleString("es-CO");
}

// Llena un select con una lista de objetos
function llenarSelect(select, lista, campoId, textoFn, textoVacio) {
  select.innerHTML = '<option value="">' + escapar(textoVacio) + "</option>" +
    lista.map(x => `<option value="${escapar(x[campoId])}">${escapar(textoFn(x))}</option>`).join("");
}

// Pone "Cargando..." / mensajes en el tbody de una tabla
function filaMensaje(tbody, columnas, texto) {
  tbody.innerHTML = `<tr><td colspan="${columnas}" class="tabla-vacia">${escapar(texto)}</td></tr>`;
}


// ── Sesión y roles ──────────────────────────────────

function verificarSesion() {
  let guardada = null;
  try {
    guardada = JSON.parse(localStorage.getItem("sesion"));
  } catch (e) { /* sesión dañada, se trata como si no existiera */ }

  if (!guardada) {
    window.location.href = "login.html";
    return false;
  }

  sesion = guardada;
  const nombre = sesion.nombre || "Usuario";
  const rolTexto = esAdmin() ? "Administrador" : "Empleado";

  document.getElementById("topbar-user").textContent = "Bienvenido, " + nombre;
  document.getElementById("sidebar-rol").textContent = "Rol: " + rolTexto;
  document.getElementById("topbar-avatar").textContent = nombre.charAt(0).toUpperCase();

  // Lo que es solo de administrador se esconde para el empleado.
  // Esto es solo comodidad visual: el backend también tiene que validar el rol.
  document.querySelectorAll("[data-solo-admin]").forEach(el => {
    el.hidden = !esAdmin();
  });

  return true;
}

function cerrarSesion() {
  if (!confirm("¿Cerrar sesión?")) return;
  localStorage.removeItem("sesion");
  window.location.href = "login.html";
}


// ── Navegación entre secciones ─────────────────────

const TITULOS = {
  "inicio": "Inicio - Panel de control",
  "productos": "Productos - Catálogo",
  "nuevo-producto": "Nuevo producto",
  "categorias": "Categorías",
  "entradas": "Entradas de inventario",
  "salidas": "Salidas de inventario",
  "ajustes": "Ajuste de inventario",
  "historial": "Historial de movimientos",
  "proveedores": "Proveedores",
  "clientes": "Clientes",
  "reportes": "Reportes de gerencia"
};

function mostrarSeccion(id) {
  document.querySelectorAll(".page-section").forEach(sec => sec.classList.remove("active"));
  const seccion = document.getElementById(id);
  if (seccion) seccion.classList.add("active");

  // Marco el item del menú como activo
  document.querySelectorAll(".nav-item").forEach(item => {
    item.classList.toggle("active", item.dataset.seccion === id);
  });

  document.querySelector(".topbar-title").textContent = TITULOS[id] || "StockCrate";
  ocultarAlertas();
  cerrarMenu();
  window.scrollTo(0, 0);

  // Cargo los datos que necesita cada sección
  if (id === "inicio" || id === "productos") cargarProductos();
  if (id === "inicio" && esAdmin()) cargarResumen();
  if (id === "reportes") prepararReportes();
  if (id === "categorias") cargarCategorias();
  if (id === "proveedores") cargarProveedores();
  if (id === "clientes") cargarClientes();
  if (id === "historial") cargarHistorial();
  if (id === "entradas") prepararMovimiento("entrada");
  if (id === "salidas") prepararMovimiento("salida");
  if (id === "ajustes") prepararAjuste();
}

// Menú lateral en celular
function abrirMenu() {
  document.getElementById("sidebar").classList.add("abierto");
  document.getElementById("overlay").classList.add("visible");
}

function cerrarMenu() {
  document.getElementById("sidebar").classList.remove("abierto");
  document.getElementById("overlay").classList.remove("visible");
}


// ── Alertas ─────────────────────────────────────────

function mostrarAlerta(mensaje, tipo = "success") {
  const alerta = document.createElement("div");
  alerta.className = "alert alert-" + tipo;
  alerta.textContent = mensaje;
  alerta.setAttribute("role", "alert");

  const seccionActiva = document.querySelector(".page-section.active");
  if (seccionActiva) seccionActiva.insertBefore(alerta, seccionActiva.firstChild);

  setTimeout(() => alerta.remove(), 3500);
}

function ocultarAlertas() {
  document.querySelectorAll(".alert").forEach(a => a.remove());
}


// ── Productos ───────────────────────────────────────

async function cargarProductos() {
  const tbody = document.getElementById("tabla-productos-body");
  filaMensaje(tbody, 7, "Cargando...");

  try {
    productos = await api("/productos");
    renderizarProductos(productos);
  } catch (error) {
    console.warn("No se pudo cargar productos:", error.message);
    filaMensaje(tbody, 7, "No se pudo conectar con el servidor.");
    filaMensaje(document.getElementById("tabla-alertas-body"), 5, "No se pudo conectar con el servidor.");
    mostrarAlerta("No se pudo conectar con el servidor: " + error.message, "danger");
  }
}

function renderizarProductos(lista) {
  const tbody = document.getElementById("tabla-productos-body");

  if (!lista || lista.length === 0) {
    filaMensaje(tbody, 7, "No hay productos registrados.");
    actualizarStats();
    return;
  }

  tbody.innerHTML = lista.map(p => {
    const precio = Number(p.precio_venta).toLocaleString("es-CO");

    // Los botones de acciones solo salen si es administrador
    const acciones = esAdmin() ? `
                <td>
                    <div class="celda-acciones">
                        <button class="btn btn-secondary btn-sm" data-editar="producto" data-id="${escapar(p.id_producto)}">Editar</button>
                        <button class="btn btn-danger btn-sm" data-eliminar="${escapar(p.id_producto)}">Desactivar</button>
                    </div>
                </td>` : "";

    return `
            <tr>
                <td class="celda-codigo">${escapar(p.codigo)}</td>
                <td><strong>${escapar(p.nombre)}</strong></td>
                <td>${escapar(p.categoria_nombre || "Sin categoría")}</td>
                <td>$${precio}</td>
                <td><strong>${escapar(p.stock)}</strong> uds</td>
                <td>${badgeStock(p)}</td>${acciones}
            </tr>`;
  }).join("");

  actualizarStats();
}

function badgeStock(p) {
  if (p.stock === 0) return '<span class="badge badge-danger">Sin stock</span>';
  if (p.stock <= p.stock_minimo) return '<span class="badge badge-warning">Stock bajo</span>';
  return '<span class="badge badge-success">Disponible</span>';
}

function buscarProducto(termino) {
  const t = termino.toLowerCase();
  const filtrados = productos.filter(p =>
    String(p.nombre).toLowerCase().includes(t) ||
    String(p.codigo).toLowerCase().includes(t) ||
    String(p.categoria_nombre || "").toLowerCase().includes(t)
  );
  renderizarProductos(filtrados);
}

async function guardarProducto(e) {
  e.preventDefault();

  const stockMinimo = parseInt(document.getElementById("np-stock-minimo").value);

  const datos = {
    codigo: document.getElementById("np-codigo").value.trim(),
    nombre: document.getElementById("np-nombre").value.trim(),
    id_categoria: parseInt(document.getElementById("np-categoria").value),
    precio_venta: parseFloat(document.getElementById("np-precio").value),
    precio_compra: parseFloat(document.getElementById("np-precio-compra").value) || 0,
    stock: parseInt(document.getElementById("np-stock").value),
    // Si el campo está vacío uso 5, pero el 0 sí es un valor válido
    stock_minimo: isNaN(stockMinimo) ? 5 : stockMinimo,
    descripcion: document.getElementById("np-descripcion").value.trim() || null
  };

  if (!datos.codigo || !datos.nombre || !datos.id_categoria || isNaN(datos.precio_venta) || isNaN(datos.stock)) {
    mostrarAlerta("Completa todos los campos obligatorios.", "danger");
    return;
  }
  if (datos.precio_venta < 0 || datos.stock < 0 || datos.stock_minimo < 0) {
    mostrarAlerta("Los valores no pueden ser negativos.", "danger");
    return;
  }

  const boton = e.submitter;
  if (boton) boton.disabled = true;
  try {
    await api("/productos", { method: "POST", body: JSON.stringify(datos) });
    document.getElementById("form-nuevo-producto").reset();
    mostrarSeccion("productos");
    mostrarAlerta('Producto "' + datos.nombre + '" registrado.', "success");
  } catch (error) {
    mostrarAlerta(error.message, "danger");
  } finally {
    if (boton) boton.disabled = false;
  }
}

// El backend debería hacer borrado lógico (cambiar el estado), no borrar la fila,
// porque el producto ya puede estar en compras o ventas
async function desactivarProducto(id) {
  if (!confirm("¿Desactivar este producto?")) return;

  try {
    await api("/productos/" + id, { method: "DELETE" });
    mostrarAlerta("Producto desactivado.", "success");
    cargarProductos();
  } catch (error) {
    mostrarAlerta(error.message, "danger");
  }
}


// ── Categorías, proveedores y clientes ─────────────

async function cargarCategorias() {
  const tbody = document.getElementById("tabla-categorias-body");
  const columnas = esAdmin() ? 5 : 4;
  filaMensaje(tbody, columnas, "Cargando...");

  try {
    categorias = await api("/categorias");

    tbody.innerHTML = categorias.length === 0
      ? `<tr><td colspan="${columnas}" class="tabla-vacia">No hay categorías registradas.</td></tr>`
      : categorias.map(c => `
            <tr>
                <td>${escapar(c.id_categoria)}</td>
                <td><strong>${escapar(c.nombre)}</strong></td>
                <td>${escapar(c.descripcion || "-")}</td>
                <td>${c.activo ? '<span class="badge badge-success">Activa</span>' : '<span class="badge badge-danger">Inactiva</span>'}</td>
                ${botonEditar("categoria", c.id_categoria)}
            </tr>`).join("");

    // Aprovecho para llenar el select del formulario de nuevo producto
    llenarSelect(document.getElementById("np-categoria"), categorias, "id_categoria", c => c.nombre, "Selecciona una categoría");
  } catch (error) {
    console.warn("No se pudieron cargar categorías:", error.message);
    filaMensaje(tbody, columnas, "No se pudo conectar con el servidor.");
  }
}

async function cargarProveedores() {
  const tbody = document.getElementById("tabla-proveedores-body");
  const columnas = esAdmin() ? 6 : 5;
  filaMensaje(tbody, columnas, "Cargando...");

  try {
    proveedores = await api("/proveedores");

    tbody.innerHTML = proveedores.length === 0
      ? `<tr><td colspan="${columnas}" class="tabla-vacia">No hay proveedores registrados.</td></tr>`
      : proveedores.map(p => `
            <tr>
                <td>${escapar(p.id_proveedor)}</td>
                <td><strong>${escapar(p.nombre)}</strong></td>
                <td>${escapar(p.nit || "-")}</td>
                <td>${escapar(p.telefono || "-")}</td>
                <td>${escapar(p.correo || "-")}</td>
                ${botonEditar("proveedor", p.id_proveedor)}
            </tr>`).join("");
  } catch (error) {
    filaMensaje(tbody, columnas, "No se pudo conectar con el servidor.");
  }
}

async function cargarClientes() {
  const tbody = document.getElementById("tabla-clientes-body");
  const columnas = esAdmin() ? 6 : 5;
  filaMensaje(tbody, columnas, "Cargando...");

  try {
    clientes = await api("/clientes");

    tbody.innerHTML = clientes.length === 0
      ? `<tr><td colspan="${columnas}" class="tabla-vacia">No hay clientes registrados.</td></tr>`
      : clientes.map(c => `
            <tr>
                <td>${escapar(c.id_cliente)}</td>
                <td><strong>${escapar(nombreCliente(c))}</strong></td>
                <td>${escapar(c.documento || "-")}</td>
                <td>${escapar(c.telefono || "-")}</td>
                <td>${escapar(c.correo || "-")}</td>
                ${botonEditar("cliente", c.id_cliente)}
            </tr>`).join("");
  } catch (error) {
    filaMensaje(tbody, columnas, "No se pudo conectar con el servidor.");
  }
}

// Celda con el botón de editar (solo para administrador)
function botonEditar(entidad, id) {
  if (!esAdmin()) return "";
  return `<td><button class="btn btn-secondary btn-sm" data-editar="${entidad}" data-id="${escapar(id)}">Editar</button></td>`;
}


// ── Modal para crear y editar ───────────────────────

// Cada entidad dice qué campos tiene, su ruta en la API y cómo recargar la tabla
const ENTIDADES = {
  producto: {
    titulo: "producto", ruta: "/productos", id: "id_producto",
    lista: () => productos, recargar: cargarProductos,
    campos: [
      { n: "codigo", l: "Código", req: true },
      { n: "nombre", l: "Nombre", req: true },
      { n: "id_categoria", l: "Categoría", tipo: "categoria", req: true },
      { n: "precio_compra", l: "Precio de compra (COP)", tipo: "number" },
      { n: "precio_venta", l: "Precio de venta (COP)", tipo: "number", req: true },
      { n: "stock_minimo", l: "Stock mínimo", tipo: "number" },
      { n: "descripcion", l: "Descripción", tipo: "textarea" }
    ]
  },
  categoria: {
    titulo: "categoría", ruta: "/categorias", id: "id_categoria",
    lista: () => categorias, recargar: cargarCategorias,
    campos: [
      { n: "nombre", l: "Nombre", req: true },
      { n: "descripcion", l: "Descripción", tipo: "textarea" }
    ]
  },
  proveedor: {
    titulo: "proveedor", ruta: "/proveedores", id: "id_proveedor",
    lista: () => proveedores, recargar: cargarProveedores,
    campos: [
      { n: "nombre", l: "Nombre", req: true },
      { n: "nit", l: "NIT" },
      { n: "telefono", l: "Teléfono" },
      { n: "correo", l: "Correo", tipo: "email" },
      { n: "direccion", l: "Dirección" }
    ]
  },
  cliente: {
    titulo: "cliente", ruta: "/clientes", id: "id_cliente",
    lista: () => clientes, recargar: cargarClientes,
    // El documento es también el id_cliente, por eso no se puede cambiar al editar
    campos: [
      { n: "documento", l: "Documento (es el ID del cliente)", req: true, fijo: true },
      { n: "nombre_razon_social", l: "Nombre o razón social", req: true },
      { n: "apellido_paterno", l: "Primer apellido" },
      { n: "apellido_materno", l: "Segundo apellido" },
      { n: "telefono", l: "Teléfono" },
      { n: "correo", l: "Correo", tipo: "email" },
      { n: "direccion", l: "Dirección" }
    ]
  }
};

// Entidad e id que se están editando (id null = registro nuevo)
let modalActual = null;

function abrirModal(nombreEntidad, id) {
  const ent = ENTIDADES[nombreEntidad];
  const registro = id ? ent.lista().find(r => String(r[ent.id]) === String(id)) : {};
  if (!registro) return;

  modalActual = { nombreEntidad, id: id || null };
  document.getElementById("modal-titulo").textContent = (id ? "Editar " : "Nuevo ") + ent.titulo;

  document.getElementById("modal-campos").innerHTML = ent.campos.map(c => {
    const valor = registro[c.n] ?? "";
    const bloqueado = c.fijo && id ? "readonly" : "";
    const comun = `id="m-${c.n}" class="form-control" ${c.req ? "required" : ""} ${bloqueado}`;
    let control;

    if (c.tipo === "textarea") {
      control = `<textarea ${comun}>${escapar(valor)}</textarea>`;
    } else if (c.tipo === "categoria") {
      const opciones = categorias.map(cat =>
        `<option value="${escapar(cat.id_categoria)}" ${String(cat.id_categoria) === String(valor) ? "selected" : ""}>${escapar(cat.nombre)}</option>`
      ).join("");
      control = `<select ${comun}><option value="">Selecciona una categoría</option>${opciones}</select>`;
    } else if (c.tipo === "number") {
      control = `<input type="number" min="0" step="1" value="${escapar(valor)}" ${comun} />`;
    } else {
      control = `<input type="${c.tipo || "text"}" value="${escapar(valor)}" ${comun} />`;
    }

    const ancho = c.tipo === "textarea" ? " full-width" : "";
    return `<div class="form-group${ancho}"><label class="form-label" for="m-${c.n}">${c.l}${c.req ? " *" : ""}</label>${control}</div>`;
  }).join("");

  document.getElementById("modal").hidden = false;
  const primero = document.querySelector("#modal-campos .form-control");
  if (primero) primero.focus();
}

function cerrarModal() {
  document.getElementById("modal").hidden = true;
  modalActual = null;
}

async function guardarModal(e) {
  e.preventDefault();
  if (!modalActual) return;

  const ent = ENTIDADES[modalActual.nombreEntidad];
  const datos = {};

  ent.campos.forEach(c => {
    const valor = document.getElementById("m-" + c.n).value.trim();
    if (c.tipo === "number") datos[c.n] = valor === "" ? 0 : parseFloat(valor);
    else if (c.tipo === "categoria") datos[c.n] = parseInt(valor);
    else datos[c.n] = valor === "" && !c.req ? null : valor;
  });

  const editando = modalActual.id !== null;
  // En clientes el id es el documento y no es autoincrement
  if (modalActual.nombreEntidad === "cliente" && !editando) datos.id_cliente = datos.documento;
  const boton = e.submitter;
  if (boton) boton.disabled = true;

  try {
    await api(ent.ruta + (editando ? "/" + modalActual.id : ""), {
      method: editando ? "PUT" : "POST",
      body: JSON.stringify(datos)
    });
    cerrarModal();
    await ent.recargar();
    mostrarAlerta(editando ? "Cambios guardados." : "Registro creado.", "success");
  } catch (error) {
    mostrarAlerta(error.message, "danger");
  } finally {
    if (boton) boton.disabled = false;
  }
}


// ── Compras (entradas), ventas (salidas) y ajustes ──

// Trae productos y la lista que necesite el formulario cada vez que se abre,
// así el stock que se ve en el select está actualizado
async function prepararMovimiento(tipo) {
  const pre = tipo === "entrada" ? "ent" : "sal";
  const sProducto = document.getElementById(pre + "-producto");
  const sTercero = document.getElementById(pre + (tipo === "entrada" ? "-proveedor" : "-cliente"));

  try {
    productos = await api("/productos");
    llenarSelect(sProducto, productos, "id_producto", p => `${p.codigo} - ${p.nombre} (stock: ${p.stock})`, "Selecciona un producto");
  } catch (error) {
    sProducto.innerHTML = '<option value="">No se pudo cargar</option>';
  }

  try {
    if (tipo === "entrada") {
      proveedores = await api("/proveedores");
      llenarSelect(sTercero, proveedores, "id_proveedor", p => p.nombre, "Selecciona un proveedor");
    } else {
      clientes = await api("/clientes");
      llenarSelect(sTercero, clientes, "id_cliente", nombreCliente, "Sin cliente");
    }
  } catch (error) {
    sTercero.innerHTML = '<option value="">No se pudo cargar</option>';
  }
}

// Al elegir un producto, sugiero su precio (compra en entradas, venta en salidas)
function sugerirPrecio(tipo) {
  const pre = tipo === "entrada" ? "ent" : "sal";
  const id = document.getElementById(pre + "-producto").value;
  const producto = productos.find(p => String(p.id_producto) === id);
  if (producto) {
    document.getElementById(pre + "-precio").value = tipo === "entrada" ? producto.precio_compra : producto.precio_venta;
  }
}

// Una entrada se guarda como compra y una salida como venta.
// Mando la cabecera y una lista de detalles, igual que las tablas compras/detalle_compra
async function guardarMovimiento(e, tipo) {
  e.preventDefault();

  const pre = tipo === "entrada" ? "ent" : "sal";
  const idProducto = parseInt(document.getElementById(pre + "-producto").value);
  const cantidad = parseInt(document.getElementById(pre + "-cantidad").value);
  const precio = parseFloat(document.getElementById(pre + "-precio").value);
  const tercero = document.getElementById(pre + (tipo === "entrada" ? "-proveedor" : "-cliente")).value;
  const observacion = document.getElementById(pre + "-observacion").value.trim() || null;

  if (!idProducto || isNaN(cantidad) || cantidad <= 0 || isNaN(precio) || precio < 0) {
    mostrarAlerta("Completa todos los campos correctamente.", "danger");
    return;
  }
  if (tipo === "entrada" && !tercero) {
    mostrarAlerta("Selecciona el proveedor de la compra.", "danger");
    return;
  }

  // En una venta reviso que alcance el stock antes de mandar nada
  if (tipo === "salida") {
    const producto = productos.find(p => p.id_producto === idProducto);
    if (producto && cantidad > producto.stock) {
      mostrarAlerta("No hay suficiente stock: solo quedan " + producto.stock + " unidades.", "danger");
      return;
    }
  }

  const datos = {
    observacion: observacion,
    detalles: [{ id_producto: idProducto, cantidad: cantidad, precio_unitario: precio }]
  };
  // El id del proveedor es número, pero el del cliente es texto (es su documento)
  if (tipo === "entrada") datos.id_proveedor = parseInt(tercero);
  else if (tercero) datos.id_cliente = tercero;

  const boton = e.submitter;
  if (boton) boton.disabled = true;
  try {
    await api(tipo === "entrada" ? "/compras" : "/ventas", { method: "POST", body: JSON.stringify(datos) });
    document.getElementById("form-" + tipo).reset();
    mostrarSeccion("productos");
    mostrarAlerta((tipo === "entrada" ? "Compra registrada: +" : "Venta registrada: -") + cantidad + " unidades.", "success");
  } catch (error) {
    mostrarAlerta(error.message, "danger");
  } finally {
    if (boton) boton.disabled = false;
  }
}

async function prepararAjuste() {
  const sProducto = document.getElementById("aj-producto");
  const sMotivo = document.getElementById("aj-motivo");

  try {
    productos = await api("/productos");
    llenarSelect(sProducto, productos, "id_producto", p => `${p.codigo} - ${p.nombre} (stock: ${p.stock})`, "Selecciona un producto");
  } catch (error) {
    sProducto.innerHTML = '<option value="">No se pudo cargar</option>';
  }

  // Los motivos salen de la tabla motivos_ajuste
  try {
    const motivos = await api("/motivos-ajuste");
    llenarSelect(sMotivo, motivos, "id_motivo", m => m.nombre, "Selecciona un motivo");
  } catch (error) {
    sMotivo.innerHTML = '<option value="">No se pudo cargar</option>';
  }
}

// En detalle_ajuste la cantidad lleva signo: negativa baja el stock y positiva lo sube
async function guardarAjuste(e) {
  e.preventDefault();

  const idProducto = parseInt(document.getElementById("aj-producto").value);
  const idMotivo = parseInt(document.getElementById("aj-motivo").value);
  const cantidad = parseInt(document.getElementById("aj-cantidad").value);
  const baja = document.getElementById("aj-tipo").value === "baja";
  const observacion = document.getElementById("aj-observacion").value.trim() || null;

  if (!idProducto || !idMotivo || isNaN(cantidad) || cantidad <= 0) {
    mostrarAlerta("Completa todos los campos correctamente.", "danger");
    return;
  }

  const producto = productos.find(p => p.id_producto === idProducto);
  if (baja && producto && cantidad > producto.stock) {
    mostrarAlerta("No puedes bajar más de " + producto.stock + " unidades, que es el stock actual.", "danger");
    return;
  }

  const datos = {
    id_motivo: idMotivo,
    observacion: observacion,
    detalles: [{ id_producto: idProducto, cantidad: baja ? -cantidad : cantidad }]
  };

  const boton = e.submitter;
  if (boton) boton.disabled = true;
  try {
    await api("/ajustes", { method: "POST", body: JSON.stringify(datos) });
    document.getElementById("form-ajuste").reset();
    mostrarSeccion("productos");
    mostrarAlerta("Ajuste registrado: " + (baja ? "-" : "+") + cantidad + " unidades.", "success");
  } catch (error) {
    mostrarAlerta(error.message, "danger");
  } finally {
    if (boton) boton.disabled = false;
  }
}


// ── Historial ───────────────────────────────────────

const BADGE_TIPO = {
  compra: '<span class="badge badge-success">Compra</span>',
  venta: '<span class="badge badge-danger">Venta</span>',
  ajuste: '<span class="badge badge-warning">Ajuste</span>'
};

function badgeEstado(estado) {
  const e = String(estado || "").toUpperCase();
  if (e === "ANULADA") return '<span class="badge badge-danger">Anulada</span>';
  if (e === "PENDIENTE") return '<span class="badge badge-warning">Pendiente</span>';
  if (e === "COMPLETADA") return '<span class="badge badge-success">Completada</span>';
  return "-";
}

// El backend devuelve una fila por cada detalle de compras, ventas y ajustes
async function cargarHistorial() {
  const tbody = document.getElementById("tabla-historial-body");
  const columnas = esAdmin() ? 9 : 8;
  filaMensaje(tbody, columnas, "Cargando...");

  try {
    const historial = await api("/historial");

    if (historial.length === 0) {
      filaMensaje(tbody, columnas, "Todavía no hay movimientos registrados.");
      return;
    }

    tbody.innerHTML = historial.map(h => {
      // Solo se pueden anular compras y ventas que no estén anuladas
      const anulable = esAdmin() && h.tipo !== "ajuste" && String(h.estado).toUpperCase() !== "ANULADA";
      const acciones = esAdmin()
        ? `<td>${anulable ? `<button class="btn btn-danger btn-sm" data-anular="${escapar(h.tipo)}" data-id="${escapar(h.id)}">Anular</button>` : ""}</td>`
        : "";

      return `
            <tr>
                <td>${escapar(h.id)}</td>
                <td>${BADGE_TIPO[h.tipo] || escapar(h.tipo)}</td>
                <td><strong>${escapar(h.producto)}</strong></td>
                <td>${escapar(h.cantidad)}</td>
                <td>${escapar(h.detalle || "-")}</td>
                <td>${badgeEstado(h.estado)}</td>
                <td>${escapar(formatearFecha(h.fecha))}</td>
                <td>${escapar(h.usuario || "-")}</td>${acciones}
            </tr>`;
    }).join("");
  } catch (error) {
    filaMensaje(tbody, columnas, "No se pudo conectar con el servidor.");
  }
}

// Anular = cambiar el estado a ANULADA. El backend tiene que devolver el stock
async function anularDocumento(tipo, id) {
  if (!confirm("¿Anular este movimiento? El stock se devolverá a como estaba.")) return;

  try {
    await api("/" + tipo + "s/" + id + "/anular", { method: "PATCH" });
    mostrarAlerta("Movimiento anulado.", "success");
    cargarHistorial();
  } catch (error) {
    mostrarAlerta(error.message, "danger");
  }
}


// ── Reportes de gerencia (solo administrador) ──────

// Cada reporte dice qué pregunta responde y qué columnas muestra:
// [campo que viene del backend, título de la columna, tipo, texto si viene vacío]
const REPORTES = {
  "stock-critico": {
    titulo: "Stock crítico y reposición",
    pregunta: "¿Qué productos hay que reponer ya, cuántas unidades y con qué proveedor?",
    nota: "La cantidad sugerida deja el stock en el doble del mínimo. El proveedor sugerido es el que tiene el precio más bajo.",
    columnas: [["codigo", "Código"], ["nombre", "Producto"], ["stock", "Stock", "entero"], ["stock_minimo", "Mínimo", "entero"],
      ["nivel", "Nivel", "nivel"], ["unidades_sugeridas", "A pedir", "entero"],
      ["proveedor_sugerido", "Proveedor sugerido", "texto", "Sin proveedor"], ["costo_reposicion", "Costo reposición", "dinero"]]
  },
  "valor-inventario": {
    titulo: "Valor del inventario por categoría",
    pregunta: "¿Cuánta plata hay invertida en el inventario y cuánto valdría al venderlo?",
    columnas: [["categoria", "Categoría"], ["productos", "Productos", "entero"], ["unidades", "Unidades", "entero"],
      ["valor_costo", "Valor a costo", "dinero"], ["valor_venta", "Valor de venta", "dinero"],
      ["utilidad_potencial", "Utilidad potencial", "dinero"], ["porcentaje_del_total", "% del total", "pct"]]
  },
  "rentabilidad": {
    titulo: "Rentabilidad por producto",
    pregunta: "¿Qué productos dejan más ganancia?",
    nota: "El costo se calcula con el precio de compra actual del producto, así que el margen es aproximado.",
    columnas: [["codigo", "Código"], ["nombre", "Producto"], ["categoria", "Categoría"], ["unidades_vendidas", "Unidades vendidas", "entero"],
      ["ingresos", "Ingresos", "dinero"], ["costo_estimado", "Costo estimado", "dinero"], ["utilidad", "Utilidad", "dinero"],
      ["margen_porcentaje", "Margen", "pct"]]
  },
  "clasificacion-abc": {
    titulo: "Clasificación ABC de productos",
    pregunta: "¿Qué productos concentran la mayor parte de las ventas?",
    nota: "Clase A: hasta el 80% de las ventas (cuidar su stock). Clase B: el siguiente 15%. Clase C: el 5% restante.",
    columnas: [["codigo", "Código"], ["nombre", "Producto"], ["ingresos", "Ingresos", "dinero"], ["porcentaje", "% de las ventas", "pct"],
      ["porcentaje_acumulado", "% acumulado", "pct"], ["clase", "Clase", "clase"]]
  },
  "resumen-mensual": {
    titulo: "Ventas y compras por mes",
    pregunta: "¿Cómo van las ventas frente a las compras mes a mes?",
    nota: "Diferencia = vendido menos comprado. La variación compara las ventas con el mes anterior; el mes en curso aún no termina, por eso puede verse baja.",
    columnas: [["mes", "Mes"], ["ventas", "Ventas", "entero"], ["total_vendido", "Total vendido", "dinero"],
      ["total_comprado", "Total comprado", "dinero"], ["diferencia", "Diferencia", "dinero"],
      ["ticket_promedio", "Promedio", "dinero"], ["variacion_ventas_porcentaje", "Variación", "pct"]]
  },
  "sin-rotacion": {
    titulo: "Productos sin rotación",
    pregunta: "¿Qué productos llevan 90 días o más sin venderse y cuánta plata tienen detenida?",
    columnas: [["codigo", "Código"], ["nombre", "Producto"], ["categoria", "Categoría"], ["stock", "Stock", "entero"],
      ["ultima_venta", "Última venta", "fecha", "Nunca"], ["dias_sin_vender", "Días sin vender", "entero", "-"],
      ["capital_inmovilizado", "Capital inmovilizado", "dinero"]]
  },
  "cobertura-stock": {
    titulo: "Cobertura de stock",
    pregunta: "¿Para cuántos días alcanza el stock de cada producto?",
    nota: "Se calcula con el promedio de ventas de los últimos 30 días.",
    columnas: [["codigo", "Código"], ["nombre", "Producto"], ["stock", "Stock", "entero"], ["vendido_30_dias", "Vendido en 30 días", "entero"],
      ["promedio_diario", "Promedio diario", "decimal"], ["dias_de_cobertura", "Días de cobertura", "entero", "Sin ventas"]]
  },
  "compras-proveedor": {
    titulo: "Compras por proveedor",
    pregunta: "¿A qué proveedores se les compra más?",
    columnas: [["proveedor", "Proveedor"], ["compras", "Compras", "entero"], ["total_comprado", "Total comprado", "dinero"],
      ["compra_promedio", "Compra promedio", "dinero"], ["ultima_compra", "Última compra", "fecha", "Sin compras"],
      ["porcentaje_del_gasto", "% del gasto", "pct"]]
  },
  "comparativo-proveedores": {
    titulo: "Comparativo de proveedores",
    pregunta: "¿Qué proveedor vende más barato cada producto?",
    nota: "Los precios se actualizan con cada compra registrada.",
    columnas: [["codigo", "Código"], ["producto", "Producto"], ["proveedor", "Proveedor"], ["precio_compra", "Precio", "dinero"],
      ["mejor_precio", "Mejor precio", "dinero"], ["sobrecosto", "Sobrecosto", "dinero"], ["es_el_mejor", "", "sino"]]
  },
  "perdidas-ajustes": {
    titulo: "Pérdidas por ajustes",
    pregunta: "¿Cuánta plata se pierde por daños, robos y vencimientos?",
    nota: "Solo cuenta los ajustes que bajan el stock, valorizados al precio de compra.",
    columnas: [["motivo", "Motivo"], ["ajustes", "Ajustes", "entero"], ["unidades_perdidas", "Unidades perdidas", "entero"],
      ["valor_perdido", "Valor perdido", "dinero"]]
  },
  "mejores-clientes": {
    titulo: "Mejores clientes",
    pregunta: "¿Qué clientes compran más?",
    columnas: [["cliente", "Cliente"], ["compras", "Compras", "entero"], ["total_comprado", "Total comprado", "dinero"],
      ["ticket_promedio", "Compra promedio", "dinero"], ["ultima_compra", "Última compra", "fecha"]]
  },
  "ventas-usuario": {
    titulo: "Ventas por usuario",
    pregunta: "¿Cuánto vende cada empleado?",
    columnas: [["usuario", "Usuario"], ["rol", "Rol"], ["ventas", "Ventas", "entero"], ["total_vendido", "Total vendido", "dinero"],
      ["ticket_promedio", "Promedio", "dinero"]]
  }
};

const TIPOS_NUMERICOS = ["dinero", "entero", "decimal", "pct"];
let reporteActual = null;

function dinero(n) {
  // El signo va antes del $ (-$852.000) para que se lea bien
  const texto = "$" + Math.abs(Number(n)).toLocaleString("es-CO", { maximumFractionDigits: 0 });
  return Number(n) < 0 ? "-" + texto : texto;
}

// Devuelve el HTML de una celda según su tipo de dato
function formatearCelda(valor, tipo, textoVacio) {
  if (valor === null || valor === undefined) return escapar(textoVacio || "-");

  if (tipo === "dinero") return dinero(valor);
  if (tipo === "entero") return Number(valor).toLocaleString("es-CO");
  if (tipo === "decimal") return Number(valor).toLocaleString("es-CO", { maximumFractionDigits: 2 });
  if (tipo === "pct") return Number(valor).toLocaleString("es-CO", { maximumFractionDigits: 1 }) + "%";
  if (tipo === "fecha") return escapar(formatearFecha(valor));
  if (tipo === "nivel") return `<span class="badge ${valor === "SIN STOCK" ? "badge-danger" : "badge-warning"}">${escapar(valor)}</span>`;
  if (tipo === "clase") {
    const color = { A: "success", B: "warning", C: "danger" }[valor] || "warning";
    return `<span class="badge badge-${color}">${escapar(valor)}</span>`;
  }
  if (tipo === "sino") return valor === "SI" ? '<span class="badge badge-success">Mejor precio</span>' : "";
  return escapar(valor);
}

function prepararReportes() {
  const select = document.getElementById("rep-select");
  // Las opciones se llenan solo la primera vez
  if (select.options.length === 0) {
    select.innerHTML = Object.entries(REPORTES)
      .map(([clave, r]) => `<option value="${clave}">${escapar(r.titulo)}</option>`).join("");
  }
  cargarReporte(select.value);
}

async function cargarReporte(clave) {
  const rep = REPORTES[clave];
  const tbody = document.getElementById("rep-body");
  const columnas = rep.columnas.length;
  reporteActual = clave;

  document.getElementById("rep-pregunta").textContent = rep.pregunta;
  document.getElementById("rep-nota").textContent = rep.nota || "";
  document.getElementById("rep-head").innerHTML = rep.columnas
    .map(c => `<th${TIPOS_NUMERICOS.includes(c[2]) ? ' class="num"' : ""}>${escapar(c[1])}</th>`).join("");
  filaMensaje(tbody, columnas, "Cargando...");

  try {
    const filas = await api("/reportes/" + clave);
    if (reporteActual !== clave) return; // el usuario ya cambió de reporte

    if (filas.length === 0) {
      filaMensaje(tbody, columnas, "Todavía no hay datos para este reporte.");
      return;
    }
    tbody.innerHTML = filas.map(f => "<tr>" + rep.columnas.map(c =>
      `<td${TIPOS_NUMERICOS.includes(c[2]) ? ' class="num"' : ""}>${formatearCelda(f[c[0]], c[2], c[3])}</td>`
    ).join("") + "</tr>").join("");
  } catch (error) {
    if (reporteActual === clave) filaMensaje(tbody, columnas, error.message);
  }
}

// Indicadores del mes para el inicio (los 4 cuadros de gerencia)
async function cargarResumen() {
  try {
    const r = await api("/reportes/resumen");
    document.getElementById("stat-ventas-mes").textContent = dinero(r.ventas_mes);
    document.getElementById("stat-compras-mes").textContent = dinero(r.compras_mes);
    document.getElementById("stat-valor-inv").textContent = dinero(r.valor_inventario);
    document.getElementById("stat-inmovilizado").textContent = dinero(r.capital_inmovilizado);
  } catch (error) {
    console.warn("No se pudo cargar el resumen:", error.message);
  }
}


// ── Dashboard ───────────────────────────────────────

function actualizarStats() {
  const stockBajo = productos.filter(p => p.stock > 0 && p.stock <= p.stock_minimo).length;
  const sinStock = productos.filter(p => p.stock === 0).length;
  const totalUnidades = productos.reduce((suma, p) => suma + p.stock, 0);

  document.getElementById("stat-total").textContent = productos.length;
  document.getElementById("stat-unidades").textContent = totalUnidades;
  document.getElementById("stat-bajo").textContent = stockBajo;
  document.getElementById("stat-sin").textContent = sinStock;

  // Tabla de alertas: productos que están en el mínimo o por debajo
  const enAlerta = productos.filter(p => p.stock <= p.stock_minimo);
  const tbody = document.getElementById("tabla-alertas-body");

  if (enAlerta.length === 0) {
    filaMensaje(tbody, 5, "Todos los productos tienen stock suficiente.");
    return;
  }

  tbody.innerHTML = enAlerta.map(p => `
            <tr>
                <td class="celda-codigo">${escapar(p.codigo)}</td>
                <td><strong>${escapar(p.nombre)}</strong></td>
                <td>${escapar(p.stock)}</td>
                <td>${escapar(p.stock_minimo)}</td>
                <td>${badgeStock(p)}</td>
            </tr>`).join("");
}


// ── Inicialización ──────────────────────────────────

document.addEventListener("DOMContentLoaded", () => {
  // Si no hay sesión, no dejo entrar
  if (!verificarSesion()) return;

  // Un solo listener para todos los botones con data-algo
  document.addEventListener("click", e => {
    const btn = e.target.closest("button");
    if (!btn) return;

    if (btn.dataset.seccion) mostrarSeccion(btn.dataset.seccion);
    else if (btn.dataset.ir) mostrarSeccion(btn.dataset.ir);
    else if (btn.dataset.nuevo) abrirModal(btn.dataset.nuevo, null);
    else if (btn.dataset.editar) abrirModal(btn.dataset.editar, btn.dataset.id);
    else if (btn.dataset.eliminar) desactivarProducto(btn.dataset.eliminar);
    else if (btn.dataset.anular) anularDocumento(btn.dataset.anular, btn.dataset.id);
  });

  document.getElementById("btn-logout").addEventListener("click", cerrarSesion);
  document.getElementById("btn-menu").addEventListener("click", abrirMenu);
  document.getElementById("overlay").addEventListener("click", cerrarMenu);

  document.getElementById("buscar-producto").addEventListener("input", e => buscarProducto(e.target.value));

  document.getElementById("form-nuevo-producto").addEventListener("submit", guardarProducto);
  document.getElementById("form-entrada").addEventListener("submit", e => guardarMovimiento(e, "entrada"));
  document.getElementById("form-salida").addEventListener("submit", e => guardarMovimiento(e, "salida"));

  document.getElementById("form-ajuste").addEventListener("submit", guardarAjuste);
  document.getElementById("ent-producto").addEventListener("change", () => sugerirPrecio("entrada"));
  document.getElementById("sal-producto").addEventListener("change", () => sugerirPrecio("salida"));

  document.getElementById("form-modal").addEventListener("submit", guardarModal);
  document.getElementById("modal-cancelar").addEventListener("click", cerrarModal);
  document.addEventListener("keydown", e => {
    if (e.key === "Escape") cerrarModal();
  });

  document.getElementById("rep-select").addEventListener("change", e => cargarReporte(e.target.value));

  // Cargo productos y categorías al iniciar para que el inicio tenga datos
  cargarProductos();
  cargarCategorias();
  if (esAdmin()) cargarResumen();
});
