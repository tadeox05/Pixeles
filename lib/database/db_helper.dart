import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instancia = DBHelper._interno();
  factory DBHelper() => _instancia;
  DBHelper._interno();

  static Database? _database;

  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pixeles_ventas.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _crearTablas,
      onConfigure: _configurarDB, 
    );
  }

  Future _configurarDB(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _crearTablas(Database db, int version) async {
    // 1. Tabla Clientes
    await db.execute('''
      CREATE TABLE clientes (
        id_cliente INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        domicilio TEXT,
        telefono TEXT
      )
    ''');

    // 2. Tabla Productos
    await db.execute('''
      CREATE TABLE productos (
        id_producto INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        precio_actual REAL NOT NULL
      )
    ''');

    // 3. Tabla Ventas (Cabecera de la boleta)
    await db.execute('''
      CREATE TABLE ventas (
        id_venta INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cliente INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        canal_venta TEXT NOT NULL,
        observaciones TEXT,
        total REAL NOT NULL,
        monto_pagado REAL NOT NULL,    -- AGREGAR ESTA
        saldo_pendiente REAL NOT NULL, -- AGREGAR ESTA
        FOREIGN KEY (id_cliente) REFERENCES clientes (id_cliente)
      )
    ''');

    // 4. Tabla Detalles Venta (Los renglones)
    await db.execute('''
      CREATE TABLE detalles_venta (
        id_detalle INTEGER PRIMARY KEY AUTOINCREMENT,
        id_venta INTEGER NOT NULL,
        id_producto INTEGER NOT NULL,
        cantidad INTEGER NOT NULL,
        precio_unitario REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (id_venta) REFERENCES ventas (id_venta) ON DELETE CASCADE,
        FOREIGN KEY (id_producto) REFERENCES productos (id_producto)
      )
    ''');
    // 5. ÍNDICES DE OPTIMIZACIÓN (Aceleran las búsquedas x10)
    await db.execute('CREATE INDEX idx_ventas_fecha ON ventas(fecha)');
    await db.execute('CREATE INDEX idx_detalles_id_venta ON detalles_venta(id_venta)');
    await db.execute('CREATE INDEX idx_detalles_id_producto ON detalles_venta(id_producto)');
  }
}