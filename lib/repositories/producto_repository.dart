import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/producto.dart';

class ProductoRepository {
  Future<Database> get _db async => await DBHelper().database;

 Future<int> guardarOActualizarProducto(Producto producto, {Transaction? txn}) async {
    final executor = txn ?? await _db;

    
    final List<Map<String, dynamic>> resultado = await executor.query(
      'productos',
      where: 'LOWER(nombre) = LOWER(?)',
      whereArgs: [producto.nombre],
    );

    if (resultado.isNotEmpty) {
      int idExistente = resultado.first['id_producto'];
      await executor.update(
        'productos',
        {
          'nombre': producto.nombre, 
          'precio_actual': producto.precioActual
        },
        where: 'id_producto = ?',
        whereArgs: [idExistente],
      );
      return idExistente; 
    } else {
      final datosAInsertar = producto.toMap();
      datosAInsertar.remove('id_producto');
      
      return await executor.insert('productos', datosAInsertar);
    }
  }

 
  Future<List<Producto>> obtenerTodos() async {
    final db = await _db;
    final List<Map<String, dynamic>> mapas = await db.query(
      'productos', 
      orderBy: 'nombre ASC'
    );

    // Convertimos la lista de diccionarios de SQLite a una lista de Objetos Producto
    return List.generate(mapas.length, (i) {
      return Producto.fromMap(mapas[i]);
    });
  }
}