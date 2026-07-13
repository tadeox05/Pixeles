import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/cliente.dart';

class ClienteRepository {
  Future<Database> get _db async => await DBHelper().database;

  // Insertar un cliente nuevo
  Future<int> insertar(Cliente cliente) async {
    final db = await _db;
    return await db.insert('clientes', cliente.toMap());
  }

  // Traer todos los clientes
  Future<List<Cliente>> obtenerTodos() async {
    final db = await _db;
    final List<Map<String, dynamic>> mapas = await db.query(
      'clientes', 
      orderBy: 'nombre ASC'
    );

    return List.generate(mapas.length, (i) {
      return Cliente.fromMap(mapas[i]);
    });
  }

 Future<int> guardarOActualizarCliente(Cliente cliente, {Transaction? txn}) async {
    final executor = txn ?? await _db;
    
    if (cliente.id != null) {
      await executor.update(
        'clientes',
        cliente.toMap()..remove('id_cliente'),
        where: 'id_cliente = ?',
        whereArgs: [cliente.id],
      );
      return cliente.id!;
    } else {
      return await executor.insert('clientes', cliente.toMap()..remove('id_cliente'));
    }
  }

  // Agregamos la función para eliminar
  Future<void> eliminarCliente(int id) async {
    final db = await _db;
    try {
      await db.delete('clientes', where: 'id_cliente = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('No se puede eliminar este cliente porque tiene ventas asociadas.');
    }
  }
}