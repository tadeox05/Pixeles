import 'package:flutter/material.dart';
import '../repositories/cliente_repository.dart';
import '../models/cliente.dart';

class ClientesViewDesktop extends StatefulWidget {
  const ClientesViewDesktop({super.key});

  @override
  State<ClientesViewDesktop> createState() => _ClientesViewDesktopState();
}

class _ClientesViewDesktopState extends State<ClientesViewDesktop> {
  final ClienteRepository _clienteRepo = ClienteRepository();
  List<Cliente> _listaClientes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarClientes();
    });
  }

  Future<void> _cargarClientes() async {
    final clis = await _clienteRepo.obtenerTodos();
    if (mounted) setState(() => _listaClientes = clis);
  }

  void _mostrarDialogoCliente(Cliente? c) {
    final nombreCtrl = TextEditingController(text: c?.nombre ?? '');
    final telCtrl = TextEditingController(text: c?.telefono ?? '');
    final domCtrl = TextEditingController(text: c?.domicilio ?? '');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(c == null ? 'Nuevo Cliente' : 'Editar Cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre *')),
            const SizedBox(height: 16),
            TextField(controller: telCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
            const SizedBox(height: 16),
            TextField(controller: domCtrl, decoration: const InputDecoration(labelText: 'Domicilio')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
            onPressed: () async {
              if (nombreCtrl.text.isEmpty) return;
              final nuevo = Cliente(id: c?.id, nombre: nombreCtrl.text, telefono: telCtrl.text, domicilio: domCtrl.text);
              await _clienteRepo.guardarOActualizarCliente(nuevo);
              _cargarClientes();
              
              if (!ctx.mounted) return; // <--- Validación correcta
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          )
        ],
      ),
    );
  }

  void _mostrarDetallesClienteModal(Cliente c) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 40, color: Color(0xFF6366F1)),
                    const SizedBox(width: 16),
                    Expanded(child: Text(c.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                  ],
                ),
                const Divider(height: 40, color: Colors.white12),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, color: Colors.white54, size: 20),
                    const SizedBox(width: 12),
                    Text(c.telefono != null && c.telefono!.isNotEmpty ? c.telefono! : 'No registrado', style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.white54, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c.domicilio != null && c.domicilio!.isNotEmpty ? c.domicilio! : 'No registrado', style: const TextStyle(fontSize: 16))),
                  ],
                ),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CERRAR', style: TextStyle(fontWeight: FontWeight.bold))),
                )
              ],
            ),
          )
        )
      )
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
              const Text('Directorio de Clientes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Actualizar lista',
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: _cargarClientes,
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                    onPressed: () => _mostrarDialogoCliente(null),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Nuevo Cliente'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _listaClientes.length,
              itemBuilder: (context, i) {
                final c = _listaClientes[i];
                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () => _mostrarDetallesClienteModal(c),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      child: Text(c.nombre[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6366F1))),
                    ),
                    title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(c.telefono ?? 'Sin teléfono', style: const TextStyle(color: Colors.white54)),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white54),
                      color: const Color(0xFF0F172A),
                      onSelected: (value) async {
                        if (value == 'editar') {
                          _mostrarDialogoCliente(c);
                        } else if (value == 'eliminar') {
                          // Cuadro de confirmación
                          final confirmar = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              title: const Text('¿Eliminar cliente?'),
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
                              await _clienteRepo.eliminarCliente(c.id!);
                              _cargarClientes();
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