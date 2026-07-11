import 'cliente.dart';
import 'detalle_venta.dart';

class Venta {
  int? id;
  Cliente cliente;
  DateTime fecha;
  String canalVenta; 
  String? observaciones;
  List<DetalleVenta> detalles;
  final double montoPagado;
  final double saldoPendiente;

  Venta({
    this.id,
    required this.cliente,
    required this.fecha,
    required this.canalVenta,
    this.observaciones,
    required this.montoPagado,
    required this.saldoPendiente,
    List<DetalleVenta>? detalles, 
  }) : detalles = detalles ?? []; 

  
  double get total {
    return detalles.fold(0, (sum, item) => sum + item.subtotal);
  }

  
  void agregarDetalle(DetalleVenta detalle) {
    detalles.add(detalle);
  }

  void removerDetalle(int index) {
    if (index >= 0 && index < detalles.length) {
      detalles.removeAt(index);
    }
  }

 
  Map<String, dynamic> toMap() => {
    'id_venta': id,
    'id_cliente': cliente.id, 
    'fecha': fecha.toIso8601String(), 
    'canal_venta': canalVenta,
    'observaciones': observaciones,
    'total': total,
    'monto_pagado': montoPagado,    
    'saldo_pendiente': saldoPendiente,
  };

  factory Venta.fromMap(Map<String, dynamic> map, Cliente cliente, List<DetalleVenta> detalles) {
    return Venta(
      id: map['id_venta'],
      cliente: cliente,
      fecha: DateTime.parse(map['fecha'] ?? DateTime.now().toIso8601String()),
      canalVenta: map['canal_venta'] ?? 'Local',
      observaciones: map['observaciones'],
      detalles: detalles,
      montoPagado: (map['monto_pagado'] ?? 0.0).toDouble(),
      saldoPendiente: (map['saldo_pendiente'] ?? 0.0).toDouble(),
    );
  }
}