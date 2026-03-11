import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/language_provider.dart';
import 'package:untitled1/pages/subscription.dart';
import '../main.dart';

class SignUpPage extends StatefulWidget {
  final Map<String, dynamic>? pendingWorkerData;
  final File? pendingWorkerImage;
  final int startAtStep;

  const SignUpPage({
    super.key,
    this.pendingWorkerData,
    this.pendingWorkerImage,
    this.startAtStep = 0,
  });

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

enum SignUpStep { profile, phone }
enum UserType { normal, worker }

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  late SignUpStep _currentStep;
  late UserType _userType;
  String? _selectedTown;
  bool _loading = false;
  bool _agreedToPolicy = false;
  bool _codeSent = false;
  String _verificationId = "";
  File? _image;
  final ImagePicker _picker = ImagePicker();

  List<String> _selectedProfessions = [];

  final List<String> _israeliTowns = [
    'Jerusalem', 'Tel Aviv', 'Haifa', 'Rishon LeZion', 'Petah Tikva', 'Ashdod',
    'Netanya', 'Beersheba', 'Holon', 'Bnei Brak', 'Ramat Gan', 'Rehovot',
  ];

  final List<String> _allProfessions = [
    'Plumber', 'Carpenter', 'Electrician', 'Painter', 'Cleaner', 'Handyman',
    'Landscaper', 'HVAC', 'Locksmith', 'Gardener', 'Mechanic', 'Photographer',
    'Tutor', 'Tailor', 'Mover', 'Interior Designer', 'Beautician', 'Pet Groomer'
  ];

  @override
  void initState() {
    super.initState();
    _currentStep = widget.startAtStep == 1 ? SignUpStep.phone : SignUpStep.profile;
    _image = widget.pendingWorkerImage;
    
    if (widget.pendingWorkerData != null) {
      _userType = UserType.worker;
      _nameController.text = widget.pendingWorkerData!['name'] ?? "";
      _emailController.text = widget.pendingWorkerData!['email'] ?? "";
      _selectedTown = widget.pendingWorkerData!['town'];
      _selectedProfessions = List<String>.from(widget.pendingWorkerData!['professions'] ?? []);
      _altPhoneController.text = widget.pendingWorkerData!['optionalPhone'] ?? "";
      _descriptionController.text = widget.pendingWorkerData!['description'] ?? "";
      _agreedToPolicy = true; // Assumed since they reached payment
    } else {
      _userType = UserType.normal;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _altPhoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Map<String, String> _getLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'title': 'הרשמה',
          'phone_label': 'מספר טלפון',
          'phone_subtitle': 'הכנס את מספר הטלפון שלך לאימות וסיום',
          'send_code': 'שלח קוד אימות',
          'verify_code': 'אמת וסיים הרשמה',
          'enter_code': 'הכנס קוד שקיבלת ב-SMS',
          'name_label': 'שם מלא',
          'email_label': 'אימייל (אופציונלי)',
          'town_label': 'בחר עיר',
          'user_type': 'סוג חשבון',
          'normal': 'משתמש רגיל',
          'pro': 'בעל מקצוע',
          'professions': 'בחר מקצועות',
          'alt_phone': 'טלפון נוסף (אופציונלי)',
          'desc_label': 'ספר על עצמך (אופציונלי)',
          'policy': 'אני מסכים לתנאי השימוש והמדיניות',
          'finish': 'המשך לאימות טלפון',
          'pay': 'המשך לתשלום מנוי',
          'req': 'שדה חובה',
          'policy_err': 'עליך להסכים לתנאי השימוש',
          'invalid_phone': 'אנא הכנס מספר טלפון ישראלי תקין (05XXXXXXXX)',
          'error_verify': 'שגיאה באימות הקוד',
        };
      default:
        return {
          'title': 'Sign Up',
          'phone_label': 'Phone Number',
          'phone_subtitle': 'Enter your phone number to verify and complete',
          'send_code': 'Send Verification Code',
          'verify_code': 'Verify & Complete',
          'enter_code': 'Enter SMS Code',
          'name_label': 'Full Name',
          'email_label': 'Email (Optional)',
          'town_label': 'Select Town',
          'user_type': 'User Type',
          'normal': 'Normal User',
          'pro': 'Professional',
          'professions': 'Select Professions',
          'alt_phone': 'Alt Phone (Optional)',
          'desc_label': 'Description (Optional)',
          'policy': 'I agree to the Terms and Policy',
          'finish': 'Continue to Phone Verification',
          'pay': 'Proceed to Subscription',
          'req': 'Required',
          'policy_err': 'You must agree to the policy',
          'invalid_phone': 'Please enter a valid Israeli phone number (05XXXXXXXX)',
          'error_verify': 'Error verifying code',
        };
    }
  }

  String _normalizePhone(String input) {
    String digits = input.replaceAll(RegExp(r'\D'), ''); 
    if (digits.startsWith('972')) {
      digits = digits.substring(3);
    }
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+972$digits';
  }

  Future<void> _handleSendCode() async {
    final strings = _getLocalizedStrings(context);
    String input = _phoneController.text.trim();
    if (input.isEmpty) return;

    String phone = _normalizePhone(input);
    final regExp = RegExp(r'^\+9725\d{8}$');
    
    if (!regExp.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings['invalid_phone']!)));
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          await _commitUserDataToDatabase();
        },
        verificationFailed: (e) {
          if (mounted) {
            setState(() => _loading = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Verification failed")));
          }
        },
        codeSent: (verificationId, resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _codeSent = true;
              _loading = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _handleVerifyCode() async {
    final strings = _getLocalizedStrings(context);
    if (_codeController.text.trim().isEmpty) return;

    setState(() => _loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _codeController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await _commitUserDataToDatabase();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings['error_verify']!)));
      }
    }
  }

  Future<void> _commitUserDataToDatabase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final dbRef = FirebaseDatabase.instanceFor(
          app: FirebaseAuth.instance.app,
          databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
      ).ref();

      String imageUrl = "";
      if (_image != null) {
        final ref = FirebaseStorage.instance.ref().child('profile_pictures/${user.uid}.jpg');
        await ref.putFile(_image!);
        imageUrl = await ref.getDownloadURL();
      }

      final userData = {
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _normalizePhone(_phoneController.text.trim()),
        'town': _selectedTown,
        'userType': _userType == UserType.worker ? 'worker' : 'normal',
        'profileImageUrl': imageUrl,
        'createdAt': ServerValue.timestamp,
        'isAnonymous': user.isAnonymous,
      };

      if (_userType == UserType.worker) {
        userData.addAll({
          'professions': _selectedProfessions,
          'optionalPhone': _altPhoneController.text.trim(),
          'description': _descriptionController.text.trim(),
          'isSubscribed': true,
          'isPro': true,
          'subscriptionDate': ServerValue.timestamp,
        });
      }

      await dbRef.child('users').child(user.uid).set(userData);
      
      if (_userType == UserType.worker) {
        await dbRef.child('totalUsers').set(ServerValue.increment(1));
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MyHomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  void _submitProfile() {
    if (!_formKey.currentState!.validate()) return;
    final strings = _getLocalizedStrings(context);
    if (!_agreedToPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings['policy_err']!)));
      return;
    }

    if (_userType == UserType.worker) {
      final workerPendingData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'town': _selectedTown,
        'userType': 'worker',
        'professions': _selectedProfessions,
        'optionalPhone': _altPhoneController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubscriptionPage(
            email: _emailController.text.trim(),
            pendingUserData: workerPendingData,
            pendingImage: _image,
            isNewRegistration: true,
          ),
        ),
      );
    } else {
      setState(() => _currentStep = SignUpStep.phone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isRtl = locale == 'he' || locale == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    final strings = _getLocalizedStrings(context);
    return SingleChildScrollView(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentStep == SignUpStep.profile 
            ? _buildProfileStep(strings) 
            : _buildPhoneStep(strings),
      ),
    );
  }

  Widget _buildPhoneStep(Map<String, String> strings) {
    return Column(
      key: const ValueKey('phone'),
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(80)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.pendingWorkerData == null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => setState(() => _currentStep = SignUpStep.profile),
                  ),
                const Icon(Icons.phone_android_rounded, size: 50, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  strings['phone_label']!,
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings['phone_subtitle']!,
                style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 40),
              _buildStyledTextField(
                controller: _phoneController,
                labelText: strings['phone_label']!,
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                hintText: 'e.g. 0501234567',
                enabled: !_codeSent,
              ),
              if (_codeSent) ...[
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _codeController,
                  labelText: strings['enter_code']!,
                  icon: Icons.lock_outline_rounded,
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_codeSent ? _handleVerifyCode : _handleSendCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_codeSent ? strings['verify_code']! : strings['send_code']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 22),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStep(Map<String, String> strings) {
    return Column(
      key: const ValueKey('profile'),
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF1976D2)]),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(80)),
          ),
          child: Center(
            child: Text(
              strings['title']!,
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFFF1F5F9),
                    backgroundImage: _image != null ? FileImage(_image!) : null,
                    child: _image == null
                        ? Icon(Icons.person_rounded, size: 60, color: Colors.grey[400])
                        : null,
                  ),
                ),
                const SizedBox(height: 32),
                _buildStyledTextField(
                  controller: _nameController,
                  labelText: strings['name_label']!,
                  icon: Icons.person_outline,
                  validator: (v) => v!.isEmpty ? strings['req'] : null,
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _emailController,
                  labelText: strings['email_label']!,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedTown,
                  decoration: InputDecoration(
                    labelText: strings['town_label']!,
                    prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF1976D2)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  items: _israeliTowns.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _selectedTown = v),
                  validator: (v) => v == null ? strings['req'] : null,
                ),
                const SizedBox(height: 24),
                _buildTypeSelector(strings),

                if (_userType == UserType.worker) ...[
                  const SizedBox(height: 24),
                  _buildMultiSelectProfessions(strings),
                  const SizedBox(height: 16),
                  _buildStyledTextField(
                    controller: _altPhoneController,
                    labelText: strings['alt_phone']!,
                    icon: Icons.phone_android_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledTextField(
                    controller: _descriptionController,
                    labelText: strings['desc_label']!,
                    icon: Icons.description_outlined,
                    maxLines: 3,
                  ),
                ],

                const SizedBox(height: 24),
                Row(
                  children: [
                    Checkbox(
                      value: _agreedToPolicy,
                      onChanged: (v) => setState(() => _agreedToPolicy = v!),
                      activeColor: const Color(0xFF1976D2),
                    ),
                    Expanded(child: Text(strings['policy']!, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _submitProfile,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: Text(_userType == UserType.worker ? strings['pay']! : strings['finish']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectProfessions(Map<String, String> strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings['professions']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allProfessions.map((prof) {
            final isSelected = _selectedProfessions.contains(prof);
            return FilterChip(
              label: Text(prof, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedProfessions.add(prof);
                  } else {
                    _selectedProfessions.remove(prof);
                  }
                });
              },
              selectedColor: const Color(0xFF1976D2),
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTypeSelector(Map<String, String> strings) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _buildTypeButton(strings['normal']!, UserType.normal)),
          Expanded(child: _buildTypeButton(strings['pro']!, UserType.worker)),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, UserType type) {
    final isSelected = _userType == type;
    return GestureDetector(
      onTap: () => setState(() => _userType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1976D2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    String? hintText,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF1976D2)),
        filled: true,
        fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFE2E8F0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}
