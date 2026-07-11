class Cliente {
  int? id;
  String nombre;
  String? domicilio;
  String? telefono;

  Cliente({
    this.id,
    required this.nombre,
    this.domicilio,
    this.telefono,
  });

  factory Cliente.fromMap(Map<String, dynamic> map) => Cliente(
    id: map['id_cliente'],
    nombre: map['nombre'],
    domicilio: map['domicilio'],
    telefono: map['telefono'],
  );

  Map<String, dynamic> toMap() => {
    'id_cliente': id,
    'nombre': nombre,
    'domicilio': domicilio,
    'telefono': telefono,
  };
}