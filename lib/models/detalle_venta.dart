import 'producto.dart';

class DetalleVenta {
  int? id;
  Producto producto; 
  int cantidad;
  double precioUnitario; 

  DetalleVenta({
    this.id,
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;


  Map<String, dynamic> toMap(int idVenta) => {
    'id_detalle': id,
    'id_venta': idVenta, 
    'id_producto': producto.id,
    'cantidad': cantidad,
    'precio_unitario': precioUnitario,
    'subtotal': subtotal,
  };
}