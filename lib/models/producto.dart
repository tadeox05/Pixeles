class Producto {
  int? id;
  String nombre;
  double precioActual; 

  Producto({
    this.id,
    required this.nombre,
    this.precioActual = 0.0,
  });

  // Para convertir de Map (SQLite) a Objeto
  factory Producto.fromMap(Map<String, dynamic> map) => Producto(
    id: map['id_producto'],
    nombre: map['nombre'],
    precioActual: map['precio_actual'] ?? 0.0,
  );

  // Para convertir de Objeto a Map (para guardar en SQLite)
  Map<String, dynamic> toMap() => {
    'id_producto': id,
    'nombre': nombre,
    'precio_actual': precioActual,
  };
}