import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/language_provider.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfilePage({super.key, required this.userData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  late TextEditingController _townController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name']);
    _bioController = TextEditingController(text: widget.userData['bio']);
    _phoneController = TextEditingController(text: widget.userData['phone']);
    _townController = TextEditingController(text: widget.userData['town']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _townController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final dbRef = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
      ).ref();

      await dbRef.child('users').child(user.uid).update({
        'name': _nameController.text.trim(),
        'description': _bioController.text.trim(),
        'phone': _phoneController.text.trim(),
        'town': _townController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, String> _getLocalizedStrings() {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'title': 'עריכת פרופיל',
          'name': 'שם מלא',
          'bio': 'תיאור',
          'phone': 'מספר טלפון',
          'town': 'עיר',
          'save': 'שמור שינויים',
        };
      case 'ar':
        return {
          'title': 'تعديل الملف الشخصي',
          'name': 'الاسم الكامل',
          'bio': 'الوصف',
          'phone': 'رقم الهاتف',
          'town': 'المدينة',
          'save': 'حفظ التغييرات',
        };
      default:
        return {
          'title': 'Edit Profile',
          'name': 'Full Name',
          'bio': 'Bio',
          'phone': 'Phone Number',
          'town': 'Town',
          'save': 'Save Changes',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings['title']!),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: strings['name']),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(labelText: strings['phone']),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _townController,
                      decoration: InputDecoration(labelText: strings['town']),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      decoration: InputDecoration(labelText: strings['bio']),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(strings['save']!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
