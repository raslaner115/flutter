import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:untitled1/pages/subscription.dart';

class CompleteWorkerProfilePage extends StatefulWidget {
  const CompleteWorkerProfilePage({Key? key}) : super(key: key);

  @override
  State<CompleteWorkerProfilePage> createState() => _CompleteWorkerProfilePageState();
}

class _CompleteWorkerProfilePageState extends State<CompleteWorkerProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _optionalPhoneController = TextEditingController();

  List<String> _selectedProfessions = [];
  bool _isLoading = false;
  File? _image;
  final ImagePicker _picker = ImagePicker();

  final List<String> _professions = [
    'Plumber', 'Carpenter', 'Electrician', 'Painter', 'Cleaner', 'Handyman', 'Landscaper', 'HVAC'
  ];

  @override
  void dispose() {
    _idController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _optionalPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProfessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one profession')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Map<String, dynamic> workerData = {
      'userType': 'worker',
      'phone': _phoneController.text.trim(),
      'optionalPhone': _optionalPhoneController.text.trim(),
      'idNumber': _idController.text.trim(),
      'description': _descriptionController.text.trim(),
      'professions': _selectedProfessions,
      'upgradedAt': ServerValue.timestamp,
    };

    // Instead of saving, go to subscription page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionPage(
          email: user.email ?? "",
          pendingUserData: workerData,
          pendingImage: _image,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Worker Profile'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Please provide your professional details. Your profile will be created after subscription payment.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _image != null ? FileImage(_image!) : null,
                        child: _image == null
                            ? const Icon(Icons.person, size: 60, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Color(0xFF1976D2), shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildMultiProfessionsDropdown(),
              const SizedBox(height: 16),
              _buildTextField(_phoneController, 'Worker Phone Number', Icons.phone),
              const SizedBox(height: 16),
              _buildTextField(_optionalPhoneController, 'Alternative Phone Number', Icons.phone_android, isRequired: false),
              const SizedBox(height: 16),
              _buildTextField(_idController, 'ID Number', Icons.badge),
              const SizedBox(height: 16),
              _buildTextField(_descriptionController, 'Description', Icons.description, maxLines: 3),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Proceed to Payment', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: isRequired ? label : '$label (Optional)',
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) => isRequired && (value?.isEmpty ?? true) ? 'Required' : null,
    );
  }

  Widget _buildMultiProfessionsDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormField<List<String>>(
          initialValue: _selectedProfessions,
          validator: (value) => _selectedProfessions.isEmpty ? 'Select at least one profession' : null,
          builder: (state) {
            return InputDecorator(
              decoration: InputDecoration(
                labelText: 'Select your professions',
                prefixIcon: const Icon(Icons.work),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                errorText: state.errorText,
              ),
              child: Column(
                children: [
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Choose professions'),
                    underline: Container(),
                    items: _professions.map((p) {
                      return DropdownMenuItem<String>(
                        value: p,
                        child: CheckboxListTile(
                          title: Text(p),
                          value: _selectedProfessions.contains(p),
                          onChanged: (bool? checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedProfessions.add(p);
                              } else {
                                _selectedProfessions.remove(p);
                              }
                            });
                            state.didChange(_selectedProfessions);
                          },
                        ),
                      );
                    }).toList(),
                    onChanged: (_) {},
                  ),
                  if (_selectedProfessions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8.0,
                        children: _selectedProfessions.map((p) => Chip(
                          label: Text(p),
                          onDeleted: () {
                            setState(() {
                              _selectedProfessions.remove(p);
                              state.didChange(_selectedProfessions);
                            });
                          },
                        )).toList(),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
