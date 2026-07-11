import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/venta.dart';import '../models/detalle_venta.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import 'cliente_repository.dart';

import 'producto_repository.dart';

class VentaRepository {
  Future<Database> get _db async => await DBHelper().database;
  final _productoRepo = ProductoRepository();
  final _clienteRepo = ClienteRepository();

 Future<void> guardarVentaCompleta(Venta venta) async {
    final db = await _db;
    
    // Abrimos UNA sola transacción
    await db.transaction((txn) async {
      int idCliente = await _clienteRepo.guardarOActualizarCliente(venta.cliente, txn: txn);
      venta.cliente.id = idCliente;

      // Insertamos la venta y obtenemos el ID generado por SQLite
      int idVentaGenerado = await txn.insert('ventas', venta.toMap());
      
      // Le asignamos ese nuevo ID al objeto que está en memoria
      venta.id = idVentaGenerado; 

      for (var detalle in venta.detalles) {
        int idProducto = await _productoRepo.guardarOActualizarProducto(detalle.producto, txn: txn);
        detalle.producto.id = idProducto; 
        
        await txn.insert('detalles_venta', detalle.toMap(idVentaGenerado));
      }
    });
  }

 Future<List<Map<String, dynamic>>> obtenerHistorial({
    String? canal,
    String? fechaParcial,
    String? busquedaGeneral,
    bool ordenDescendente = true,
  }) async {
    final db = await _db;
    
    // Usamos una subconsulta con GROUP_CONCAT para traer los productos unidos por "||"
    String sql = '''
      SELECT v.*, c.nombre as nombre_cliente,
             (SELECT GROUP_CONCAT(p.nombre, '||')
              FROM detalles_venta d
              JOIN productos p ON d.id_producto = p.id_producto
              WHERE d.id_venta = v.id_venta) as productos_preview
      FROM ventas v 
      JOIN clientes c ON v.id_cliente = c.id_cliente
    ''';
    
    List<String> condiciones = [];
    List<dynamic> argumentos = [];

    if (canal != null && canal.isNotEmpty) { 
      condiciones.add('v.canal_venta = ?'); 
      argumentos.add(canal); 
    }
    
    if (fechaParcial != null && fechaParcial.isNotEmpty) { 
      condiciones.add('v.fecha LIKE ?'); 
      argumentos.add('$fechaParcial%'); 
    }

    // Busca en el nombre del cliente O en los productos de esa venta
    if (busquedaGeneral != null && busquedaGeneral.isNotEmpty) { 
      condiciones.add('''
        (c.nombre LIKE ? OR EXISTS (
          SELECT 1 FROM detalles_venta d2
          JOIN productos p2 ON d2.id_producto = p2.id_producto
          WHERE d2.id_venta = v.id_venta AND p2.nombre LIKE ?
        ))
      '''); 
      argumentos.add('%$busquedaGeneral%'); 
      argumentos.add('%$busquedaGeneral%'); 
    }

    if (condiciones.isNotEmpty) sql += ' WHERE ${condiciones.join(' AND ')}';
    sql += ' ORDER BY v.fecha ${ordenDescendente ? 'DESC' : 'ASC'}';

    return await db.rawQuery(sql, argumentos);
  }

 Future<Venta?> obtenerVentaPorId(int idVenta) async {
    final db = await _db;

    // Buscamos la cabecera de la venta y los datos del cliente con un JOIN
    final List<Map<String, dynamic>> resVenta = await db.rawQuery('''
      SELECT v.*, c.nombre as c_nombre, c.domicilio as c_domicilio, c.telefono as c_telefono
      FROM ventas v
      JOIN clientes c ON v.id_cliente = c.id_cliente
      WHERE v.id_venta = ?
    ''', [idVenta]);

    if (resVenta.isEmpty) return null;

    final datosVenta = resVenta.first;

    // Reconstruimos el objeto Cliente
    Cliente cliente = Cliente(
      id: datosVenta['id_cliente'],
      nombre: datosVenta['c_nombre'],
      domicilio: datosVenta['c_domicilio'],
      telefono: datosVenta['c_telefono'],
    );

    // Buscamos todos los detalles (renglones) de esa venta
    final List<Map<String, dynamic>> resDetalles = await db.rawQuery('''
      SELECT d.*, p.nombre as p_nombre
      FROM detalles_venta d
      JOIN productos p ON d.id_producto = p.id_producto
      WHERE d.id_venta = ?
    ''', [idVenta]);

    // Mapeamos cada fila de la DB a un objeto DetalleVenta (con su Producto dentro)
    List<DetalleVenta> detalles = resDetalles.map((reg) {
      return DetalleVenta(
        id: reg['id_detalle'],
        producto: Producto(
          id: reg['id_producto'],
          nombre: reg['p_nombre'],
        ),
        cantidad: reg['cantidad'],
        precioUnitario: reg['precio_unitario'],
      );
    }).toList();

    // Ensamblamos la Venta completa
    return Venta(
      id: datosVenta['id_venta'],
      cliente: cliente,
      fecha: DateTime.parse(datosVenta['fecha']),
      canalVenta: datosVenta['canal_venta'],
      observaciones: datosVenta['observaciones'],
      detalles: detalles,
      montoPagado: (datosVenta['monto_pagado'] ?? 0.0).toDouble(),
      saldoPendiente: (datosVenta['saldo_pendiente'] ?? 0.0).toDouble(),
    );
  } 

 Future<void> eliminarVenta(int idVenta) async {
    final db = await _db;
    await db.delete('ventas', where: 'id_venta = ?', whereArgs: [idVenta]);
  }

 Future<void> modificarVenta(Venta ventaModificada) async {
    final db = await _db;
    if (ventaModificada.id == null) return;

    await db.transaction((txn) async {
      // Aseguramos el cliente dentro de la transacción
      int idCliente = await _clienteRepo.guardarOActualizarCliente(ventaModificada.cliente, txn: txn);
      ventaModificada.cliente.id = idCliente;

      // Actualizamos la cabecera
      await txn.update(
        'ventas',
        ventaModificada.toMap(),
        where: 'id_venta = ?',
        whereArgs: [ventaModificada.id],
      );

      // Limpiamos detalles viejos para evitar duplicados o basura
      await txn.delete(
        'detalles_venta',
        where: 'id_venta = ?',
        whereArgs: [ventaModificada.id],
      );

      // Procesamos productos y re-insertamos detalles
      for (var detalle in ventaModificada.detalles) {
        int idProd = await _productoRepo.guardarOActualizarProducto(detalle.producto, txn: txn);
        detalle.producto.id = idProd;
        
        await txn.insert('detalles_venta', detalle.toMap(ventaModificada.id!));
      }
    });
  }
}