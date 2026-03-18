import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:untitled1/language_provider.dart';

class InvoiceItem {
  final String description;
  final double price;
  InvoiceItem({required this.description, required this.price});
}

class InvoiceBuilderPage extends StatefulWidget {
  final String workerName;
  final String? workerPhone;
  final String? workerEmail;

  const InvoiceBuilderPage({
    super.key,
    required this.workerName,
    this.workerPhone,
    this.workerEmail,
  });

  @override
  State<InvoiceBuilderPage> createState() => _InvoiceBuilderPageState();
}

class _InvoiceBuilderPageState extends State<InvoiceBuilderPage> {
  final _clientNameController = TextEditingController();
  final _clientAddressController = TextEditingController();
  final _itemDescController = TextEditingController();
  final _itemPriceController = TextEditingController();
  final List<InvoiceItem> _items = [];
  bool _isPreparing = false;

  Map<String, String> _getLocalizedStrings(BuildContext context, {bool listen = true}) {
    final locale = Provider.of<LanguageProvider>(context, listen: listen).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'title': 'מפיק חשבוניות (הצעת מחיר)',
          'client_info': 'פרטי לקוח',
          'client_name': 'שם הלקוח',
          'client_address': 'כתובת הלקוח (אופציונלי)',
          'items': 'פריטים',
          'desc': 'תיאור',
          'price': 'מחיר',
          'add_item': 'הוסף פריט',
          'total': 'סה"כ',
          'generate': 'הפק מסמך PDF',
          'empty_items': 'נא להוסיף לפחות פריט אחד',
          'invoice_title': 'הצעת מחיר / קבלה',
          'worker': 'מפיק:',
          'date': 'תאריך:',
          'preparing': 'מכין את המסמך...',
          'legal_disclaimer': 'מסמך זה הופק באמצעות HireHub ומשמש כהצעת מחיר או תיעוד פנימי בלבד. אין לראות בו חשבונית מס כחוק אלא אם נחתם דיגיטלית כדין.',
        };
      default:
        return {
          'title': 'Invoice / Quote Builder',
          'client_info': 'Client Information',
          'client_name': 'Client Name',
          'client_address': 'Client Address (Optional)',
          'items': 'Items',
          'desc': 'Description',
          'price': 'Price',
          'add_item': 'Add Item',
          'total': 'Total',
          'generate': 'Generate PDF',
          'empty_items': 'Please add at least one item',
          'invoice_title': 'Quote / Receipt',
          'worker': 'Provider:',
          'date': 'Date:',
          'preparing': 'Preparing document...',
          'legal_disclaimer': 'This document was generated via HireHub and is for internal record-keeping or quotes only. It is not a legal Tax Invoice unless properly signed.',
        };
    }
  }

  void _addItem() {
    if (_itemDescController.text.isEmpty || _itemPriceController.text.isEmpty) return;
    final price = double.tryParse(_itemPriceController.text) ?? 0.0;
    setState(() {
      _items.add(InvoiceItem(description: _itemDescController.text, price: price));
      _itemDescController.clear();
      _itemPriceController.clear();
    });
  }

  Future<void> _displayPdf() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getLocalizedStrings(context, listen: false)['empty_items']!)));
      return;
    }

    setState(() => _isPreparing = true);

    try {
      // Load fonts from assets instead of the network
      final fontData = await rootBundle.load("assets/fonts/Rubik-VariableFont_wght.ttf");
      final fontBoldData = await rootBundle.load("assets/fonts/Rubik-VariableFont_wght.ttf");
      
      final font = pw.Font.ttf(fontData);
      final fontBold = pw.Font.ttf(fontBoldData);

      if (!mounted) return;
      setState(() => _isPreparing = false);

      await Printing.layoutPdf(
        onLayout: (format) async {
          final pdfBytes = await _generatePdf(format, font, fontBold);
          return pdfBytes;
        },
        name: 'Invoice_${intl.DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) setState(() => _isPreparing = false);
      debugPrint("PDF Generation Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    }
  }

  Future<Uint8List> _generatePdf(pdf.PdfPageFormat format, pw.Font font, pw.Font fontBold) async {
    final doc = pw.Document();
    // Use listen: false because we are inside an async function/callback
    final strings = _getLocalizedStrings(context, listen: false);
    final dateStr = intl.DateFormat('dd/MM/yyyy').format(DateTime.now());
    final total = _items.fold(0.0, (sum, item) => sum + item.price);
    final locale = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    final isRtl = locale == 'he' || locale == 'ar';

    doc.addPage(
      pw.Page(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) {
          return pw.Directionality(
            textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('HireHub', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: pdf.PdfColors.blue900)),
                    pw.Text(strings['invoice_title']!, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("${strings['worker']} ${widget.workerName}"),
                        if (widget.workerPhone != null) pw.Text(widget.workerPhone!),
                        if (widget.workerEmail != null) pw.Text(widget.workerEmail!),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("${strings['date']} $dateStr"),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text(strings['client_info']!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(_clientNameController.text.isEmpty ? "---" : _clientNameController.text),
                if (_clientAddressController.text.isNotEmpty) pw.Text(_clientAddressController.text),
                pw.SizedBox(height: 30),
                // Using stable Table.fromTextArray
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headers: [strings['desc']!, strings['price']!],
                  data: _items.map((item) => [item.description, "${item.price.toStringAsFixed(2)} ₪"]).toList(),
                  headerDecoration: const pw.BoxDecoration(color: pdf.PdfColors.grey200),
                  cellAlignment: pw.Alignment.centerLeft,
                  headerAlignment: pw.Alignment.centerLeft,
                ),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text("${strings['total']}: ${total.toStringAsFixed(2)} ₪", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Spacer(),
                pw.Divider(),
                pw.Text(strings['legal_disclaimer']!, style: const pw.TextStyle(fontSize: 10, color: pdf.PdfColors.grey700), textAlign: pw.TextAlign.center),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isRtl = locale == 'he' || locale == 'ar';

    return Directionality(
      textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(strings['title']!),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(strings['client_info']!),
                  const SizedBox(height: 12),
                  _buildTextField(_clientNameController, strings['client_name']!),
                  const SizedBox(height: 12),
                  _buildTextField(_clientAddressController, strings['client_address']!),
                  const SizedBox(height: 24),
                  _buildSectionTitle(strings['items']!),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(flex: 3, child: _buildTextField(_itemDescController, strings['desc']!)),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: _buildTextField(_itemPriceController, strings['price']!, keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add_circle, color: Color(0xFF1976D2), size: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._items.asMap().entries.map((entry) => _buildItemTile(entry.key, entry.value)),
                  if (_items.isNotEmpty) ...[
                    const Divider(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(strings['total']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text("${_items.fold(0.0, (sum, item) => sum + item.price).toStringAsFixed(2)} ₪", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                      ],
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isPreparing ? null : _displayPdf,
                        icon: _isPreparing 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.picture_as_pdf),
                        label: Text(_isPreparing ? strings['preparing']! : strings['generate']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_isPreparing)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)));
  }

  Widget _buildTextField(TextEditingController controller, String label, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildItemTile(int index, InvoiceItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        title: Text(item.description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${item.price.toStringAsFixed(2)} ₪", style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => setState(() => _items.removeAt(index)),
            ),
          ],
        ),
      ),
    );
  }
}
