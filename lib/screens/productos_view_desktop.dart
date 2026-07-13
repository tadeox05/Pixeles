import 'package:flutter/material.dart';
import '../repositories/producto_repository.dart';
import '../models/producto.dart';

class ProductosViewDesktop extends StatefulWidget {
  const ProductosViewDesktop({super.key});

  @override
  State<ProductosViewDesktop> createState() => _ProductosViewDesktopState();
}

class _ProductosViewDesktopState extends State<ProductosViewDesktop> {
  final ProductoRepository _productoRepo = ProductoRepository();
  List<Producto> _listaProductos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarProductos();
    });
  }

  Future<void> _cargarProductos() async {
    final prods = await _productoRepo.obtenerTodos();
    if (mounted) setState(() => _listaProductos = prods);
  }

  void _mostrarDialogoProducto(Producto? p) {
    final nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    final precioCtrl = TextEditingController(text: p?.precioActual.toString() ?? '');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(p == null ? 'Nuevo Producto' : 'Editar Producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 16),
            TextField(controller: precioCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio Actual', prefixText: '\$ ')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
            onPressed: () async {
              final nuevo = Producto(id: p?.id, nombre: nombreCtrl.text, precioActual: double.tryParse(precioCtrl.text) ?? 0);
              await _productoRepo.guardarOActualizarProducto(nuevo);
              _cargarProductos();
              
              if (!ctx.mounted) return; // <--- Validación correcta
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gestión de Productos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Actualizar lista',
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: _cargarProductos,
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                    onPressed: () => _mostrarDialogoProducto(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo Producto'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _listaProductos.length,
              itemBuilder: (context, i) {
                final p = _listaProductos[i];
                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('\$ ${p.precioActual.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent)),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white54),
                      color: const Color(0xFF0F172A),
                      onSelected: (value) async {
                        if (value == 'editar') {
                          _mostrarDialogoProducto(p);
                        } else if (value == 'eliminar') {
                          // Cuadro de confirmación
                          final confirmar = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              title: const Text('¿Eliminar producto?'),
                              content: const Text('Esta acción no se puede deshacer.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: Colors.white54))),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true), 
                                  child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent))
                                ),
                              ],
                            ),
                          ) ?? false;

                          // Si confirmó, intentamos eliminar
                          if (confirmar) {
                            try {
                              await _productoRepo.eliminarProducto(p.id!);
                              _cargarProductos();
                            } catch (e) {
                              if (!context.mounted) return;
                              // Mostramos el error si falló la integridad referencial
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('Exception: ', '')),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'editar', child: Text('Editar')),
                        PopupMenuItem(value: 'eliminar', child: Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}