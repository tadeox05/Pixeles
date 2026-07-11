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
    
    final List<Map<String, dynamic>> existentes = await executor.query(
      'clientes',
      where: 'LOWER(nombre) = LOWER(?) AND telefono = ?',
      whereArgs: [cliente.nombre, cliente.telefono],
    );

    if (existentes.isNotEmpty) {
      int id = existentes.first['id_cliente'];
      
      final datosAActualizar = cliente.toMap();
      datosAActualizar.remove('id_cliente'); 

      await executor.update(
        'clientes',
        datosAActualizar,
        where: 'id_cliente = ?',
        whereArgs: [id],
      );
      return id;
    } else {
      final datosAInsertar = cliente.toMap();
      datosAInsertar.remove('id_cliente');
      
      return await executor.insert('clientes', datosAInsertar);
    }
  }
}