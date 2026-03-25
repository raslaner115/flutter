import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:untitled1/services/language_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

class InvoiceItem {
  final String description;
  final int quantity;
  final double price;
  InvoiceItem({required this.description, this.quantity = 1, required this.price});

  double get total => quantity * price;
}

class InvoiceBuilderPage extends StatefulWidget {
  final String workerName;
  final String? workerPhone;
  final String? workerEmail;
  final String? receiverId;
  final String? receiverName;

  const InvoiceBuilderPage({
    super.key,
    required this.workerName,
    this.workerPhone,
    this.workerEmail,
    this.receiverId,
    this.receiverName,
  });

  @override
  State<InvoiceBuilderPage> createState() => _InvoiceBuilderPageState();
}

class _InvoiceBuilderPageState extends State<InvoiceBuilderPage> {
  final _clientNameController = TextEditingController();
  final _clientAddressController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _itemDescController = TextEditingController();
  final _itemQtyController = TextEditingController(text: "1");
  final _itemPriceController = TextEditingController();
  final _notesController = TextEditingController();

  final List<InvoiceItem> _items = [];
  bool _isPreparing = false;
  String _invoiceNumber = "";
  double _totalAmount = 0.0;

  // State for dealer logic
  String _dealerType = 'exempt';
  bool _isBusinessVerified = false;
  String _selectedDocType = 'receipt';

  pw.Font? _cachedFont;
  pw.Font? _cachedFontBold;
  pw.MemoryImage? _cachedLogo;
  Map<String, String>? _cachedStrings;
  String? _lastLocale;

  @override
  void initState() {
    super.initState();
    _invoiceNumber = "DOC-${intl.DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}";
    if (widget.receiverName != null) {
      _clientNameController.text = widget.receiverName!;
    }

    _fetchWorkerInfo();

    if (widget.receiverId != null) {
      _fetchClientInfo(widget.receiverId!);
    }

    _loadAssets();
  }

  Future<void> _fetchWorkerInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            _isBusinessVerified = data?['isBusinessVerified'] ?? false;
            _dealerType = data?['dealerType'] ?? 'exempt';

            // Logic: Must be both Verified AND Licensed to use Invoices
            if (_isBusinessVerified && _dealerType == 'licensed') {
              _selectedDocType = 'invoice_receipt';
            } else {
              _selectedDocType = 'receipt';
            }
          });
        }
      } catch (e) {
        dev.log("Error fetching worker info: $e");
      }
    }
  }

  Future<void> _fetchClientInfo(String clientId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(clientId).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          if (data?['name'] != null && _clientNameController.text.isEmpty) {
            _clientNameController.text = data!['name'];
          }
          if (data?['phone'] != null) {
            _clientPhoneController.text = data!['phone'];
          }
          if (data?['town'] != null) {
            _clientAddressController.text = data!['town'];
          }
        });
      }
    } catch (e) {
      dev.log("Error fetching client info: $e");
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientAddressController.dispose();
    _clientPhoneController.dispose();
    _itemDescController.dispose();
    _itemQtyController.dispose();
    _itemPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final fontData = await rootBundle.load("assets/fonts/Rubik-VariableFont_wght.ttf");
      _cachedFont = pw.Font.ttf(fontData);
      _cachedFontBold = pw.Font.ttf(fontData);

      try {
        final logoData = await rootBundle.load("assets/icon/app_icon.png");
        _cachedLogo = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (e) {
        dev.log("Logo load failed: $e");
      }
    } catch (e) {
      dev.log("Font load failed: $e");
    }
  }

  Map<String, String> _getLocalizedStrings(BuildContext context, {bool listen = true}) {
    final locale = Provider.of<LanguageProvider>(context, listen: listen).locale.languageCode;

    if (_cachedStrings != null && _lastLocale == locale) {
      return _cachedStrings!;
    }

    _lastLocale = locale;
    switch (locale) {
      case 'he':
        _cachedStrings = {
          'title': 'מפיק מסמכים עסקיים',
          'client_info': 'פרטי לקוח',
          'client_name': 'שם הלקוח',
          'client_address': 'כתובת הלקוח (אופציונלי)',
          'client_phone': 'טלפון הלקוח',
          'items': 'פריטים',
          'desc': 'תיאור השירות/מוצר',
          'qty': 'כמות',
          'price': 'מחיר ליחידה',
          'add_item': 'הוסף פריט',
          'total': 'סה"כ לתשלום',
          'generate': 'תצוגה מקדימה / הדפסה',
          'empty_items': 'נא להוסיף לפחות פריט אחד',
          'worker': 'ספק שירות:',
          'date': 'תאריך:',
          'inv_no': 'מספר מסמך:',
          'preparing': 'מכין את המסמך...',
          'legal_disclaimer': 'מסמך זה הופק באמצעות אפליקציית HireHub. מסמך זה משמש כהצעת מחיר או דרישת תשלום פנימית בלבד. אין לראות בו חשבונית מס כחוק אלא אם נחתם דיגיטלית כדין על פי תקנות רשות המיסים.',
          'send_to_contact': 'שלח ישירות בצ׳אט',
          'send_to': 'שלח ל-',
          'no_contacts': 'לא נמצאו אנשי קשר',
          'sent_success': 'המסמך נשלח בהצלחה!',
          'notes': 'הערות נוספות (תנאי תשלום וכו\')',
          'subtotal': 'סיכום ביניים',
          'doc_type': 'סוג המסמך',
          'receipt': 'קבלה',
          'invoice': 'חשבונית מס',
          'invoice_receipt': 'חשבונית מס / קבלה',
          'licensed_only': 'זמין לעוסק מורשה מאומת בלבד',
        };
        break;
      default:
        _cachedStrings = {
          'title': 'Business Document Builder',
          'client_info': 'Client Information',
          'client_name': 'Client Name',
          'client_address': 'Client Address (Optional)',
          'client_phone': 'Client Phone',
          'items': 'Service Items',
          'desc': 'Description',
          'qty': 'Qty',
          'price': 'Unit Price',
          'add_item': 'Add Item',
          'total': 'Grand Total',
          'generate': 'Preview / Print PDF',
          'empty_items': 'Please add at least one item',
          'worker': 'Service Provider:',
          'date': 'Date:',
          'inv_no': 'Document No:',
          'preparing': 'Preparing document...',
          'legal_disclaimer': 'Generated via HireHub. This document serves as a quote or payment request. It is not a legal Tax Invoice unless properly signed according to tax regulations.',
          'send_to_contact': 'Send to Contact',
          'send_to': 'Send to ',
          'no_contacts': 'No contacts found',
          'sent_success': 'Invoice sent successfully!',
          'notes': 'Notes / Payment Terms',
          'subtotal': 'Subtotal',
          'doc_type': 'Document Type',
          'receipt': 'Receipt',
          'invoice': 'Tax Invoice',
          'invoice_receipt': 'Tax Invoice / Receipt',
          'licensed_only': 'Verified Licensed Dealers only',
        };
    }
    return _cachedStrings!;
  }

  void _addItem() {
    if (_itemDescController.text.isEmpty || _itemPriceController.text.isEmpty) return;
    final price = double.tryParse(_itemPriceController.text) ?? 0.0;
    final qty = int.tryParse(_itemQtyController.text) ?? 1;
    setState(() {
      final newItem = InvoiceItem(description: _itemDescController.text, quantity: qty, price: price);
      _items.add(newItem);
      _totalAmount += newItem.total;
      _itemDescController.clear();
      _itemPriceController.clear();
      _itemQtyController.text = "1";
    });
  }

  void _removeItem(int index) {
    setState(() {
      _totalAmount -= _items[index].total;
      _items.removeAt(index);
    });
  }

  Future<Uint8List?> _getGeneratedPdfBytes() async {
    if (_items.isEmpty) return null;

    try {
      if (_cachedFont == null) await _loadAssets();
      return await _generatePdf(pdf.PdfPageFormat.a4, _cachedFont!, _cachedFontBold!, _cachedLogo);
    } catch (e) {
      dev.log("Error generating PDF: $e");
      return null;
    }
  }

  Future<void> _displayPdf() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getLocalizedStrings(context, listen: false)['empty_items']!)));
      return;
    }

    setState(() => _isPreparing = true);

    try {
      if (_cachedFont == null) await _loadAssets();

      if (!mounted) return;
      setState(() => _isPreparing = false);

      await Printing.layoutPdf(
        onLayout: (format) async {
          return await _generatePdf(format, _cachedFont!, _cachedFontBold!, _cachedLogo);
        },
        name: '$_invoiceNumber.pdf',
      );
    } catch (e) {
      if (mounted) setState(() => _isPreparing = false);
      dev.log("PDF Layout Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    }
  }

  Future<void> _showContactPickerAndSend() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getLocalizedStrings(context, listen: false)['empty_items']!)));
      return;
    }

    if (widget.receiverId != null) {
      _sendToContact(widget.receiverId!, widget.receiverName ?? "User");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final strings = _getLocalizedStrings(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings['send_to_contact']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chat_rooms')
                      .where('users', arrayContains: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final rooms = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final List users = data['users'] ?? [];
                      return !users.contains('hirehub_manager');
                    }).toList();

                    if (rooms.isEmpty) return Center(child: Text(strings['no_contacts']!));

                    return ListView.builder(
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final data = rooms[index].data() as Map<String, dynamic>;
                        final List users = data['users'] ?? [];
                        final otherId = users.firstWhere((id) => id != user.uid, orElse: () => "");
                        final Map names = data['userNames'] ?? {};
                        final otherName = names[otherId] ?? "User";

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1976D2).withValues(alpha: 0.1),
                            child: Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : "?", style: const TextStyle(color: Color(0xFF1976D2))),
                          ),
                          title: Text(otherName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () {
                            Navigator.pop(context);
                            _sendToContact(otherId, otherName);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendToContact(String receiverId, String receiverName) async {
    setState(() => _isPreparing = true);
    final strings = _getLocalizedStrings(context, listen: false);

    try {
      final pdfBytes = await _getGeneratedPdfBytes();
      if (pdfBytes == null) throw "Failed to generate PDF";

      final fileName = '$_invoiceNumber.pdf';
      final ref = firebase_storage.FirebaseStorage.instance.ref().child('chat_media/files/$fileName');

      final uploadTask = await ref.putData(pdfBytes, firebase_storage.SettableMetadata(contentType: 'application/pdf'));
      final url = await uploadTask.ref.getDownloadURL();

      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final ids = [currentUserId, receiverId];
      ids.sort();
      final chatRoomId = ids.join('_');

      final messageData = {
        'senderId': currentUserId,
        'receiverId': receiverId,
        'message': '',
        'type': 'file',
        'url': url,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData);

      await FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).set({
        'lastMessage': "📄 File: $fileName",
        'lastTimestamp': FieldValue.serverTimestamp(),
        'users': [currentUserId, receiverId],
        'userNames': {
          currentUserId: FirebaseAuth.instance.currentUser!.displayName ?? "User",
          receiverId: receiverName,
        }
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _isPreparing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings['sent_success']!)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _isPreparing = false);
      dev.log("Error sending PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<Uint8List> _generatePdf(pdf.PdfPageFormat format, pw.Font font, pw.Font fontBold, pw.MemoryImage? logo) async {
    final doc = pw.Document();
    final strings = _getLocalizedStrings(context, listen: false);
    final dateStr = intl.DateFormat('dd/MM/yyyy').format(DateTime.now());
    final locale = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    final isRtl = locale == 'he' || locale == 'ar';
    final themeColor = pdf.PdfColors.blue900;

    String docTitle;
    switch (_selectedDocType) {
      case 'invoice': docTitle = strings['invoice']!; break;
      case 'invoice_receipt': docTitle = strings['invoice_receipt']!; break;
      default: docTitle = strings['receipt']!;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) {
          return [
            pw.Directionality(
              textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (logo != null)
                            pw.Container(width: 60, height: 60, child: pw.Image(logo))
                          else
                            pw.Text('HireHub', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: themeColor)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(docTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: themeColor)),
                          pw.SizedBox(height: 4),
                          pw.Text("${strings['inv_no']} $_invoiceNumber", style: const pw.TextStyle(fontSize: 10)),
                          pw.Text("${strings['date']} $dateStr", style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.Divider(thickness: 1, color: themeColor),
                  pw.SizedBox(height: 20),

                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(strings['worker']!, style: pw.TextStyle(fontSize: 10, color: pdf.PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text(widget.workerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            if (widget.workerPhone != null) pw.Text(widget.workerPhone!, style: const pw.TextStyle(fontSize: 10)),
                            if (widget.workerEmail != null) pw.Text(widget.workerEmail!, style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 40),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(strings['client_info']!, style: pw.TextStyle(fontSize: 10, color: pdf.PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text(_clientNameController.text.isEmpty ? "---" : _clientNameController.text, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            if (_clientPhoneController.text.isNotEmpty) pw.Text(_clientPhoneController.text, style: const pw.TextStyle(fontSize: 10)),
                            if (_clientAddressController.text.isNotEmpty)
                              pw.Text(_clientAddressController.text, style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 30),

                  pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pdf.PdfColors.white, fontSize: 10),
                    cellStyle: const pw.TextStyle(fontSize: 10),
                    headers: [strings['desc']!, strings['qty']!, strings['price']!, strings['total']!],
                    data: _items.map((item) => [
                      item.description,
                      item.quantity.toString(),
                      "${item.price.toStringAsFixed(2)} ₪",
                      "${item.total.toStringAsFixed(2)} ₪"
                    ]).toList(),
                    headerDecoration: pw.BoxDecoration(color: themeColor),
                    cellAlignment: isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                    headerAlignment: isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                    cellPadding: const pw.EdgeInsets.all(8),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(4),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                    border: pw.TableBorder.all(color: pdf.PdfColors.grey200, width: 0.5),
                  ),

                  pw.SizedBox(height: 20),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (_notesController.text.isNotEmpty) ...[
                              pw.Text(strings['notes']!, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: themeColor)),
                              pw.SizedBox(height: 4),
                              pw.Text(_notesController.text, style: const pw.TextStyle(fontSize: 9)),
                            ],
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.all(12),
                              decoration: const pw.BoxDecoration(
                                color: pdf.PdfColors.blue50,
                                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                              ),
                              child: pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(strings['total']!, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: themeColor)),
                                  pw.Text("${_totalAmount.toStringAsFixed(2)} ₪", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: themeColor)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 50),
                  pw.Divider(color: pdf.PdfColors.grey300),
                  pw.SizedBox(height: 10),
                  pw.Text(strings['legal_disclaimer']!, style: const pw.TextStyle(fontSize: 8, color: pdf.PdfColors.grey600), textAlign: pw.TextAlign.center),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final isRtl = Provider.of<LanguageProvider>(context).locale.languageCode == 'he' || 
                 Provider.of<LanguageProvider>(context).locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(strings['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1976D2),
          elevation: 0,
          centerTitle: true,
        ),
        body: _isPreparing
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF1976D2)),
                  const SizedBox(height: 16),
                  Text(strings['preparing']!),
                ],
              ))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionCard(
                      title: strings['doc_type']!,
                      icon: Icons.article_outlined,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedDocType,
                          decoration: _inputStyle(strings['doc_type']!, Icons.description_outlined),
                          items: [
                            DropdownMenuItem(value: 'receipt', child: Text(strings['receipt']!)),
                            DropdownMenuItem(
                              value: 'invoice', 
                              enabled: _dealerType == 'licensed' && _isBusinessVerified,
                              child: Text(
                                strings['invoice']! + ((_dealerType != 'licensed' || !_isBusinessVerified) ? " (${strings['licensed_only']})" : ""),
                                style: TextStyle(color: (_dealerType == 'licensed' && _isBusinessVerified) ? Colors.black : Colors.grey),
                              )
                            ),
                            DropdownMenuItem(
                              value: 'invoice_receipt', 
                              enabled: _dealerType == 'licensed' && _isBusinessVerified,
                              child: Text(
                                strings['invoice_receipt']! + ((_dealerType != 'licensed' || !_isBusinessVerified) ? " (${strings['licensed_only']})" : ""),
                                style: TextStyle(color: (_dealerType == 'licensed' && _isBusinessVerified) ? Colors.black : Colors.grey),
                              )
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDocType = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: strings['client_info']!,
                      icon: Icons.person_add_alt_1_rounded,
                      children: [
                        _buildTextField(_clientNameController, strings['client_name']!, Icons.person_outline),
                        const SizedBox(height: 12),
                        _buildTextField(_clientPhoneController, strings['client_phone']!, Icons.phone_outlined, keyboardType: TextInputType.phone),
                        const SizedBox(height: 12),
                        _buildTextField(_clientAddressController, strings['client_address']!, Icons.location_on_outlined),
                      ],
                    ),

                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: strings['items']!,
                      icon: Icons.list_alt_rounded,
                      children: [
                        _buildTextField(_itemDescController, strings['desc']!, Icons.description_outlined),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_itemQtyController, strings['qty']!, Icons.numbers_rounded, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField(_itemPriceController, strings['price']!, Icons.sell_outlined, keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(strings['add_item']!),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2).withValues(alpha: 0.1),
                              foregroundColor: const Color(0xFF1976D2),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              title: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text("${item.quantity} x ${item.price.toStringAsFixed(2)} ₪"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("${item.total.toStringAsFixed(2)} ₪", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                    onPressed: () => _removeItem(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: strings['notes']!,
                      icon: Icons.note_add_outlined,
                      children: [
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: strings['notes'],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    if (_items.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: const Color(0xFF1976D2).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(strings['total']!, style: const TextStyle(color: Colors.white, fontSize: 16)),
                                Text("${_totalAmount.toStringAsFixed(2)} ₪",
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _displayPdf,
                                    icon: const Icon(Icons.print_rounded),
                                    label: Text(strings['generate']!),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _showContactPickerAndSend,
                                    icon: const Icon(Icons.send_rounded),
                                    label: Text(widget.receiverId != null ? (isRtl ? "שלח ישירות" : "Send Direct") : (isRtl ? "שלח איש קשר" : "Send Contact")),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF1976D2),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF1976D2)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputStyle(label, icon),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
