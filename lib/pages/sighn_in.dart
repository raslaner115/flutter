import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/language_provider.dart';
import 'package:untitled1/pages/sighn_up.dart';
import '../main.dart';

class SignInPage extends StatefulWidget {
  final String? initialEmail;
  const SignInPage({super.key, this.initialEmail});

  static Route route() {
    return MaterialPageRoute(builder: (_) => const SignInPage());
  }

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailCtrl;
  late TextEditingController _passwordCtrl;
  bool _loading = false;
  bool _obscure = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
  ).ref();

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _getLocalizedStrings(BuildContext context, {bool listen = true}) {
    final locale = Provider.of<LanguageProvider>(context, listen: listen).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'welcome': 'ברוכים\nהבאים',
          'email': 'אימייל',
          'password': 'סיסמה',
          'forgot': 'שכחת סיסמה?',
          'signin': 'התחברות',
          'no_account': 'אין לך חשבון? ',
          'signup': 'הרשמה',
          'email_required': 'אימייל שדה חובה',
          'valid_email': 'הכנס אימייל תקין',
          'pass_required': 'סיסמה שדה חובה',
          'success': 'התחברת בהצלחה',
        };
      case 'ar':
        return {
          'welcome': 'أهلاً\nبكم',
          'email': 'البريد الإلكتروني',
          'password': 'كلمة المرور',
          'forgot': 'نسيت كلمة المرور؟',
          'signin': 'تسجيل الدخول',
          'no_account': 'ليس لديك حساب؟ ',
          'signup': 'إنشاء حساب',
          'email_required': 'البريد الإلكتروني مطلوب',
          'valid_email': 'أدخل بريداً إلكترونياً صالحاً',
          'pass_required': 'كلمة المرور مطلوبة',
          'success': 'تم تسجيل الدخول بنجاح',
        };
      case 'ru':
        return {
          'welcome': 'С\nвозвращением',
          'email': 'Email',
          'password': 'Пароль',
          'forgot': 'Забыли пароль?',
          'signin': 'Войти',
          'no_account': 'Нет аккаунта? ',
          'signup': 'Регистрация',
          'email_required': 'Введите Email',
          'valid_email': 'Введите корректный Email',
          'pass_required': 'Введите пароль',
          'success': 'Успешный вход',
        };
      case 'am':
        return {
          'welcome': 'እንኳን\nደህና መጡ',
          'email': 'ኢሜይል',
          'password': 'የይለፍ ቃል',
          'forgot': 'የይለፍ ቃል ረስተዋል?',
          'signin': 'ግባ',
          'no_account': 'አካውንት የለዎትም? ',
          'signup': 'ይመዝገቡ',
          'email_required': 'ኢሜይል ያስፈልጋል',
          'valid_email': 'ትክክለኛ ኢሜይል ያስገቡ',
          'pass_required': 'የይለፍ ቃል ያስፈልጋል',
          'success': 'በተሳካ ሁኔታ ገብተዋል',
        };
      default:
        return {
          'welcome': 'Welcome\nBack',
          'email': 'Email',
          'password': 'Password',
          'forgot': 'Forgot Password?',
          'signin': 'Sign In',
          'no_account': "Don't have an account? ",
          'signup': 'Sign Up',
          'email_required': 'Email is required',
          'valid_email': 'Enter a valid email',
          'pass_required': 'Password is required',
          'success': 'Signed in successfully',
        };
    }
  }

  Future<void> _submit() async {
    final strings = _getLocalizedStrings(context, listen: false);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (userCredential.user != null) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings['success']!)),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MyHomePage()),
        );

        _dbRef.child('users').child(userCredential.user!.uid).get().then((snapshot) {
           debugPrint('User data loaded in background');
        }).catchError((e) {
           debugPrint('Background data fetch error: $e');
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication failed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final localeCode = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isRtl = localeCode == 'he' || localeCode == 'ar';
    
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
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
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(80),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.handyman_rounded, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        strings['welcome']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: strings['email'],
                          hintText: 'name@example.com',
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1976D2)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return strings['email_required'];
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                            return strings['valid_email'];
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: strings['password'],
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1976D2)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? strings['pass_required'] : null,
                      ),
                      
                      Align(
                        alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            strings['forgot']!,
                            style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                          child: _loading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : Text(strings['signin']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(strings['no_account']!, style: const TextStyle(color: Color(0xFF64748B))),
                          GestureDetector(
                            onTap: _loading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpPage())),
                            child: Text(
                              strings['signup']!,
                              style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
