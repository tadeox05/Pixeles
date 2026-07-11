import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/venta.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PdfService {
  

Future<Uint8List> generarBoleta(Venta venta) async {
    final pdf = pw.Document();

    
    pw.MemoryImage? logoSuperior;
    pw.MemoryImage? imagenInferior;
    pw.MemoryImage? marcaDeAgua; 
    
    try {
      final ByteData bytesLogo = await rootBundle.load('assets/logo_p.jpeg');
      logoSuperior = pw.MemoryImage(bytesLogo.buffer.asUint8List());
    } catch (e) {
      debugPrint("No se pudo cargar logo_p.jpeg: $e");
    }

    try {
      final ByteData bytesInferior = await rootBundle.load('assets/logo_completo.jpeg'); 
      imagenInferior = pw.MemoryImage(bytesInferior.buffer.asUint8List());
    } catch (e) {
      debugPrint("No se pudo cargar logo_completo.jpeg: $e");
    }

    try {
      final ByteData bytesAgua = await rootBundle.load('assets/logo_p.png');
      marcaDeAgua = pw.MemoryImage(bytesAgua.buffer.asUint8List());
    } catch (e) {
      debugPrint("No se pudo cargar logo_p.png: $e");
    }

    // CONSTRUIMOS EL DOCUMENTO
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // --- CAPA 1: FONDO (MARCA DE AGUA) ---
              if (marcaDeAgua != null)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.1, // 10% de opacidad (bien transparente)
                      child: pw.Image(marcaDeAgua, width: 350), // Tamaño gigante
                    ),
                  ),
                ),

              // --- CAPA 2: FRENTE (CONTENIDO DE LA BOLETA) ---
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _construirEncabezado(venta, logoSuperior),
                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 10),
                  _construirInfoCliente(venta),
                  pw.SizedBox(height: 15),
                  
                  
                  _construirTablaProductos(venta),
                  
                  
                  pw.Spacer(),
                  
                  
                  _construirPiePagina(venta, imagenInferior),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

 // NUEVO ENCABEZADO
  pw.Widget _construirEncabezado(Venta venta, pw.MemoryImage? logoSuperior) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // IZQUIERDA
        pw.Expanded(
          flex: 4,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 45,
                height: 45,
                child: logoSuperior != null ? pw.Image(logoSuperior) : pw.SizedBox(),
              ),
              pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("PIXELES", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                  pw.Text("SERVICIOS GRÁFICOS", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text("WhatsApp: 343-6453201", style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("3 de Febrero 1181 - La Paz (E.R)", style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ],
          ),
        ),

        // 2. CENTRO: 
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Text("X", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 2),
              pw.Text("DOCUMENTO NO", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Text("VÁLIDO COMO FACTURA", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                child: pw.Column(
                  children: [
                    pw.Text("PENDIENTES", style: const pw.TextStyle(fontSize: 7)),
                    pw.Text("PRESUPUESTO", style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. DERECHA
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text("FECHA", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  _cajitaFecha(venta.fecha.day.toString().padLeft(2, '0')),
                  pw.SizedBox(width: 2),
                  _cajitaFecha(venta.fecha.month.toString().padLeft(2, '0')),
                  pw.SizedBox(width: 2),
                  _cajitaFecha(venta.fecha.year.toString().substring(2)), // Extrae el "26" en lugar de "2026"
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  
  pw.Widget _cajitaFecha(String texto) {
    return pw.Container(
      width: 22,
      height: 22,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
      child: pw.Text(texto, style: const pw.TextStyle(fontSize: 9)),
    );
  }


  // 2. DATOS DEL CLIENTE
  pw.Widget _construirInfoCliente(Venta venta) {
    return pw.Column(
      children: [
        _renglonCliente("Cliente:", venta.cliente.nombre),
        pw.SizedBox(height: 6),
        _renglonCliente("Domicilio:", venta.cliente.domicilio ?? ""),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(child: _renglonCliente("Cuenta Nº:", "")),
            pw.SizedBox(width: 20),
            pw.Expanded(child: _renglonCliente("Teléfono:", venta.cliente.telefono ?? "")),
          ],
        )
      ],
    );
  }


  pw.Widget _renglonCliente(String etiqueta, String valor) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(etiqueta, style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(width: 5),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 2),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.black)),
            ),
            child: pw.Text(valor, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // 3. LA TABLA DE PRODUCTOS
  pw.Widget _construirTablaProductos(Venta venta) {
    final headers = ['CANT.', 'DETALLE', 'PARCIAL', 'IMPORTE'];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: venta.detalles.map((d) => [
        d.cantidad.toString(),
        d.producto.nombre,
        "\$ ${d.precioUnitario.toStringAsFixed(2)}",
        "\$ ${d.subtotal.toStringAsFixed(2)}",
      ]).toList(),
      border: pw.TableBorder.all(width: 1),
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: const pw.TextStyle(fontSize: 11),
      cellHeight: 25,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
    );
  }

pw.Widget _construirPiePagina(Venta venta, pw.MemoryImage? imagenInferior) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Container(
                height: 50,
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Observaciones:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text(venta.observaciones ?? "", style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                height: 50,
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: const pw.BorderSide(width: 1),
                    bottom: const pw.BorderSide(width: 1),
                    right: const pw.BorderSide(width: 1),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 40,
                      alignment: pw.Alignment.center,
                      child: pw.Text("TOTAL", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        alignment: pw.Alignment.center,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(left: pw.BorderSide(width: 1)),
                        ),
                        child: pw.Text("\$ ${venta.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 25),
        
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            
            pw.Container(
              width: 220, 
              child: imagenInferior != null 
                ? pw.Image(imagenInferior)
                : pw.Text("PIXELES SERVICIOS GRÁFICOS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)), 
            ),
            
            // Protección contra IDs nulos garantizada
            pw.Text("Nº: ${(venta.id ?? 0).toString().padLeft(6, '0')}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            
            pw.Container(
              width: 120,
              padding: const pw.EdgeInsets.only(bottom: 2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1, style: pw.BorderStyle.dashed)),
              ),
              child: pw.Text("Firma:", style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ],
    );
  }
}