import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/services/language_provider.dart';

class AddReviewPage extends StatefulWidget {
  final String targetUserId;
  final String targetCollection;
  final List<String> professions;
  final Map<String, dynamic>? existingReview;

  const AddReviewPage({
    super.key,
    required this.targetUserId,
    required this.targetCollection,
    required this.professions,
    this.existingReview,
  });

  @override
  State<AddReviewPage> createState() => _AddReviewPageState();
}

class _AddReviewPageState extends State<AddReviewPage> {
  final _commentController = TextEditingController();
  String? _selectedProfession;
  double _priceRating = 5.0;
  double _workRating = 5.0;
  double _professionalismRating = 5.0;
  
  final List<File> _newImages = [];
  List<String> _existingImageUrls = [];
  bool _isUploading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.existingReview != null) {
      _commentController.text = widget.existingReview!['comment'] ?? '';
      _priceRating = (widget.existingReview!['priceRating'] ?? 5.0).toDouble();
      _workRating = (widget.existingReview!['workRating'] ?? 5.0).toDouble();
      _professionalismRating = (widget.existingReview!['professionalismRating'] ?? 5.0).toDouble();
      _selectedProfession = widget.existingReview!['profession'];
      _existingImageUrls = List<String>.from(widget.existingReview!['imageUrls'] ?? []);
    } else if (widget.professions.isNotEmpty) {
      _selectedProfession = widget.professions.first;
    }
  }

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage(imageQuality: 60);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _newImages.addAll(pickedFiles.map((file) => File(file.path)));
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  Future<void> _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a comment')));
       return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      List<String> finalImageUrls = List.from(_existingImageUrls);

      // 1. Upload New Images to Storage
      for (var i = 0; i < _newImages.length; i++) {
        final fileName = 'review_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('reviews')
            .child(widget.targetUserId)
            .child(fileName);
        
        await storageRef.putFile(_newImages[i]);
        final imageUrl = await storageRef.getDownloadURL();
        finalImageUrls.add(imageUrl);
      }

      // 2. Save to Firestore
      double overallRating = (_priceRating + _workRating + _professionalismRating) / 3;

      final reviewData = {
        'userId': user.uid,
        'userName': user.displayName ?? "Anonymous",
        'userProfileImage': user.photoURL,
        'profession': _selectedProfession,
        'rating': overallRating,
        'priceRating': _priceRating,
        'workRating': _workRating,
        'professionalismRating': _professionalismRating,
        'comment': _commentController.text.trim(),
        'imageUrls': finalImageUrls,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final reviewCollection = FirebaseFirestore.instance
            .collection(widget.targetCollection)
            .doc(widget.targetUserId)
            .collection('reviews');

      if (widget.existingReview != null) {
        // Update existing review using its ID
        await reviewCollection.doc(widget.existingReview!['id']).update(reviewData);
      } else {
        // Add new review using user UID as document ID to enforce 1 review per user
        await reviewCollection.doc(user.uid).set(reviewData);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Review upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Map<String, String> _getLocalizedStrings() {
    final locale = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    if (locale == 'he') {
      return {
        'title': widget.existingReview != null ? 'ערוך ביקורת' : 'כתוב ביקורת',
        'profession_label': 'בחר מקצוע:',
        'price_rating': 'דירוג מחיר',
        'work_rating': 'איכות העבודה',
        'professionalism': 'מקצועיות',
        'comment_hint': 'ספר לנו על החוויה שלך...',
        'add_images': 'הוסף תמונות',
        'submit': widget.existingReview != null ? 'עדכן ביקורת' : 'שלח ביקורת',
        'uploading': 'שולח ביקורת...',
      };
    }
    return {
      'title': widget.existingReview != null ? 'Edit Review' : 'Write a Review',
      'profession_label': 'Select Profession:',
      'price_rating': 'Price Rating',
      'work_rating': 'Work Quality',
      'professionalism': 'Professionalism',
      'comment_hint': 'Tell us about your experience...',
      'add_images': 'Add Images',
      'submit': widget.existingReview != null ? 'Update Review' : 'Submit Review',
      'uploading': 'Submitting review...',
    };
  }

  Widget _buildRatingStars(String label, double rating, Function(double) onRatingChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Row(
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: Colors.amber,
                size: 30,
              ),
              onPressed: () => onRatingChanged(index + 1.0),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings();
    final isRtl = Provider.of<LanguageProvider>(context).locale.languageCode == 'he';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings['title']!),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.professions.length > 1) ...[
                Text(strings['profession_label']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedProfession,
                  items: widget.professions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) => setState(() => _selectedProfession = val),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              _buildRatingStars(strings['price_rating']!, _priceRating, (val) => setState(() => _priceRating = val)),
              _buildRatingStars(strings['work_rating']!, _workRating, (val) => setState(() => _workRating = val)),
              _buildRatingStars(strings['professionalism']!, _professionalismRating, (val) => setState(() => _professionalismRating = val)),
              const SizedBox(height: 24),
              TextField(
                controller: _commentController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: strings['comment_hint'],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 24),
              Text(strings['add_images']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImageUrls.length + _newImages.length + 1,
                  itemBuilder: (context, index) {
                    if (index < _existingImageUrls.length) {
                      // Existing images
                      return Stack(
                        children: [
                          Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(_existingImageUrls[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeExistingImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    } else if (index < _existingImageUrls.length + _newImages.length) {
                      // New images
                      int newIdx = index - _existingImageUrls.length;
                      return Stack(
                        children: [
                          Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(_newImages[newIdx]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeNewImage(newIdx),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Add button
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isUploading ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isUploading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(strings['submit']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
