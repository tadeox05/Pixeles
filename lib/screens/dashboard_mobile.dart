import 'package:flutter/material.dart';
import '../repositories/venta_repository.dart';
import 'nueva_venta_screen.dart';
import '../models/venta.dart';
import '../services/pdf_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:async';



class DashboardMobile extends StatefulWidget {
  const DashboardMobile({super.key});

  @override
  State<DashboardMobile> createState() => _DashboardMobileState();
}

class _DashboardMobileState extends State<DashboardMobile> {
  final VentaRepository _ventaRepo = VentaRepository();
  
  // Estado de la pantalla
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
    // Aseguramos que la UI cargue antes de llamar a SQLite
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
    if (_modoFecha == 'Día') {
      return '${_fechaSeleccionada.day} ${meses[_fechaSeleccionada.month - 1]} ${_fechaSeleccionada.year}';
    } else if (_modoFecha == 'Mes') {
      return '${meses[_fechaSeleccionada.month - 1]} ${_fechaSeleccionada.year}';
    } else {
      return '${_fechaSeleccionada.year}';
    }
  }

 void _mostrarDetallesVenta(Venta v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7, 
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 24),

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

            // SECCIÓN CLIENTE
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
                  if (v.cliente.domicilio != null && v.cliente.domicilio!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: Colors.white70),
                        const SizedBox(width: 8),
                        Expanded(child: Text(v.cliente.domicilio!)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // SECCIÓN PRODUCTOS
            const Text("DETALLE DE PRODUCTOS", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),
            ...v.detalles.map((d) => Padding(
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
            )),

            const Divider(height: 40, color: Colors.white12),

            // TOTALES Y SALDOS
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

Future<void> _generarComprobante(int idVenta) async {
    try {
      // Buscamos los datos
      final venta = await _ventaRepo.obtenerVentaPorId(idVenta);
      if (venta == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generando archivo PDF...'))
      );

      final pdfBytes = await PdfService().generarBoleta(venta);

      // BUSCAR RUTA Y GUARDAR:
      // Obtenemos la carpeta de documentos de la App
      final directorio = await getApplicationDocumentsDirectory();
      final nombreArchivo = 'Boleta_Pixeles_${venta.id}.pdf';
      final rutaCompleta = '${directorio.path}/$nombreArchivo';
      
      final archivo = File(rutaCompleta);
      await archivo.writeAsBytes(pdfBytes);

      // ABRIR EL ARCHIVO:
      await OpenFilex.open(rutaCompleta);

    } catch (e) {
      debugPrint("Error al exportar/abrir PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  Future<void> _cargarVentas() async {
    setState(() => _isLoading = true);

    try {
      final datos = await _ventaRepo.obtenerHistorial(
        busquedaGeneral: _busquedaCliente,
        fechaParcial: _fechaFiltro,
        canal: _canalFiltro == 'Todos' ? null : _canalFiltro, 
      ).timeout(const Duration(seconds: 10));

      setState(() {
        _ventas = datos;
      });

    } catch (e) {
      // SI EXPLOTA EL SQL O PASAN LOS 10 SEGUNDOS, LO ATRAPAMOS ACÁ
      debugPrint("ERROR EN LA BÚSQUEDA: $e");
      
      // Aseguramos que la pantalla ya exista antes de mostrar el cartel rojo
      // Esto evita el crash si falla apenas se abre la app
      if (mounted && ScaffoldMessenger.maybeOf(context) != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cargar las ventas.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      
      
      setState(() {
        _ventas = [];
      });

    } finally {
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            // Logo circular 'P'
            Image.asset(
              'assets/logo_p_principal.png', 
              height: 40,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
            ),
            const SizedBox(width: 12),
            // Textos de Marca
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PIXELES',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Agenda',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. Barra de Búsqueda y Filtros
          _construirBarraFiltros(),
          
          // 2. Grilla/Lista de Tarjetas Responsiva con Pull-to-Refresh
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF6366F1),
              backgroundColor: const Color(0xFF1E293B),
              onRefresh: _cargarVentas, // Llama a la base de datos al deslizar
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _ventas.isEmpty
                  ? ListView(
                      // Este ListView oculto permite deslizar aunque no haya ventas
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 300,
                          child: Center(child: Text('No se encontraron ventas.', style: TextStyle(color: Colors.white54))),
                        ),
                      ],
                    )
                  : _construirListadoResponsivo(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NuevaVentaScreen()),
          );
          if (resultado == true) {
            _cargarVentas();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva Venta', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- WIDGETS MODULARIZADOS ---

  Widget _construirBarraFiltros() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // FILA 1: Buscador y Filtro de Plataforma
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cliente o Producto',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  onChanged: (valor) {
                    _busquedaCliente = valor;
                     if (_debounce?.isActive ?? false) _debounce!.cancel();

                     _debounce = Timer(const Duration(milliseconds: 500), () {
                     _cargarVentas();
                     });
                 },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _canalFiltro,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  items: _canales.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    setState(() => _canalFiltro = val!);
                    _cargarVentas();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // FILA 2: Navegador de Fechas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Dropdown para elegir Día/Mes/Año
                SizedBox(
                  width: 90,
                  child: DropdownButton<String>(
                    value: _modoFecha,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: ['Día', 'Mes', 'Año'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) {
                      setState(() => _modoFecha = val!);
                      _actualizarFiltroFecha();
                    },
                  ),
                ),
                
                
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _cambiarFecha(-1),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        _obtenerTextoFecha(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _cambiarFecha(1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _construirListadoResponsivo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          // Diseño para tablets o pantallas anchas
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: _ventas.length,
            itemBuilder: (context, index) => _generarTarjeta(index),
          );
        } else {
          // Diseño para celulares (Vertical)
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _ventas.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _generarTarjeta(index),
            ),
          );
        }
      },
    );
  }

  // 2. Método auxiliar para no repetir la lógica del itemBuilder
 Widget _generarTarjeta(int index) {
    final ventaMap = _ventas[index];
    final int idVenta = ventaMap['id_venta'];

    return TarjetaVenta(
      venta: ventaMap,
      onTap: () async {
        final ventaCompleta = await _ventaRepo.obtenerVentaPorId(idVenta);
        if (ventaCompleta != null && mounted) {
          _mostrarDetallesVenta(ventaCompleta);
        }
      },
      onEdit: () async {
        final ventaCompleta = await _ventaRepo.obtenerVentaPorId(idVenta);
        if (ventaCompleta != null && mounted) {
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NuevaVentaScreen(ventaExistente: ventaCompleta)),
          );
          if (resultado == true) _cargarVentas();
        }
      },
      onPdf: () => _generarComprobante(idVenta),
      onDelete: () async {
        final confirmar = await _confirmarBorrado();
        if (confirmar) {
          await _ventaRepo.eliminarVenta(idVenta);
          if (!mounted) return;
          _cargarVentas();
        }
      },
    );
  }


  // Función auxiliar para el diálogo de confirmación
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
}

class TarjetaVenta extends StatelessWidget {
  final Map<String, dynamic> venta;
  final VoidCallback onDelete;
  final VoidCallback onPdf;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  const TarjetaVenta({
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
    
    // Lógica para la vista previa de productos
    String previewCrudo = venta['productos_preview']?.toString() ?? '';
    String previewFinal = '';
    if (previewCrudo.isNotEmpty) {
      List<String> lista = previewCrudo.split('||')..removeWhere((p) => p.trim().isEmpty);
      previewFinal = lista.take(2).join('\n'); // Muestra máximo 2
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

    bool debe = saldo > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF1E1E1E), // Color oscuro para que coincida con PC
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      venta['nombre_cliente']?.toString() ?? 'Cliente',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: debe ? Colors.redAccent.withValues(alpha: 0.15) : Colors.greenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: debe ? Colors.redAccent.withValues(alpha: 0.5) : Colors.greenAccent.withValues(alpha: 0.5), width: 0.5),
                    ),
                    child: Text(debe ? "DEBE" : "PAGADO", style: TextStyle(color: debe ? Colors.redAccent : Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(fechaFormateada, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(width: 8),
                  Text("• $canal", style: TextStyle(color: colorPlataforma.withValues(alpha: 0.7), fontSize: 12)),
                ],
              ),
              
              // VISTA PREVIA AÑADIDA ACÁ
              if (previewFinal.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(previewFinal, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
              ],
              
              const SizedBox(height: 12),
              const Divider(color: Colors.white12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Importe Total", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text("\$ ${total.toStringAsFixed(2)}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent), onPressed: onEdit),
                      IconButton(icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white70), onPressed: onPdf),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: onDelete),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}



