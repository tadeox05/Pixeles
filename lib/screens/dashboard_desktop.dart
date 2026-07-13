import 'package:flutter/material.dart';
import 'dart:async';
import '../repositories/venta_repository.dart';
import '../models/venta.dart';
import '../services/pdf_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'nueva_venta_screen.dart';
import 'productos_view_desktop.dart';
import 'clientes_view_desktop.dart';

class DashboardDesktop extends StatefulWidget {
  const DashboardDesktop({super.key});

  @override
  State<DashboardDesktop> createState() => _DashboardDesktopState();
}

class _DashboardDesktopState extends State<DashboardDesktop> {
  int _indiceSeleccionado = 0;
  
  final VentaRepository _ventaRepo = VentaRepository();
  List<Map<String, dynamic>> _ventas = [];
  bool _isLoading = true;
  String _busquedaCliente = '';
  String _fechaFiltro = '';
  DateTime _fechaSeleccionada = DateTime.now();
  String _modoFecha = 'Mes';
  Timer? _debounce;
  String _canalFiltro = 'Todos'; 
  final List<String> _canales = ['Todos', 'WhatsApp', 'Instagram', 'Facebook', 'Local', 'Web'];

  @override
  void initState() {
    super.initState();
    // addPostFrameCallback asegura que la interfaz cargue antes de trabarse con la base de datos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _actualizarFiltroFecha();
    });
  }

  void _actualizarFiltroFecha() {
    String mes = _fechaSeleccionada.month.toString().padLeft(2, '0');
    String dia = _fechaSeleccionada.day.toString().padLeft(2, '0');
    if (_modoFecha == 'Día') {
      _fechaFiltro = '${_fechaSeleccionada.year}-$mes-$dia';
    } else if (_modoFecha == 'Mes') {
      _fechaFiltro = '${_fechaSeleccionada.year}-$mes';
    } else {
      _fechaFiltro = '${_fechaSeleccionada.year}'; 
    }
    _cargarVentas();
  }

  void _cambiarFecha(int delta) {
    setState(() {
      if (_modoFecha == 'Día') {
        _fechaSeleccionada = _fechaSeleccionada.add(Duration(days: delta));
      } else if (_modoFecha == 'Mes') {
        _fechaSeleccionada = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month + delta, 1);
      } else {
        _fechaSeleccionada = DateTime(_fechaSeleccionada.year + delta, 1, 1);
      }
    });
    _actualizarFiltroFecha();
  }

  String _obtenerTextoFecha() {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    if (_modoFecha == 'Día') return '${_fechaSeleccionada.day} ${meses[_fechaSeleccionada.month - 1]} ${_fechaSeleccionada.year}';
    if (_modoFecha == 'Mes') return '${meses[_fechaSeleccionada.month - 1]} ${_fechaSeleccionada.year}';
    return '${_fechaSeleccionada.year}';
  }

  Future<void> _cargarVentas() async {
    setState(() => _isLoading = true);
    try {
      final datos = await _ventaRepo.obtenerHistorial(
        busquedaGeneral: _busquedaCliente,
        fechaParcial: _fechaFiltro,
        canal: _canalFiltro == 'Todos' ? null : _canalFiltro, 
      ); // Se eliminó el .timeout()
      
      if (mounted) setState(() => _ventas = datos);
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al conectar con la base de datos: $e'),
            backgroundColor: Colors.redAccent,
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generarComprobante(int idVenta) async {
    try {
      final venta = await _ventaRepo.obtenerVentaPorId(idVenta);
      if (venta == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generando archivo PDF...'))
      );

      final pdfBytes = await PdfService().generarBoleta(venta);
      final directorio = await getApplicationDocumentsDirectory();
      final nombreArchivo = 'Boleta_Pixeles_${venta.id}.pdf';
      final rutaCompleta = '${directorio.path}/$nombreArchivo';
      
      final archivo = File(rutaCompleta);
      await archivo.writeAsBytes(pdfBytes);
      await OpenFilex.open(rutaCompleta);
    } catch (e) {
      debugPrint("Error al exportar/abrir PDF: $e");
    }
  }

  Future<bool> _confirmarBorrado() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar venta?'),
        content: const Text('Esta acción borrará la boleta de forma permanente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    ) ?? false;
  }

  // AQUÍ VA EL MÉTODO DEL MODAL FLOTANTE (Dentro de _DashboardDesktopState)
  void _mostrarDetallesVentaDesktop(Venta v) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("COMPROBANTE", style: TextStyle(fontSize: 12, color: Colors.white54, letterSpacing: 1.2)),
                          Text("#${v.id.toString().padLeft(4, '0')}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("${v.fecha.day}/${v.fecha.month}/${v.fecha.year}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(v.canalVenta, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 40, color: Colors.white12),
                  const Text("DATOS DEL CLIENTE", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 18, color: Colors.white70),
                            const SizedBox(width: 8),
                            Text(v.cliente.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (v.cliente.telefono != null && v.cliente.telefono!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 18, color: Colors.white70),
                              const SizedBox(width: 8),
                              Text(v.cliente.telefono!),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("DETALLE DE PRODUCTOS", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: v.detalles.length,
                      itemBuilder: (context, i) {
                        final d = v.detalles[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                                child: Text("${d.cantidad}x", style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.producto.nombre, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    Text("\$${d.precioUnitario.toStringAsFixed(2)} c/u", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text("\$${d.subtotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                  const Divider(height: 40, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("TOTAL", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("\$${v.total.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Pagado:", style: TextStyle(color: Colors.white54)),
                      Text("\$${v.montoPagado.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent)),
                    ],
                  ),
                  if (v.saldoPendiente > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Saldo Pendiente:", style: TextStyle(color: Colors.white54)),
                        Text("\$${v.saldoPendiente.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          _construirSidebar(),
          Expanded(
            child: Container(
              color: const Color(0xFF0F172A),
              child: _construirContenido(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSidebar() {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/logo_p_principal.png', height: 40),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PIXELES', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  Text('Agenda', style: TextStyle(fontSize: 12, color: Colors.white54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),

          _itemMenu(0, Icons.grid_view_rounded, 'Dashboard'),
          const SizedBox(height: 16),
          _itemMenu(1, Icons.sell_outlined, 'Nueva venta'),
          const SizedBox(height: 16),
          _itemMenu(2, Icons.inventory_2_outlined, 'Productos'),
          const SizedBox(height: 16),
          _itemMenu(3, Icons.people_outline, 'Clientes'),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NuevaVentaScreen()),
                );
                if (resultado == true) _cargarVentas();
              },
              icon: const Icon(Icons.add),
              label: const Text('Nueva Venta', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemMenu(int index, IconData icono, String titulo) {
    final isSelected = _indiceSeleccionado == index;
    return InkWell(
      onTap: () {
        if (index == 1) {
          // Si toca "Nueva Venta" abrimos la pantalla encima
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NuevaVentaScreen()),
          ).then((value) {
            if (value == true) _cargarVentas();
          });
        } else {
          setState(() => _indiceSeleccionado = index);
          // ¡SOLUCIÓN AQUÍ! Refrescamos las ventas al volver a la pestaña Dashboard
          if (index == 0) _cargarVentas();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icono, color: isSelected ? Colors.white : Colors.white54, size: 20),
            const SizedBox(width: 16),
            Text(
              titulo,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirContenido() {
    if (_indiceSeleccionado == 0) {
      // ---------------------------------------------------
      // PESTAÑA 0: DASHBOARD (VENTAS)
      // ---------------------------------------------------
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            _construirBarraFiltrosDesktop(),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _ventas.isEmpty
                  ? const Center(child: Text('No se encontraron ventas.', style: TextStyle(color: Colors.white54)))
                  : _construirGrillaVentas(),
            ),
          ],
        ),
      );
    } else if (_indiceSeleccionado == 2) {
      // ---------------------------------------------------
      // PESTAÑA 2: PRODUCTOS
      // ---------------------------------------------------
      return const ProductosViewDesktop(); 
      
    } else if (_indiceSeleccionado == 3) {
      // ---------------------------------------------------
      // PESTAÑA 3: CLIENTES
      // ---------------------------------------------------
      return const ClientesViewDesktop(); 
    }
    
    // Fallback por defecto (ej. si el índice es 1, que es "Nueva Venta"
    // y se maneja como un pop-up en el Sidebar, acá no mostramos nada raro)
    return const SizedBox(); 
  }

  Widget _construirBarraFiltrosDesktop() {
    return Wrap(
      spacing: 16, // Espacio horizontal entre elementos
      runSpacing: 16, // Espacio vertical si bajan a la segunda línea
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Buscador con ancho fijo máximo
        SizedBox(
          width: 300, 
          height: 48,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cliente o Producto',
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (valor) {
              _busquedaCliente = valor;
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), _cargarVentas);
            },
          ),
        ),
        
        // Filtro de canal
        SizedBox(
          width: 180,
          height: 48,
          child: DropdownButtonFormField<String>(
            initialValue: _canalFiltro,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.filter_alt_outlined, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            items: _canales.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) {
              setState(() => _canalFiltro = val!);
              _cargarVentas();
            },
          ),
        ),
        
        // Navegador de fechas
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Ocupa solo el espacio necesario
            children: [
              SizedBox(
                width: 70,
                child: DropdownButton<String>(
                  value: _modoFecha,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: ['Día', 'Mes', 'Año'].map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    setState(() => _modoFecha = val!);
                    _actualizarFiltroFecha();
                  },
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: () => _cambiarFecha(-1), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
              const SizedBox(width: 4),
              Text(_obtenerTextoFecha(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 4),
              IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () => _cambiarFecha(1), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
            ],
          ),
        ),
        
        // Botón actualizar
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            tooltip: 'Actualizar datos',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _cargarVentas,
          ),
        ),
      ],
    );
  }

  Widget _construirGrillaVentas() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400, // Ancho máximo de la tarjeta. Flutter calcula cuántas columnas entran.
        mainAxisExtent: 220,     // Altura FIJA. Esto evita para siempre el desborde inferior (bottom overflow).
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: _ventas.length,
      itemBuilder: (context, index) {
        final ventaMap = _ventas[index];
        final int idVenta = ventaMap['id_venta'];

        return TarjetaVentaDesktop(
          venta: ventaMap,
          onTap: () async {
            final ventaCompleta = await _ventaRepo.obtenerVentaPorId(idVenta);
            if (ventaCompleta != null && mounted) {
              _mostrarDetallesVentaDesktop(ventaCompleta);
            }
          },
          onDelete: () async {
            final confirmar = await _confirmarBorrado();
            if (confirmar) {
              await _ventaRepo.eliminarVenta(idVenta);
              if (!context.mounted) return;
              _cargarVentas();
            }
          },
          onPdf: () => _generarComprobante(idVenta),
          onEdit: () async {
            final ventaCompleta = await _ventaRepo.obtenerVentaPorId(idVenta);
            if (!context.mounted) return;
            if (ventaCompleta != null) {
              final resultado = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NuevaVentaScreen(ventaExistente: ventaCompleta)),
              );
              if (resultado == true) _cargarVentas();
            }
          },
        );
      },
    );
  }
}

class TarjetaVentaDesktop extends StatelessWidget {
  final Map<String, dynamic> venta;
  final VoidCallback onDelete;
  final VoidCallback onPdf;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  const TarjetaVentaDesktop({
    super.key, 
    required this.venta, 
    required this.onDelete, 
    required this.onPdf, 
    required this.onEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    DateTime fecha = DateTime.tryParse(venta['fecha'].toString()) ?? DateTime.now();
    String fechaFormateada = "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}";
    double total = (venta['total'] ?? 0).toDouble();
    double saldo = (venta['saldo_pendiente'] ?? 0).toDouble();
    String canal = venta['canal_venta']?.toString() ?? 'Otro';
    bool debe = saldo > 0;

    String previewCrudo = venta['productos_preview']?.toString() ?? '';
    String previewFinal = 'Sin productos';
    if (previewCrudo.isNotEmpty) {
      List<String> lista = previewCrudo.split('||')..removeWhere((p) => p.trim().isEmpty);
      previewFinal = lista.take(2).join('\n');
      if (lista.length > 2) previewFinal += '\n...';
    }

    Color colorPlataforma;
    String canalLower = canal.toLowerCase();
    if (canalLower.contains('whatsapp')) {
      colorPlataforma = Colors.green.shade400;
    } else if (canalLower.contains('instagram')) {
      colorPlataforma = Colors.pink.shade400;
    } else if (canalLower.contains('facebook')) {
      colorPlataforma = Colors.blue.shade400;
    } else if (canalLower.contains('web')) {
      colorPlataforma = Colors.teal.shade400; 
    } else if (canalLower.contains('local')) {
      colorPlataforma = Colors.orange.shade400; 
    } else {
      colorPlataforma = Colors.grey;
    }

    return Material(
      color: Colors.transparent, 
      child: InkWell(
        onTap: onTap, 
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), 
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(venta['nombre_cliente']?.toString() ?? 'Cliente', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: debe ? Colors.transparent : Colors.green.withValues(alpha: 0.2),
                      border: Border.all(color: debe ? Colors.redAccent : Colors.green),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(debe ? "DEBE" : "PAGADO", style: TextStyle(color: debe ? Colors.redAccent : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(fechaFormateada, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(width: 12),
                  Text("• $canal", style: TextStyle(color: colorPlataforma.withValues(alpha: 0.7), fontSize: 12)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Text(previewFinal, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
              ),
              const Divider(color: Colors.white12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Importe Total", style: TextStyle(color: Colors.white54, fontSize: 10)),
                      // --- COLOR DEL TEMA APLICADO AL IMPORTE ---
                      Text("\$ ${total.toStringAsFixed(2)}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.lightBlueAccent, size: 20), onPressed: onEdit, constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                      IconButton(icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white70, size: 20), onPressed: onPdf, constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: onDelete, constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                    ],
                  ),
                ],
              ),
            ],
          )
        )
      )
    );
  }
}