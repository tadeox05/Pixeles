import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/producto.dart';

class ProductoRepository {
  Future<Database> get _db async => await DBHelper().database;

 Future<int> guardarOActualizarProducto(Producto producto, {Transaction? txn}) async {
    final executor = txn ?? await _db;

    if (producto.id != null) {
      // Si tiene ID, es una edición. Actualizamos ese registro específico.
      await executor.update(
        'productos',
        producto.toMap()..remove('id_producto'), // Evitamos actualizar el ID
        where: 'id_producto = ?',
        whereArgs: [producto.id],
      );
      return producto.id!; 
    } else {
      // Si no tiene ID, es un producto nuevo. Insertamos.
      return await executor.insert('productos', producto.toMap()..remove('id_producto'));
    }
  }

  // Agregamos la función para eliminar
  Future<void> eliminarProducto(int id) async {
    final db = await _db;
    try {
      await db.delete('productos', where: 'id_producto = ?', whereArgs: [id]);
    } catch (e) {
      // Si la base de datos bloquea el borrado, lanzamos un mensaje amigable
      throw Exception('No se puede eliminar este producto porque está incluido en ventas históricas.');
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