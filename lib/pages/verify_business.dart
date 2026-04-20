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

  final List<File> _idCardImages = [];
  File? _businessCertImage;
  File? _insuranceImage;
  final List<File> _latestInvoiceImages = [];

  String _dealerType = 'exempt'; // 'exempt' (פטור) or 'licensed' (מורשה)
  bool _isUploading = false;
  bool _isLoadingStatus = true;
  String? _currentStatus; // 'pending', 'verified', 'rejected', or null

  bool _acceptedTerms = false;
  bool _acceptedDataPrivacy = false;
  bool _isLegalDeclarationSigned = false;
  bool _acceptedResponsibility = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('verifications')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _currentStatus = doc.data()?['status'];
          });
        }
      } catch (e) {
        debugPrint("Status check error: $e");
      }
    }
    if (mounted) setState(() => _isLoadingStatus = false);
  }

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
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (picked != null) {
        setState(() {
          if (type == 'cert') _businessCertImage = File(picked.path);
          if (type == 'insurance') _insuranceImage = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint("Pick error: $e");
    }
  }

  Future<void> _pickIdCardImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 70);
      if (picked.isNotEmpty) {
        setState(() {
          _idCardImages
            ..clear()
            ..addAll(picked.take(2).map((file) => File(file.path)));
        });
      }
    } catch (e) {
      debugPrint("Pick ID images error: $e");
    }
  }

  Future<void> _pickLatestInvoices() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 70);
      if (picked.isNotEmpty) {
        setState(() {
          _latestInvoiceImages
            ..clear()
            ..addAll(picked.take(5).map((file) => File(file.path)));
        });
      }
    } catch (e) {
      debugPrint("Pick invoices error: $e");
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
    final isHe =
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).locale.languageCode ==
        'he';

    if (!_formKey.currentState!.validate()) return;

    if (_idCardImages.length != 2 || _businessCertImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHe
                ? 'אנא העלה 2 תמונות תעודת זהות ואישור עוסק'
                : 'Please upload 2 ID photos and Business Certificate',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_latestInvoiceImages.length < 2 || _latestInvoiceImages.length > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHe
                ? 'יש להעלות בין 2 ל-5 חשבוניות אחרונות'
                : 'Please upload between 2 and 5 latest invoices',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!_acceptedTerms ||
        !_acceptedDataPrivacy ||
        !_isLegalDeclarationSigned ||
        !_acceptedResponsibility) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHe
                ? 'עליך לאשר את כל הצהרות החוקיות'
                : 'You must accept all legal declarations',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Sequential uploads to avoid storage task state warnings
      final idCardUrls = <String>[];
      for (var i = 0; i < _idCardImages.length; i++) {
        idCardUrls.add(
          await _uploadToStorage(
            _idCardImages[i],
            'verifications/${user.uid}/id_card_$i.jpg',
          ),
        );
      }
      final certUrl = await _uploadToStorage(
        _businessCertImage!,
        'verifications/${user.uid}/business_cert.jpg',
      );

      String? insuranceUrl;
      if (_insuranceImage != null) {
        insuranceUrl = await _uploadToStorage(
          _insuranceImage!,
          'verifications/${user.uid}/insurance.jpg',
        );
      }

      final latestInvoiceUrls = <String>[];
      for (var i = 0; i < _latestInvoiceImages.length; i++) {
        latestInvoiceUrls.add(
          await _uploadToStorage(
            _latestInvoiceImages[i],
            'verifications/${user.uid}/latest_invoice_$i.jpg',
          ),
        );
      }

      final businessId = _idController.text.trim();
      final verificationData = {
        'userId': user.uid,
        'businessId': businessId,
        'businessName': _businessNameController.text.trim(),
        'address': _addressController.text.trim(),
        'taxBranch': _taxBranchController.text.trim(),
        'dealerType': _dealerType,
        'idCardUrl': idCardUrls.first,
        'idCardUrls': idCardUrls,
        'idCardCount': idCardUrls.length,
        'businessCertUrl': certUrl,
        'insuranceUrl': insuranceUrl,
        'latestInvoiceUrls': latestInvoiceUrls,
        'latestInvoiceCount': latestInvoiceUrls.length,
        'hasInsurance': _insuranceImage != null,
        'status': 'pending',
        'legalAccepted': true,
        'responsibilityAccepted': true,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Save to verifications collection
      await FirebaseFirestore.instance
          .collection('verifications')
          .doc(user.uid)
          .set(verificationData);

      // Update user document in unified 'users' collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'dealerType': _dealerType,
            'businessId': businessId,
            'businessVerificationStatus': 'pending',
          });

      if (mounted) {
        _showSuccessDialog(isHe);
      }
    } catch (e) {
      debugPrint("Verification submit error: $e");
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
            Text(
              isHe ? 'הבקשה הוגשה בהצלחה' : 'Request Submitted!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              isHe
                  ? 'המסמכים הועברו לבדיקה מול רשויות המס. סטטוס החשבון יעודכן תוך 48 שעות.'
                  : 'Documents submitted for tax authority review. Account status will be updated within 48 hours.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(isHe ? 'הבנתי' : 'Got it'),
          ),
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
          title: Text(
            isHe ? 'אימות זהות ועסק' : 'Identity & Business Verification',
          ),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoadingStatus
            ? const Center(child: CircularProgressIndicator())
            : _isUploading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      "מעלה מסמכים ומאמת...",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : _currentStatus == 'pending' || _currentStatus == 'verified'
            ? _buildStatusScreen(isHe)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_currentStatus == 'rejected')
                        _buildRejectedNotice(isHe),
                      _buildStepHeader(
                        1,
                        isHe
                            ? 'פרטי העסק והרישום'
                            : 'Business & Registration Details',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _businessNameController,
                        decoration: _inputStyle(
                          isHe ? 'שם העסק הרשום' : 'Registered Business Name',
                          Icons.business,
                        ),
                        validator: (v) =>
                            v!.isEmpty ? (isHe ? 'חובה' : 'Required') : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _idController,
                        decoration: _inputStyle(
                          isHe
                              ? 'מספר עוסק / ח.פ / ת.ז'
                              : 'Business ID / VAT ID',
                          Icons.badge_outlined,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v!.isEmpty ? (isHe ? 'חובה' : 'Required') : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _taxBranchController,
                        decoration: _inputStyle(
                          isHe ? 'סניף מע"מ / מס הכנסה' : 'Tax Office Branch',
                          Icons.account_balance_rounded,
                        ),
                        validator: (v) =>
                            v!.isEmpty ? (isHe ? 'חובה' : 'Required') : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: _inputStyle(
                          isHe ? 'כתובת העסק המלאה' : 'Business Address',
                          Icons.location_on_outlined,
                        ),
                        validator: (v) =>
                            v!.isEmpty ? (isHe ? 'חובה' : 'Required') : null,
                      ),

                      const SizedBox(height: 24),
                      _buildStepHeader(
                        2,
                        isHe
                            ? 'סיווג עוסק לצרכי מס'
                            : 'Tax Dealer Classification',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isHe
                            ? 'שים לב: הגדרה זו תקבע את סוגי המסמכים (חשבונית/קבלה) שתוכל להפיק.'
                            : 'Note: This setting determines the document types (Invoice/Receipt) you can generate.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _dealerTypeCard(
                              'exempt',
                              isHe ? 'עוסק פטור' : 'Exempt Dealer',
                              Icons.money_off,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dealerTypeCard(
                              'licensed',
                              isHe
                                  ? 'עוסק מורשה / חברה'
                                  : 'Licensed Dealer / Co.',
                              Icons.payments_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                      _buildStepHeader(
                        3,
                        isHe ? 'העלאת מסמכים רשמיים' : 'Upload Legal Documents',
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHe
                                  ? 'צילום תעודת זהות - חובה 2 תמונות'
                                  : 'ID Card Photos - exactly 2 required',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isHe
                                  ? 'העלה בדיוק 2 תמונות ברורות של תעודת הזהות. מומלץ חזית + מסמך נוסף ברור, ללא חיתוך וללא טשטוש.'
                                  : 'Upload exactly 2 clear ID photos. Prefer front side plus another clear supporting ID image, with no crop or blur.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _pickIdCardImages,
                              icon: const Icon(Icons.badge_outlined),
                              label: Text(
                                isHe ? 'בחר 2 תמונות' : 'Choose 2 Photos',
                              ),
                            ),
                            if (_idCardImages.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 110,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _idCardImages.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final file = _idCardImages[index];
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Image.file(
                                            file,
                                            width: 120,
                                            height: 110,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: CircleAvatar(
                                            radius: 14,
                                            backgroundColor: Colors.black
                                                .withValues(alpha: 0.55),
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              iconSize: 16,
                                              icon: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                              ),
                                              onPressed: () {
                                                setState(
                                                  () => _idCardImages.removeAt(
                                                    index,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildUploadTile(
                        title: isHe
                            ? 'תעודת עוסק פטור/מורשה'
                            : 'Business Certificate',
                        image: _businessCertImage,
                        onTap: () => _pickImage('cert'),
                      ),
                      _buildUploadTile(
                        title: isHe
                            ? 'פוליסת ביטוח אחריות מקצועית (אופציונלי)'
                            : 'Professional Liability Insurance (Opt.)',
                        image: _insuranceImage,
                        onTap: () => _pickImage('insurance'),
                      ),

                      const SizedBox(height: 24),
                      _buildStepHeader(
                        4,
                        isHe ? '2-5 חשבוניות אחרונות' : '2-5 Latest Invoices',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F8FC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD7E3F4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHe
                                  ? 'יש להעלות לפחות 2 חשבוניות אחרונות ולא יותר מ-5.'
                                  : 'Upload at least 2 and no more than 5 recent invoices.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isHe
                                  ? 'החשבוניות חייבות להיות במספרים עוקבים ולייצג את החשבוניות האחרונות שהפקת.'
                                  : 'The invoices must be consecutive numbers and must represent the most recent invoices you issued.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isHe
                                  ? 'דוגמה: אם החשבונית האחרונה שלך היא 105, אפשר להעלות 104-105 או 101,102,103,104,105. לא ניתן להעלות 98, 101, 105.'
                                  : 'Example: if your latest invoice is 105, you can upload 104-105 or 101,102,103,104,105. Do not upload 98, 101, 105.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isHe
                                  ? 'ודא שהמספר, התאריך, שם העסק והסכום נראים בבירור. העלאה של מסמכים חסרים, חתוכים, כפולים או לא קריאים עלולה לעכב או לדחות את האימות.'
                                  : 'Make sure the invoice number, date, business name, and amount are clearly visible. Missing, cropped, duplicate, or unreadable files may delay or reject verification.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickLatestInvoices,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: Text(isHe ? 'בחר חשבוניות' : 'Choose Invoices'),
                      ),
                      if (_latestInvoiceImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _latestInvoiceImages.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final file = _latestInvoiceImages[index];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      file,
                                      width: 120,
                                      height: 110,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.black.withValues(
                                        alpha: 0.55,
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        iconSize: 16,
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          setState(
                                            () => _latestInvoiceImages.removeAt(
                                              index,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      _buildStepHeader(
                        5,
                        isHe
                            ? 'אישורים והצהרות משפטיות'
                            : 'Legal Confirmations',
                      ),
                      const SizedBox(height: 12),
                      _buildLegalCheckbox(
                        value: _acceptedTerms,
                        onChanged: (v) => setState(() => _acceptedTerms = v!),
                        label: isHe
                            ? 'קראתי ואני מסכים לתנאי השימוש וכללי האתיקה של הירו.'
                            : 'I have read and agree to the hiro Terms of Use and Code of Ethics.',
                      ),
                      _buildLegalCheckbox(
                        value: _acceptedDataPrivacy,
                        onChanged: (v) =>
                            setState(() => _acceptedDataPrivacy = v!),
                        label: isHe
                            ? 'אני מאשר ל-הירו לשמור את מסמכיי לצורך תהליך האימות בלבד.'
                            : 'I authorize hiro to store my documents for verification purposes only.',
                      ),
                      _buildLegalCheckbox(
                        value: _isLegalDeclarationSigned,
                        onChanged: (v) =>
                            setState(() => _isLegalDeclarationSigned = v!),
                        label: isHe
                            ? 'אני מצהיר כי כל המידע והמסמכים שמסרתי נכונים, תקפים ומקוריים.'
                            : 'I declare that all information and documents provided are correct, valid, and original.',
                      ),
                      _buildLegalCheckbox(
                        value: _acceptedResponsibility,
                        onChanged: (v) =>
                            setState(() => _acceptedResponsibility = v!),
                        label: isHe
                            ? 'אני אחראי לכל מידע שגוי או מטעה שאמסור לכם.'
                            : 'I am responsible for any wrong or misleading information I provide.',
                      ),

                      const SizedBox(height: 40),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        onPressed: _submitVerification,
                        child: Text(
                          isHe ? 'שלח לאישור משפטי' : 'Submit for Legal Review',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusScreen(bool isHe) {
    bool isPending = _currentStatus == 'pending';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending
                  ? Icons.hourglass_bottom_rounded
                  : Icons.verified_rounded,
              size: 80,
              color: isPending ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 24),
            Text(
              isPending
                  ? (isHe ? 'הבקשה בבדיקה' : 'Verification Pending')
                  : (isHe ? 'העסק מאומת' : 'Business Verified'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              isPending
                  ? (isHe
                        ? 'שלחת כבר בקשת אימות. הצוות שלנו בודק את המסמכים שלך. בדרך כלל זה לוקח עד 48 שעות.'
                        : 'You have already submitted a verification request. Our team is reviewing your documents. This usually takes up to 48 hours.')
                  : (isHe
                        ? 'מזל טוב! העסק שלך מאומת במערכת.'
                        : 'Congratulations! Your business is verified in our system.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(isHe ? 'חזור לפרופיל' : 'Back to Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedNotice(bool isHe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isHe
                  ? 'בקשת האימות הקודמת שלך נדחתה. אנא בדוק את המסמכים ושלח שוב.'
                  : 'Your previous verification request was rejected. Please check your documents and resubmit.',
              style: TextStyle(
                color: Colors.red[900],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(int step, String title) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFF1976D2),
          child: Text(
            step.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blueGrey, size: 20),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
      ),
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
          color: isSelected
              ? const Color(0xFF1976D2).withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1976D2)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1976D2) : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? const Color(0xFF1976D2) : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTile({
    required String title,
    required File? image,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
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
                image: image != null
                    ? DecorationImage(
                        image: FileImage(image),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: image == null
                  ? const Center(
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        color: Colors.grey,
                        size: 30,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
  }) {
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }
}
