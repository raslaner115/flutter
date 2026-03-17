import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/language_provider.dart';

class VerifyBusinessPage extends StatefulWidget {
  const VerifyBusinessPage({super.key});

  @override
  State<VerifyBusinessPage> createState() => _VerifyBusinessPageState();
}

class _VerifyBusinessPageState extends State<VerifyBusinessPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _businessNameController = TextEditingController();
  File? _docImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _docImage = File(picked.path));
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate() || _docImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields and upload a document image')));
      return;
    }

    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final storageRef = FirebaseStorage.instance.ref().child('verifications/${user.uid}/business_doc.jpg');
      await storageRef.putFile(_docImage!);
      final docUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('verifications').doc(user.uid).set({
        'userId': user.uid,
        'businessId': _idController.text.trim(),
        'businessName': _businessNameController.text.trim(),
        'documentUrl': docUrl,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Verification request submitted. We will review it shortly.'),
            actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isHe = locale == 'he';

    return Directionality(
      textDirection: isHe ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(isHe ? 'אימות עוסק' : 'Business Verification'), backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
        body: _isUploading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(isHe ? 'הגש מסמכים לאימות חשבון' : 'Submit documents for account verification', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: InputDecoration(labelText: isHe ? 'שם העסק / שם מלא' : 'Business Name / Full Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _idController,
                      decoration: InputDecoration(labelText: isHe ? 'מספר עוסק / ת.ז' : 'Business ID / ID Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    Text(isHe ? 'צילום אישור עוסק פטור/מורשה' : 'Upload Business Certificate (Dealer)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                        child: _docImage != null 
                          ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_docImage!, fit: BoxFit.cover))
                          : const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _submitVerification, 
                      child: Text(isHe ? 'שלח לאימות' : 'Submit for Verification', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}
