import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/detalle_venta.dart';
import '../models/venta.dart';
import '../repositories/venta_repository.dart';
import '../repositories/producto_repository.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/pdf_service.dart';


// Clase auxiliar para manejar el estado de cada renglón dinámico
class ControladorRenglon {
  final TextEditingController productoCtrl = TextEditingController();
  final FocusNode productoFocus = FocusNode();
  final TextEditingController cantidadCtrl = TextEditingController(text: '1');
  final TextEditingController precioCtrl = TextEditingController();
  Producto? productoExistente; // Guarda el producto si vino de la BD
}

class NuevaVentaScreen extends StatefulWidget {
  final Venta? ventaExistente;
  const NuevaVentaScreen({super.key, this.ventaExistente});

  @override
  State<NuevaVentaScreen> createState() => _NuevaVentaScreenState();
}

class _NuevaVentaScreenState extends State<NuevaVentaScreen> {
  final _formKey = GlobalKey<FormState>();
  final VentaRepository _ventaRepo = VentaRepository();
  final ProductoRepository _productoRepo = ProductoRepository();
  bool _isGuardando = false;
  DateTime _fechaManual = DateTime.now();

  // Controladores del Cliente
  final _nombreClienteCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _domicilioCtrl = TextEditingController();
  String _canalSeleccionado = 'WhatsApp';
  final List<String> _canales = ['WhatsApp', 'Instagram', 'Facebook', 'Local', 'Web'];
  final _pagoClienteCtrl = TextEditingController(text: '0');
  // Lista de renglones de productos
  final List<ControladorRenglon> _renglones = [ControladorRenglon()]; // Arranca con 1 vacío

  // Lista para el autocompletado cargada desde SQLite
  List<Producto> _catalogoProductos = [];

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();

    if (widget.ventaExistente != null) {
      final v = widget.ventaExistente!;
      _nombreClienteCtrl.text = v.cliente.nombre;
      _telefonoCtrl.text = v.cliente.telefono ?? '';
      _domicilioCtrl.text = v.cliente.domicilio ?? '';
      _canalSeleccionado = v.canalVenta;
      _pagoClienteCtrl.text = v.montoPagado.toString();
      _fechaManual = v.fecha;
      
      _renglones.clear();
      for (var det in v.detalles) {
        final ctrl = ControladorRenglon();
        ctrl.productoCtrl.text = det.producto.nombre;
        ctrl.cantidadCtrl.text = det.cantidad.toString();
        ctrl.precioCtrl.text = det.precioUnitario.toString();
        ctrl.productoExistente = det.producto;
        _renglones.add(ctrl);
      }
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaManual,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fechaManual = picked);
  }

  Future<void> _cargarCatalogo() async {
    final productos = await _productoRepo.obtenerTodos();
    setState(() {
      _catalogoProductos = productos;
    });
  }

  // Calcula el total en tiempo real leyendo los controladores
  double _calcularTotalVisible() {
    double total = 0;
    for (var r in _renglones) {
      double precio = double.tryParse(r.precioCtrl.text) ?? 0;
      int cantidad = int.tryParse(r.cantidadCtrl.text) ?? 1;
      total += (precio * cantidad);
    }
    return total;
  }

Future<void> _guardarVenta(bool exportarPdf) async {
    if (!_formKey.currentState!.validate()) return;
    if (_renglones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agregá al menos un producto')));
      return;
    }

    setState(() => _isGuardando = true);

    try {
      final cliente = Cliente(
        nombre: _nombreClienteCtrl.text.trim(), 
        telefono: _telefonoCtrl.text.trim(), 
        domicilio: _domicilioCtrl.text.trim()
      );
      
      List<DetalleVenta> detalles = _renglones.map((r) => DetalleVenta(
        producto: Producto(id: r.productoExistente?.id, nombre: r.productoCtrl.text.trim(), precioActual: double.parse(r.precioCtrl.text)),
        cantidad: int.parse(r.cantidadCtrl.text),
        precioUnitario: double.parse(r.precioCtrl.text),
      )).toList();

      double total = _calcularTotalVisible();
      double pago = double.tryParse(_pagoClienteCtrl.text) ?? 0;

      final ventaAGuardar = Venta(
        id: widget.ventaExistente?.id,
        cliente: cliente,
        fecha: _fechaManual,
        canalVenta: _canalSeleccionado,
        detalles: detalles,
        montoPagado: pago,
        saldoPendiente: total - pago,
      );

      // 1. Guardamos en la Base de Datos
      if (widget.ventaExistente == null) {
        await _ventaRepo.guardarVentaCompleta(ventaAGuardar);
      } else {
        await _ventaRepo.modificarVenta(ventaAGuardar);
      }

      // 2. Si apretó "Guardar y PDF", generamos y abrimos el archivo
      if (exportarPdf) {
        final pdfBytes = await PdfService().generarBoleta(ventaAGuardar);
        final directorio = await getApplicationDocumentsDirectory();
        final nombreArchivo = 'Boleta_${cliente.nombre.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final ruta = '${directorio.path}/$nombreArchivo';
        
        final archivo = File(ruta);
        await archivo.writeAsBytes(pdfBytes);
        
        // Abrimos el PDF automáticamente
        await OpenFilex.open(ruta);
      }

      if (!mounted) return;
      Navigator.pop(context, true); 

    } catch (e) {
      debugPrint(" ERROR AL GUARDAR/EXPORTAR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isGuardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Venta'),
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _construirTarjetaCliente(),
            const SizedBox(height: 16),
            _construirSeccionProductos(),
          ],
        ),
      ),
      bottomNavigationBar: _construirBarraInferior(),
    );
  }

  // --- WIDGETS MODULARIZADOS ---

  Widget _construirTarjetaCliente() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DATOS DEL CLIENTE', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreClienteCtrl,
              decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder()),
              validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _telefonoCtrl,
                    decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _canalSeleccionado,
                    decoration: const InputDecoration(labelText: 'Plataforma', border: OutlineInputBorder()),
                    items: _canales.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _canalSeleccionado = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _domicilioCtrl,
              decoration: const InputDecoration(labelText: 'Dirección (Opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text("Fecha: ${_fechaManual.day}/${_fechaManual.month}/${_fechaManual.year}"),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: _seleccionarFecha,
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirSeccionProductos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PRODUCTOS', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => setState(() => _renglones.add(ControladorRenglon())),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          
            ...List.generate(_renglones.length, (index) => _construirRenglon(index)),
          ],
        ),
      ),
    );
  }

  Widget _construirRenglon(int index) {
    final renglon = _renglones[index];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Expanded(
            flex: 3,
            child: RawAutocomplete<Producto>(
              focusNode: renglon.productoFocus,
              textEditingController: renglon.productoCtrl,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return const Iterable<Producto>.empty();
                return _catalogoProductos.where((Producto p) =>
                    p.nombre.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: (Producto p) => p.nombre,
              onSelected: (Producto p) {
                renglon.productoExistente = p;
                renglon.precioCtrl.text = p.precioActual.toStringAsFixed(2); 
                setState(() {});
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Producto ${index + 1}', 
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: SizedBox(
                      height: 200,
                      width: 300,
                      child: ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, i) {
                          final option = options.elementAt(i);
                          return ListTile(
                            title: Text(option.nombre),
                            subtitle: Text('\$${option.precioActual}'),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // Cantidad
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: renglon.cantidadCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cant.', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}), 
            ),
          ),
          const SizedBox(width: 8),
          // Precio Unitario
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: renglon.precioCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio', border: OutlineInputBorder(), prefixText: '\$ '),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Botón Eliminar Renglón
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () {
              if (_renglones.length > 1) {
                setState(() => _renglones.removeAt(index));
              }
            },
          ),
        ],
      ),
    );
  }

Widget _construirBarraInferior() {
  double total = _calcularTotalVisible();
  double pago = double.tryParse(_pagoClienteCtrl.text) ?? 0;
  double deuda = total - pago;

  
  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Columna de Totales (Izquierda)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: \$ ${total.toStringAsFixed(2)}', 
                        style: const TextStyle(color: Colors.white70)),
                    Text(
                      'Debe: \$ ${deuda.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: deuda > 0 ? Colors.redAccent : Colors.greenAccent
                      ),
                    ),
                  ],
                ),
                // Campo de entrada de pago (Derecha)
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    controller: _pagoClienteCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    decoration: const InputDecoration(
                      labelText: 'Paga con \$',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}), // Actualiza la deuda en tiempo real
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Fila de botones: Guardar y Guardar + PDF
            Row(
              children: [
                // Botón solo Guardar
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGuardando ? null : () => _guardarVenta(false),
                    icon: _isGuardando 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(_isGuardando ? '...' : 'Guardar'),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Botón Guardar y Generar PDF
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGuardando ? null : () => _guardarVenta(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isGuardando 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(_isGuardando ? '...' : 'Guardar y PDF'),
                  ),
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