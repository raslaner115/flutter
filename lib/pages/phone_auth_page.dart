import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/language_provider.dart';
import '../main.dart';

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String _verificationId = "";
  bool _codeSent = false;
  bool _loading = false;

  Map<String, String> _getLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'title': 'אימות טלפוני',
          'phone_label': 'מספר טלפון',
          'phone_hint': 'הכנס את מספר הטלפון שלך',
          'send_code': 'שלח קוד',
          'code_label': 'קוד אימות',
          'code_hint': 'הכנס את הקוד שקיבלת',
          'verify': 'אמת והתחבר',
        };
      case 'am':
        return {
          'title': 'የስልክ ማረጋገጫ',
          'phone_label': 'የስልክ ቁጥር',
          'phone_hint': 'የስልክ ቁጥርዎን ያስገቡ',
          'send_code': 'ኮድ ላክ',
          'code_label': 'የማረጋገጫ ኮድ',
          'code_hint': 'የተቀበሉትን ኮድ ያስገቡ',
          'verify': 'አረጋግጥ እና ግባ',
        };
      default:
        return {
          'title': 'Phone Authentication',
          'phone_label': 'Phone Number',
          'phone_hint': 'Enter your phone number',
          'send_code': 'Send Code',
          'code_label': 'Verification Code',
          'code_hint': 'Enter the code you received',
          'verify': 'Verify & Sign In',
        };
    }
  }

  Future<void> _verifyPhone() async {
    setState(() => _loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneController.text.trim(),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyHomePage()));
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Verification Failed")));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _loading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _signInWithCode() async {
    setState(() => _loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _codeController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyHomePage()));
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Code")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final isRtl = Provider.of<LanguageProvider>(context).locale.languageCode == 'he' ||
        Provider.of<LanguageProvider>(context).locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(strings),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: !_codeSent
                          ? _buildPhoneInput(strings)
                          : _buildCodeInput(strings),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(Map<String, String> strings) {
    return Container(
      height: 250,
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
            const Icon(Icons.phone_android, size: 40, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              strings['title']!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInput(Map<String, String> strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        TextField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: strings['phone_label'],
            hintText: strings['phone_hint'],
            prefixIcon: const Icon(Icons.phone, color: Color(0xFF1976D2)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _verifyPhone,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(strings['send_code']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildCodeInput(Map<String, String> strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        TextField(
          controller: _codeController,
          decoration: InputDecoration(
            labelText: strings['code_label'],
            hintText: strings['code_hint'],
            prefixIcon: const Icon(Icons.sms, color: Color(0xFF1976D2)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _signInWithCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(strings['verify']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
