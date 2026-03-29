import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/services/language_provider.dart';

class VerifyBusinessPage extends StatefulWidget {
  const VerifyBusinessPage({super.key});

  @override
  State<VerifyBusinessPage> createState() => _VerifyBusinessPageState();
}

class _VerifyBusinessPageState extends State<VerifyBusinessPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxBranchController = TextEditingController();
  
  File? _idCardImage;
  File? _businessCertImage;
  File? _insuranceImage;
  
  String _dealerType = 'exempt'; // 'exempt' (פטור) or 'licensed' (מורשה)
  bool _isUploading = false;
  bool _acceptedTerms = false;
  bool _acceptedDataPrivacy = false;
  bool _isLegalDeclarationSigned = false;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _idController.dispose();
    _businessNameController.dispose();
    _addressController.dispose();
    _taxBranchController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked != null) {
        setState(() {
          if (type == 'id') _idCardImage = File(picked.path);
          if (type == 'cert') _businessCertImage = File(picked.path);
          if (type == 'insurance') _insuranceImage = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint("Pick error: $e");
    }
  }

  Future<String> _uploadToStorage(File file, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final uploadTask = ref.putFile(file, metadata);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _submitVerification() async {
    final isHe = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'he';
    
    if (!_formKey.currentState!.validate()) return;
    
    if (_idCardImage == null || _businessCertImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isHe ? 'אנא העלה תעודת זהות ואישור עוסק' : 'Please upload ID and Business Certificate'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    if (!_acceptedTerms || !_acceptedDataPrivacy || !_isLegalDeclarationSigned) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isHe ? 'עליך לאשר את כל הצהרות החוקיות' : 'You must accept all legal declarations'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      
      // Sequential uploads to avoid storage task state warnings
      final idUrl = await _uploadToStorage(_idCardImage!, 'verifications/${user.uid}/id_card.jpg');
      final certUrl = await _uploadToStorage(_businessCertImage!, 'verifications/${user.uid}/business_cert.jpg');

      String? insuranceUrl;
      if (_insuranceImage != null) {
        insuranceUrl = await _uploadToStorage(_insuranceImage!, 'verifications/${user.uid}/insurance.jpg');
      }

      final businessId = _idController.text.trim();
      final verificationData = {
        'userId': user.uid,
        'businessId': businessId,
        'businessName': _businessNameController.text.trim(),
        'address': _addressController.text.trim(),
        'taxBranch': _taxBranchController.text.trim(),
        'dealerType': _dealerType,
        'idCardUrl': idUrl,
        'businessCertUrl': certUrl,
        'insuranceUrl': insuranceUrl,
        'hasInsurance': _insuranceImage != null,
        'status': 'pending',
        'legalAccepted': true,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Save to verifications collection
      await FirebaseFirestore.instance.collection('verifications').doc(user.uid).set(verificationData);

      // Update user document in unified 'users' collection
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'dealerType': _dealerType,
        'businessId': businessId,
        'businessVerificationStatus': 'pending',
      });

      if (mounted) {
        _showSuccessDialog(isHe);
      }
    } catch (e) {
      debugPrint("Verification submit error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSuccessDialog(bool isHe) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Icon(Icons.verified_user, size: 50, color: Colors.green[600]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isHe ? 'הבקשה הוגשה בהצלחה' : 'Request Submitted!', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Text(isHe 
              ? 'המסמכים הועברו לבדיקה מול רשויות המס. סטטוס החשבון יעודכן תוך 48 שעות.' 
              : 'Documents submitted for tax authority review. Account status will be updated within 48 hours.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); }, 
            child: Text(isHe ? 'הבנתי' : 'Got it')
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isHe = locale == 'he';

    return Directionality(
      textDirection: isHe ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(isHe ? 'אימות זהות ועסק' : 'Identity & Business Verification'),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isUploading 
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("מעלה מסמכים ומאמת...", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStepHeader(1, isHe ? 'פרטי העסק והרישום' : 'Business & Registration Details'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: _inputStyle(isHe ? 'שם העסק הרשום' : 'Registered Business Name', Icons.business),
                      validator: (v) => v!.isEmpty ? (isHe ? 'חובה' : 'Required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _idController,
                      decoration: _inputStyle(isHe ? 'מספר עוסק / ח.פ / ת.ז' : 'Business ID / VAT ID', Icons.badge_outlined),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? (isHe ? 'חובה' : 'Required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _taxBranchController,
                      decoration: _inputStyle(isHe ?'סניף מע"מ / מס הכנסה' : 'Tax Office Branch', Icons.account_balance_rounded),
                      validator: (v) => v!.isEmpty ? (isHe ? 'חובה' : 'Required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: _inputStyle(isHe ? 'כתובת העסק המלאה' : 'Business Address', Icons.location_on_outlined),
                      validator: (v) => v!.isEmpty ? (isHe ? 'חובה' : 'Required') : null,
                    ),
                    
                    const SizedBox(height: 24),
                    _buildStepHeader(2, isHe ? 'סיווג עוסק לצרכי מס' : 'Tax Dealer Classification'),
                    const SizedBox(height: 8),
                    Text(
                      isHe ? 'שים לב: הגדרה זו תקבע את סוגי המסמכים (חשבונית/קבלה) שתוכל להפיק.' : 'Note: This setting determines the document types (Invoice/Receipt) you can generate.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _dealerTypeCard('exempt', isHe ? 'עוסק פטור' : 'Exempt Dealer', Icons.money_off)),
                        const SizedBox(width: 12),
                        Expanded(child: _dealerTypeCard('licensed', isHe ? 'עוסק מורשה / חברה' : 'Licensed Dealer / Co.', Icons.payments_outlined)),
                      ],
                    ),

                    const SizedBox(height: 32),
                    _buildStepHeader(3, isHe ? 'העלאת מסמכים רשמיים' : 'Upload Legal Documents'),
                    const SizedBox(height: 16),
                    _buildUploadTile(
                      title: isHe ? 'צילום תעודת זהות (צד פנים)' : 'ID Card Photo',
                      image: _idCardImage,
                      onTap: () => _pickImage('id'),
                    ),
                    _buildUploadTile(
                      title: isHe ? 'תעודת עוסק פטור/מורשה' : 'Business Certificate',
                      image: _businessCertImage,
                      onTap: () => _pickImage('cert'),
                    ),
                    _buildUploadTile(
                      title: isHe ? 'פוליסת ביטוח אחריות מקצועית (אופציונלי)' : 'Professional Liability Insurance (Opt.)',
                      image: _insuranceImage,
                      onTap: () => _pickImage('insurance'),
                    ),

                    const SizedBox(height: 24),
                    _buildStepHeader(4, isHe ? 'אישורים והצהרות משפטיות' : 'Legal Confirmations'),
                    const SizedBox(height: 12),
                    _buildLegalCheckbox(
                      value: _acceptedTerms,
                      onChanged: (v) => setState(() => _acceptedTerms = v!),
                      label: isHe 
                        ? 'קראתי ואני מסכים לתנאי השימוש וכללי האתיקה של HireHub.'
                        : 'I have read and agree to the HireHub Terms of Use and Code of Ethics.',
                    ),
                    _buildLegalCheckbox(
                      value: _acceptedDataPrivacy,
                      onChanged: (v) => setState(() => _acceptedDataPrivacy = v!),
                      label: isHe 
                        ? 'אני מאשר ל-HireHub לשמור את מסמכיי לצורך תהליך האימות בלבד.'
                        : 'I authorize HireHub to store my documents for verification purposes only.',
                    ),
                    _buildLegalCheckbox(
                      value: _isLegalDeclarationSigned,
                      onChanged: (v) => setState(() => _isLegalDeclarationSigned = v!),
                      label: isHe 
                        ? 'אני מצהיר כי כל המידע והמסמכים שמסרתי נכונים, תקפים ומקוריים.'
                        : 'I declare that all information and documents provided are correct, valid, and original.',
                    ),

                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: _submitVerification, 
                      child: Text(isHe ? 'שלח לאישור משפטי' : 'Submit for Legal Review', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildStepHeader(int step, String title) {
    return Row(
      children: [
        CircleAvatar(radius: 12, backgroundColor: const Color(0xFF1976D2), child: Text(step.toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
      ],
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blueGrey, size: 20),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _dealerTypeCard(String type, String label, IconData icon) {
    bool isSelected = _dealerType == type;
    return InkWell(
      onTap: () => setState(() => _dealerType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1976D2).withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF1976D2) : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF1976D2) : Colors.grey, size: 28),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? const Color(0xFF1976D2) : Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTile({required String title, required File? image, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                image: image != null ? DecorationImage(image: FileImage(image), fit: BoxFit.cover) : null,
              ),
              child: image == null ? const Center(child: Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 30)) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCheckbox({required bool value, required ValueChanged<bool?> onChanged, required String label}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF1976D2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }
}
