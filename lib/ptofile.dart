import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:untitled1/services/language_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:untitled1/pages/sighn_in.dart';
import 'package:untitled1/pages/schedule.dart';
import 'package:untitled1/pages/settings.dart';
import 'package:untitled1/pages/subscription.dart';
import 'package:untitled1/pages/invoice_builder.dart';
import 'package:untitled1/pages/verify_business.dart';
import 'package:untitled1/pages/chat_page.dart';
import 'package:untitled1/pages/analytics_page.dart';
import 'package:untitled1/pages/admin_panel.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class Profile extends StatefulWidget {
  final String? userId;
  const Profile({super.key, this.userId});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSubscription;

  String _userName = "";
  String _bio = "";
  String _phoneNumber = "";
  String _altPhoneNumber = "";
  String _email = "";
  String _town = "";
  String _profileImageUrl = "";
  String _userType = "";
  List<String> _userProfessions = [];
  List<Map<String, dynamic>> _userReviews = [];
  List<Map<String, dynamic>> _projects = [];
  bool _isFavorite = false;

  bool _isOwnProfile = false;
  bool _isLoading = true;

  bool _isIdVerified = false;
  bool _isBusinessVerified = false;
  bool _isInsured = false;

  String _distanceStr = "";
  double? _proLat;
  double? _proLng;

  final String _googleMapsApiKey = "AIzaSyCL9zie59-f_Hiyqj_dYtaMziReezcd6fU";

  @override
  void initState() {
    super.initState();
    _checkInitialOwnership();
    _initTabController();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && widget.userId == null) {
        _fetchUserData();
      }
    });

    _fetchUserData();
  }

  void _checkInitialOwnership() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final targetUid = widget.userId ?? currentUser?.uid;
    _isOwnProfile = (targetUid == null || (currentUser != null && targetUid == currentUser.uid));
  }

  void _initTabController() {
    // Admin has 2 tabs: System Overview, Actions
    // Professional has 4 tabs: About, Reviews, Schedule, Projects
    // Normal user has 2 tabs: About, Reviews
    int tabCount = _userType == 'admin' ? 2 : (_userType == 'worker' ? 4 : 2);
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  Future<void> _fetchUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final targetUid = widget.userId ?? currentUser?.uid;

    if (mounted) {
      setState(() {
        _isOwnProfile = (targetUid == null || (currentUser != null && targetUid == currentUser.uid));
        if (_userName.isEmpty) _isLoading = true;
      });
    }

    if (targetUid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(targetUid).get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;

        String oldType = _userType;
        setState(() {
          _userName = data['name']?.toString() ?? "";
          _bio = data['description']?.toString() ?? "";
          _phoneNumber = data['phone']?.toString() ?? "";
          _altPhoneNumber = data['optionalPhone']?.toString() ?? "";
          _email = data['email']?.toString() ?? "";
          _town = data['town']?.toString() ?? "";
          _profileImageUrl = data['profileImageUrl']?.toString() ?? "";

          if (data['isAdmin'] == true) {
            _userType = 'admin';
          } else if (data['isWorker'] == true) {
            _userType = 'worker';
          } else {
            _userType = 'normal';
          }

          if (data['professions'] is List) {
            _userProfessions = List<String>.from(data['professions']);
          } else if (data['profession'] != null) {
            _userProfessions = [data['profession'].toString()];
          } else {
            _userProfessions = [];
          }

          _isIdVerified = data['isIdVerified'] ?? false;
          _isBusinessVerified = data['isBusinessVerified'] ?? false;
          _isInsured = data['isInsured'] ?? false;

          _proLat = data['lat']?.toDouble();
          _proLng = data['lng']?.toDouble();
        });

        if (oldType != _userType) {
          _initTabController();
        }

        if (!_isOwnProfile) {
          _calculateDistance();
        }

        final reviews = await _fetchSubcollection(targetUid, 'reviews');
        final projects = await _fetchSubcollection(targetUid, 'projects');

        if (mounted) {
          setState(() {
            _userReviews = reviews;
            _projects = projects;
          });
        }

        if (currentUser != null && !_isOwnProfile) {
          final favDoc = await _firestore.collection('users').doc(currentUser.uid).collection('favorites').doc(targetUid).get();
          if (mounted) setState(() => _isFavorite = favDoc.exists);
        }

        if (!_isOwnProfile && targetUid != null) {
          _firestore.collection('users').doc(targetUid).update({
            'profileViews': FieldValue.increment(1)
          });
        }

        if (mounted) setState(() => _isLoading = false);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("FETCH ERROR: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateDistance() async {
    if (_proLat == null || _proLng == null) return;

    try {
      Position? userPos;
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          userPos = await Geolocator.getCurrentPosition();
        }
      }

      if (userPos != null) {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/distancematrix/json'
          '?origins=${userPos.latitude},${userPos.longitude}'
          '&destinations=$_proLat,$_proLng'
          '&key=$_googleMapsApiKey'
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' &&
              data['rows'].isNotEmpty &&
              data['rows'][0]['elements'].isNotEmpty &&
              data['rows'][0]['elements'][0]['status'] == 'OK') {

            final distanceText = data['rows'][0]['elements'][0]['distance']['text'];

            if (mounted) {
              setState(() {
                _distanceStr = distanceText;
              });
            }
          } else {
            _calculateStraightLineDistance(userPos);
          }
        } else {
          _calculateStraightLineDistance(userPos);
        }
      }
    } catch (e) {
      debugPrint("Distance calc error: $e");
    }
  }

  void _calculateStraightLineDistance(Position userPos) {
    double distance = Geolocator.distanceBetween(
      userPos.latitude, userPos.longitude, _proLat!, _proLng!
    );

    if (mounted) {
      setState(() {
        if (distance < 1000) {
          _distanceStr = "${distance.toStringAsFixed(0)}m";
        } else {
          _distanceStr = "${(distance / 1000).toStringAsFixed(1)}km";
        }
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final targetUid = widget.userId;
    if (currentUser == null || targetUid == null || _isGuest()) {
      _showGuestDialog(context, _getLocalizedStrings(context));
      return;
    }

    final favRef = _firestore.collection('users').doc(currentUser.uid).collection('favorites').doc(targetUid);

    try {
      if (_isFavorite) {
        await favRef.delete();
        if (mounted) setState(() => _isFavorite = false);
      } else {
        await favRef.set({
          'name': _userName,
          'profileImageUrl': _profileImageUrl,
          'professions': _userProfessions,
          'town': _town,
          'timestamp': FieldValue.serverTimestamp(),
        });
        if (mounted) setState(() => _isFavorite = true);
      }
    } catch (e) {
      debugPrint("FAVORITE TOGGLE ERROR: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSubcollection(String uid, String collectionName) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).collection(collectionName).get();
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint("Subcollection error ($collectionName): $e");
      return [];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  Map<String, String> _getLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'title': 'פרופיל',
          'user_name': _userName.isNotEmpty ? _userName : 'שם משתמש',
          'edit_profile': 'ערוך פרופיל',
          'share_profile': 'שתף פרופיל',
          'bio': _bio.isNotEmpty ? _bio : 'כאן יופיע התיאור האישי שלך...',
          'projects': 'פרויקט',
          'reviews': 'ביקורות',
          'about': 'אודות',
          'add_project': 'הוסף פרויקט',
          'call': 'התקשר',
          'message': 'הודעה',
          'contact_info': 'מידע ליצירת קשר',
          'no_reviews': 'אין עדיין ביקורות',
          'rating_title': 'דרג את העובד',
          'rating_hint': 'כתוב ביקורת...',
          'submit': 'שלח',
          'cancel': 'ביטול',
          'description': 'תיאור',
          'take_photo': 'צלם תמונה',
          'pick_gallery': 'בחר מהגלריה',
          'add': 'הוסף',
          'guest_msg': 'עליך להירשם כדי לבצע פעולה זו',
          'login': 'התחברות',
          'schedule': 'לו"ז',
          'price_guide': 'מחירון מומלץ',
          'report': 'דווח',
          'add_review': 'הוסף ביקורת',
          'edit_review': 'ערוך ביקורת',
          'report_success': 'הדיווח נשלח בהצלחה',
          'please_login': 'אנא התחבר כדי לצפות בפרופיל שלך',
          'upgrade_pro': 'שדרוג לבעל מקצוע',
          'error': 'שגיאה בהעלאה',
          'comments': 'תגובות',
          'add_comment': 'הוסף תגובה...',
          'write_on_image': 'כתוב על התמונה (אופציונלי)',
          'delete_project': 'מחיקת פרויקט',
          'confirm_delete': 'האם אתה בטוח שברצונך למחוק פרויקט זה?',
          'delete': 'מחק',
          'settings': 'הגדרות',
          'create_invoice': 'הפק הצעת מחיר / קבלה',
          'verify_business': 'אימות תיק עוסק',
          'analytics_title': 'לוח בקרה למקצוען',
          'total_jobs': 'עבודות שהושלמו',
          'monthly_views': 'צפיות החודש',
          'total_earnings': 'סה"כ הכנסות',
          'id_verified': 'זהות אומתה',
          'business_verified': 'עוסק מאומת',
          'insured': 'מבוטח',
          'analytics': 'ניתוח מקצועי',
          'distance': 'מרחק ממך',
          'price': 'מחיר',
          'service': 'שירות',
          'timing': 'עמידה בזמנים',
          'choose_profession': 'בחר מקצוע',
          'admin_panel': 'פאנל מנהל',
          'sys_overview': 'סקירת מערכת',
          'admin_actions': 'פעולות ניהול',
          'admin_mode': 'מצב מנהל',
        };
      default:
        return {
          'title': 'Profile',
          'user_name': _userName.isNotEmpty ? _userName : 'User Name',
          'edit_profile': 'Edit profile',
          'share_profile': 'Share profile',
          'bio': _bio.isNotEmpty ? _bio : 'Professional service provider.',
          'projects': 'Project',
          'reviews': 'Reviews',
          'about': 'About',
          'add_project': 'Add Project',
          'call': 'Call',
          'message': 'Message',
          'contact_info': 'Contact Info',
          'no_reviews': 'No reviews yet',
          'rating_title': 'Rate Worker',
          'rating_hint': 'Write a review...',
          'submit': 'Submit',
          'cancel': 'Cancel',
          'description': 'Description',
          'take_photo': 'Take Photo',
          'pick_gallery': 'Pick from Gallery',
          'add': 'Add',
          'delete_project': 'Delete Project',
          'delete_confirm': 'Are you sure you want to delete this project?',
          'delete': 'Delete',
          'upgrade_pro': 'Upgrade to Pro',
          'guest_msg': 'You must sign up to perform this action',
          'login': 'Sign In',
          'schedule': 'Schedule',
          'price_guide': 'Price Guide',
          'report': 'Report',
          'add_review': 'Add Review',
          'edit_review': 'Edit Review',
          'report_success': 'Report sent successfully',
          'please_login': 'Please log in to view your profile',
          'error': 'Upload Error',
          'comments': 'Comments',
          'add_comment': 'Add a comment...',
          'write_on_image': 'Write on image (Optional)',
          'delete_project_title': 'Delete Project',
          'confirm_delete': 'Are you sure you want to delete this project?',
          'settings': 'Settings',
          'create_invoice': 'Create Invoice / Quote',
          'verify_business': 'Verify Business (Dealer)',
          'analytics_title': 'Professional Analytics',
          'total_jobs': 'Jobs Completed',
          'monthly_views': 'Views this Month',
          'total_earnings': 'Total Earnings',
          'id_verified': 'ID Verified',
          'business_verified': 'Business Verified',
          'insured': 'Insured',
          'analytics': 'Professional Analyzation',
          'distance': 'Distance from you',
          'price': 'Price',
          'service': 'Service',
          'timing': 'Timing',
          'choose_profession': 'Choose Profession',
          'admin_panel': 'Admin Panel',
          'sys_overview': 'System Overview',
          'admin_actions': 'Admin Actions',
          'admin_mode': 'Admin Mode',
        };
    }
  }

  bool _isGuest() => FirebaseAuth.instance.currentUser == null || FirebaseAuth.instance.currentUser!.isAnonymous;

  void _showGuestDialog(BuildContext context, Map<String, String> strings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(strings['guest_msg']!, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(strings['cancel']!)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInPage()));
            },
            child: Text(strings['login']!),
          ),
        ],
      ),
    );
  }

  void _shareProfile(Map<String, String> strings) {
    Share.share("${strings['user_name']}: $_userName\n${strings['bio']}: $_bio");
  }

  Future<void> _addProject() async {
    final strings = _getLocalizedStrings(context);
    if (_isGuest()) {
      _showGuestDialog(context, strings);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProjectPage(
          localizedStrings: strings,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _fetchUserData();
      }
    });
  }

  Future<void> _reportUser(Map<String, String> strings) async {
    if (_isGuest()) {
      _showGuestDialog(context, strings);
      return;
    }
    final reasonController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(strings['report']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            hintText: strings['rating_hint'],
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          maxLines: 3
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(strings['cancel']!)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final targetUid = widget.userId;
              if (targetUid == null) return;
              await _firestore.collection('reports').add({
                'reporterId': FirebaseAuth.instance.currentUser!.uid,
                'reportedId': targetUid,
                'reason': reasonController.text,
                'timestamp': FieldValue.serverTimestamp(),
              });
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings['report_success']!)));
            },
            child: Text(strings['submit']!),
          ),
        ],
      ),
    );
  }

  Future<void> _showReviewDialog(Map<String, String> strings, {Map<String, dynamic>? existingReview}) async {
    if (_isGuest()) {
      _showGuestDialog(context, strings);
      return;
    }

    double starsPrice = existingReview != null ? (existingReview['starsPrice'] as num? ?? existingReview['stars'] ?? 5.0).toDouble() : 5.0;
    double starsService = existingReview != null ? (existingReview['starsService'] as num? ?? existingReview['stars'] ?? 5.0).toDouble() : 5.0;
    double starsTiming = existingReview != null ? (existingReview['starsTiming'] as num? ?? existingReview['stars'] ?? 5.0).toDouble() : 5.0;

    String? selectedProfession = existingReview != null ? existingReview['profession'] : (_userProfessions.isNotEmpty ? _userProfessions.first : null);

    final commentController = TextEditingController(text: existingReview != null ? existingReview['comment'] : "");

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(existingReview != null ? strings['edit_review']! : strings['rating_title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_userProfessions.length > 1) ...[
                DropdownButtonFormField<String>(
                  value: selectedProfession,
                  decoration: InputDecoration(labelText: strings['choose_profession']),
                  items: _userProfessions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) => setDialogState(() => selectedProfession = val),
                ),
                const SizedBox(height: 16),
              ],
              _buildRatingRow(strings['price']!, starsPrice, (v) => setDialogState(() => starsPrice = v)),
              _buildRatingRow(strings['service']!, starsService, (v) => setDialogState(() => starsService = v)),
              _buildRatingRow(strings['timing']!, starsTiming, (v) => setDialogState(() => starsTiming = v)),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: strings['rating_hint'],
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                maxLines: 3
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(strings['cancel']!)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                final targetUid = widget.userId;
                if (targetUid == null) return;

                final currentUser = FirebaseAuth.instance.currentUser!;
                String authorName = currentUser.displayName ?? "User";
                if (authorName == "User") {
                   final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
                   if (userDoc.exists) authorName = userDoc.data()?['name'] ?? "User";
                }

                double avg = (starsPrice + starsService + starsTiming) / 3.0;

                final reviewData = {
                  'userId': currentUser.uid,
                  'userName': authorName,
                  'stars': avg,
                  'starsPrice': starsPrice,
                  'starsService': starsService,
                  'starsTiming': starsTiming,
                  'profession': selectedProfession,
                  'comment': commentController.text,
                  'timestamp': FieldValue.serverTimestamp(),
                };

                await _firestore.runTransaction((transaction) async {
                  final userRef = _firestore.collection('users').doc(targetUid);
                  final userSnap = await transaction.get(userRef);

                  if (!userSnap.exists) return;

                  final data = userSnap.data()!;
                  double currentAvg = (data['avgRating'] ?? 0.0).toDouble();
                  int currentCount = (data['reviewCount'] ?? 0);
                  Map<String, dynamic> professionStats = Map<String, dynamic>.from(data['professionStats'] ?? {});

                  final reviewsRef = userRef.collection('reviews');

                  if (existingReview != null) {
                    double oldStars = (existingReview['stars'] as num).toDouble();
                    String oldProf = existingReview['profession'] ?? "";

                    // Update overall avg
                    double totalStars = (currentAvg * currentCount) - oldStars + avg;
                    double newAvg = totalStars / currentCount;

                    // Update profession-specific stats
                    if (oldProf.isNotEmpty && professionStats.containsKey(oldProf)) {
                       var pStat = professionStats[oldProf];
                       double pAvg = (pStat['avg'] ?? 0.0).toDouble();
                       int pCount = pStat['count'] ?? 0;

                       if (oldProf == selectedProfession) {
                          double pTotal = (pAvg * pCount) - oldStars + avg;
                          professionStats[oldProf] = {'avg': pTotal / pCount, 'count': pCount};
                       } else {
                          // Moved review from one profession to another
                          // Remove from old
                          if (pCount > 1) {
                             professionStats[oldProf] = {'avg': ((pAvg * pCount) - oldStars) / (pCount - 1), 'count': pCount - 1};
                          } else {
                             professionStats.remove(oldProf);
                          }
                          // Add to new
                          if (selectedProfession != null) {
                             var nStat = professionStats[selectedProfession] ?? {'avg': 0.0, 'count': 0};
                             double nAvg = (nStat['avg'] ?? 0.0).toDouble();
                             int nCount = nStat['count'] ?? 0;
                             professionStats[selectedProfession!] = {'avg': ((nAvg * nCount) + avg) / (nCount + 1), 'count': nCount + 1};
                          }
                       }
                    }

                    transaction.update(reviewsRef.doc(existingReview['id']), reviewData);
                    transaction.update(userRef, {
                      'avgRating': newAvg,
                      'professionStats': professionStats,
                    });
                  } else {
                    double totalStars = (currentAvg * currentCount) + avg;
                    int newCount = currentCount + 1;
                    double newAvg = totalStars / newCount;

                    // Update profession-specific stats
                    if (selectedProfession != null) {
                       var pStat = professionStats[selectedProfession] ?? {'avg': 0.0, 'count': 0};
                       double pAvg = (pStat['avg'] ?? 0.0).toDouble();
                       int pCount = pStat['count'] ?? 0;
                       professionStats[selectedProfession!] = {'avg': ((pAvg * pCount) + avg) / (pCount + 1), 'count': pCount + 1};
                    }

                    transaction.set(reviewsRef.doc(), reviewData);
                    transaction.update(userRef, {
                      'avgRating': newAvg,
                      'reviewCount': newCount,
                      'professionStats': professionStats,
                    });
                  }
                });

                if (!mounted) return;
                Navigator.pop(context);
                _fetchUserData();
              },
              child: Text(strings['submit']!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow(String label, double rating, Function(double) onRatingChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 24),
          onPressed: () => onRatingChanged(i + 1.0)))),
      ],
    );
  }

  void _showProjectDetail(Map<String, dynamic> project) {
    final strings = _getLocalizedStrings(context);
    final targetUid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (targetUid == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailPage(
          project: project,
          userId: targetUid,
          localizedStrings: strings,
          onDelete: _isOwnProfile ? () async {
            await _firestore.collection('users').doc(targetUid).collection('projects').doc(project['id']).delete();
            _fetchUserData();
          } : null,
        ),
      ),
    ).then((_) => _fetchUserData());
  }

  Future<void> _confirmDeleteProject(Map<String, dynamic> project) async {
    if (!_isOwnProfile) return;
    final strings = _getLocalizedStrings(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(strings['delete_project']!, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(strings['confirm_delete']!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings['cancel']!)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings['delete']!),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final targetUid = FirebaseAuth.instance.currentUser!.uid;
        await _firestore.collection('users').doc(targetUid).collection('projects').doc(project['id']).delete();
        await _fetchUserData();
      } catch (e) {
        debugPrint("DELETE ERROR: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final isRtl = Provider.of<LanguageProvider>(context).locale.languageCode == 'he' || Provider.of<LanguageProvider>(context).locale.languageCode == 'ar';

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_isOwnProfile && _isGuest() && widget.userId == null) {
      return Scaffold(
        appBar: AppBar(elevation: 0, title: Text(strings['title']!), backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle), child: Icon(Icons.person_outline, size: 80, color: Colors.grey[400])),
          const SizedBox(height: 24),
          Text(strings['please_login']!, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInPage())).then((_) => _fetchUserData()),
            child: Text(strings['login']!),
          ),
        ])),
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final existingReview = _userReviews.cast<Map<String, dynamic>?>().firstWhere(
      (r) => r != null && r['userId'] == currentUser?.uid,
      orElse: () => null,
    );

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        body: RefreshIndicator(
          key: _refreshIndicatorKey,
          color: const Color(0xFF1976D2),
          onRefresh: _fetchUserData,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 450, pinned: true, stretch: true,
                backgroundColor: _userType == 'admin' ? Colors.red[900] : const Color(0xFF1976D2),
                actions: [
                  IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => _shareProfile(strings)),
                  if (!_isOwnProfile)
                    IconButton(
                      icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.redAccent : Colors.white),
                      onPressed: _toggleFavorite
                    ),
                  if (!_isOwnProfile) IconButton(icon: const Icon(Icons.report_problem_outlined, color: Colors.white70), onPressed: () => _reportUser(strings)),
                  if (_isOwnProfile && !_isGuest())
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())).then((_) => _fetchUserData())
                    )
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                  background: Stack(fit: StackFit.expand, children: [
                    _profileImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _profileImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: _userType == 'admin' ? Colors.red[900] : const Color(0xFF1E3A8A)),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        )
                      : Container(color: _userType == 'admin' ? Colors.red[900] : const Color(0xFF1E3A8A), child: const Icon(Icons.person, size: 100, color: Colors.white24)),
                    Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.4), Colors.black.withOpacity(0.9)]))),
                    Positioned(bottom: 80, left: 24, right: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5))),
                        if (_userType == 'worker') const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.verified, color: Color(0xFF60A5FA), size: 24)),
                        if (_userType == 'admin') Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)), child: Text(strings['admin_mode']!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
                        if (_isIdVerified) const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.assignment_ind, color: Colors.greenAccent, size: 20)),
                        if (_isBusinessVerified) const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.business_center, color: Colors.orangeAccent, size: 20)),
                        if (_isInsured) const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.shield, color: Colors.blueAccent, size: 20)),
                      ]),
                      const SizedBox(height: 8),
                      if (_userProfessions.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                          child: Text(_userProfessions.join(' • '), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.location_on_rounded, color: Colors.white70, size: 18),
                        const SizedBox(width: 4),
                        Text(_town, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                        if (_distanceStr.isNotEmpty) ...[
                           const SizedBox(width: 12),
                           const Icon(Icons.straighten_rounded, color: Colors.white70, size: 18),
                           const SizedBox(width: 4),
                           Text(_distanceStr, style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold)),
                        ]
                      ]),
                    ])),
                    Positioned(bottom: -1, left: 0, right: 0, child: Container(height: 30, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))))),
                  ]),
                ),
              ),
              if (_userType != 'admin')
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(_projects.length.toString(), strings['projects']!),
                      _buildStatItem(_userReviews.isEmpty ? "0.0" : (_userReviews.map((e) => (e['stars'] as num).toDouble()).reduce((a, b) => a + b) / _userReviews.length).toStringAsFixed(1), strings['reviews']!, icon: Icons.star),
                      _buildStatItem(_userReviews.length.toString(), "Ratings"),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: _userType == 'admin' ? Colors.red : const Color(0xFF1976D2),
                      unselectedLabelColor: Colors.grey[400],
                      indicatorColor: _userType == 'admin' ? Colors.red : const Color(0xFF1976D2),
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      tabs: _buildTabs(strings),
                    ),
                  )
                )
              ),
            ],
            body: Container(
              color: Colors.white,
              child: TabBarView(
                controller: _tabController,
                children: _buildTabViews(strings, existingReview),
              ),
            ),
          ),
        ),
        bottomNavigationBar: (_isOwnProfile && (_userType == 'worker' || _userType == 'admin')) ? null : _buildBottomAction(strings, existingReview),
      ),
    );
  }

  List<Widget> _buildTabs(Map<String, String> strings) {
    if (_userType == 'admin') {
      return [
        Tab(text: strings['sys_overview']),
        Tab(text: strings['admin_actions']),
      ];
    } else if (_userType == 'worker') {
      return [
        Tab(text: strings['about']),
        Tab(text: strings['reviews']),
        Tab(text: strings['schedule']),
        Tab(text: strings['projects']),
      ];
    } else {
      return [
        Tab(text: strings['about']),
        Tab(text: strings['reviews']),
      ];
    }
  }

  List<Widget> _buildTabViews(Map<String, String> strings, Map<String, dynamic>? existingReview) {
    if (_userType == 'admin') {
      return [
        _buildAdminOverviewTab(strings),
        _buildAdminActionsTab(strings),
      ];
    } else if (_userType == 'worker') {
      return [
        _buildAboutTab(strings),
        _buildReviewsTab(strings, existingReview),
        SchedulePage(workerId: widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? "", workerName: _userName),
        _buildProjectsGrid(strings),
      ];
    } else {
      return [
        _buildAboutTab(strings),
        _buildReviewsTab(strings, existingReview),
      ];
    }
  }

  Widget _buildAdminOverviewTab(Map<String, String> strings) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('metadata').doc('stats').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildAdminStatCard('Total Workers', data['totalWorkers']?.toString() ?? '0', Icons.work, Colors.blue),
            const SizedBox(height: 16),
            _buildAdminStatCard('Total Users', '...', Icons.people, Colors.green), // Need a cloud function or different way to count all users efficiently
            const SizedBox(height: 16),
            _buildAdminStatCard('Pending Reports', '...', Icons.report, Colors.orange),
            const SizedBox(height: 16),
            _buildAdminStatCard('Active Subscriptions', '...', Icons.star, Colors.purple),
          ],
        );
      }
    );
  }

  Widget _buildAdminStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAdminActionsTab(Map<String, String> strings) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildAdminActionTile(Icons.admin_panel_settings, strings['admin_panel']!, Colors.red, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel()));
        }),
        _buildAdminActionTile(Icons.search, 'Find User by UID', Colors.blue, () {
          // TODO: Search dialog
        }),
        _buildAdminActionTile(Icons.notifications_active, 'Broadcast Notification', Colors.orange, () {
          // TODO: Notification sender
        }),
        _buildAdminActionTile(Icons.settings, 'Global App Settings', Colors.grey, () {
          // TODO: System config
        }),
      ],
    );
  }

  Widget _buildAdminActionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.chevron_right),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  Widget _buildStatItem(String value, String label, {IconData? icon}) {
    return Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) Icon(icon, color: Colors.amber, size: 16),
        if (icon != null) const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      ]),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildProjectsGrid(Map<String, String> strings) {
    bool canAdd = _isOwnProfile && !_isGuest();
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85),
      itemCount: _projects.length + (canAdd ? 1 : 0),
      itemBuilder: (context, index) {
        if (canAdd && index == 0) {
          return InkWell(
            onTap: _addProject,
            child: Container(
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue[100]!, width: 2, style: BorderStyle.solid)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF1976D2), size: 32),
                const SizedBox(height: 8),
                Text(strings['add']!, style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
              ])
            )
          );
        }
        final project = _projects[canAdd ? index - 1 : index];
        return GestureDetector(
          onTap: () => _showProjectDetail(project),
          onLongPress: () => _confirmDeleteProject(project),
          child: Column(
            children: [
              Expanded(
                child: Hero(
                  tag: 'project_${project['id']}',
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CachedNetworkImage(
                        imageUrl: project['imageUrl'] ?? project['image'] ?? "",
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      )
                    ),
                  ),
                ),
              ),
              if (project['description'] != null && project['description'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                  child: Text(
                    project['description'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab(Map<String, String> strings, Map<String, dynamic>? existingReview) {
    if (_userReviews.isEmpty) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        const SizedBox(height: 100),
        Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Center(child: Text(strings['no_reviews']!, style: TextStyle(color: Colors.grey[50], fontSize: 16))),
      ]);
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: _userReviews.length,
      itemBuilder: (context, index) {
        final r = _userReviews[index];
        final bool isMyReview = r['userId'] == FirebaseAuth.instance.currentUser?.uid;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['userName'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (r['profession'] != null)
                    Text(r['profession'], style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                ],
              ),
              Row(children: List.generate(5, (i) => Icon(Icons.star, color: i < (r['stars'] as num) ? Colors.amber : Colors.grey[300], size: 14))),
            ]),
            const SizedBox(height: 12),
            if (r['starsPrice'] != null || r['starsService'] != null || r['starsTiming'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (r['starsPrice'] != null) _buildMiniRating(strings['price']!, (r['starsPrice'] as num).toDouble()),
                    if (r['starsService'] != null) _buildMiniRating(strings['service']!, (r['starsService'] as num).toDouble()),
                    if (r['starsTiming'] != null) _buildMiniRating(strings['timing']!, (r['starsTiming'] as num).toDouble()),
                  ],
                ),
              ),
            Text(r['comment'] ?? "", style: TextStyle(color: Colors.grey[700], height: 1.4)),
            if (isMyReview)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => _showReviewDialog(strings, existingReview: existingReview), child: Text(strings['edit_review']!, style: const TextStyle(fontSize: 12)))
              ),
          ]),
        );
      }
    );
  }

  Widget _buildMiniRating(String label, double rating) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) => Icon(Icons.star, color: i < rating ? Colors.amber : Colors.grey[300], size: 10))),
      ],
    );
  }

  Widget _buildAboutTab(Map<String, String> strings) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(strings['bio']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 12),
        Text(_bio.isNotEmpty ? _bio : (strings['bio'] ?? ""), style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.6)),
        if (_userType == 'worker' && (_isIdVerified || _isBusinessVerified || _isInsured)) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (_isIdVerified) _buildBadge(Icons.assignment_ind, strings['id_verified'] ?? 'ID Verified', Colors.green),
              if (_isBusinessVerified) _buildBadge(Icons.business_center, strings['business_verified'] ?? 'Business Verified', Colors.orange),
              if (_isInsured) _buildBadge(Icons.shield, strings['insured'] ?? 'Insured', Colors.blue),
            ],
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        Text(strings['contact_info'] ?? 'Contact Info', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 16),
        _buildContactTile(Icons.phone_rounded, _phoneNumber, Colors.green),
        if (_altPhoneNumber.isNotEmpty) _buildContactTile(Icons.phone_iphone_rounded, _altPhoneNumber, Colors.green),
        _buildContactTile(Icons.email_rounded, _email, Colors.blue),
        if (_distanceStr.isNotEmpty) ...[
           _buildContactTile(Icons.straighten_rounded, "${strings['distance'] ?? 'Distance'}: $_distanceStr", Colors.purple),
        ],
        const SizedBox(height: 32),
        if (_isOwnProfile && _userType == 'worker') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceBuilderPage(workerName: _userName, workerPhone: _phoneNumber, workerEmail: _email))),
              icon: const Icon(Icons.description_outlined),
              label: Text(strings['create_invoice'] ?? 'Create Invoice', style: const TextStyle(fontWeight: FontWeight.bold))
            )
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal, side: const BorderSide(color: Colors.teal), padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyBusinessPage())),
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(strings['verify_business'] ?? 'Verify Business', style: const TextStyle(fontWeight: FontWeight.bold))
            )
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsPage(userId: widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? "", strings: strings))),
              icon: const Icon(Icons.analytics_outlined),
              label: Text(strings['analytics'] ?? 'Professional Analytics', style: const TextStyle(fontWeight: FontWeight.bold))
            )
          ),
          const SizedBox(height: 12),
        ],
        if (_isOwnProfile && _userType == 'admin') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel()));
              },
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: Text(strings['admin_panel']!, style: const TextStyle(fontWeight: FontWeight.bold))
            )
          ),
          const SizedBox(height: 12),
        ],
      ])
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildContactTile(IconData icon, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildBottomAction(Map<String, String> strings, Map<String, dynamic>? existingReview) {
    if (_isOwnProfile && _userType == 'normal' && !_isGuest()) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionPage(email: _email))).then((_) => _fetchUserData()),
          child: Container(
            height: 60,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.stars_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 12),
              Text(strings['upgrade_pro'] ?? 'Upgrade to Pro', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ]),
          ),
        ),
      );
    }

    if (_isOwnProfile) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 34),
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -10))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: _buildActionBtn(
              onTap: () {
                if (_isGuest()) {
                  _showGuestDialog(context, strings);
                } else {
                  launchUrl(Uri.parse("tel:$_phoneNumber"));
                }
              },
              icon: Icons.phone_forwarded_rounded,
              label: strings['call'] ?? 'Call',
              color: const Color(0xFF10B981)
            )
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionBtn(
              onTap: () {
                if (_isGuest()) {
                  _showGuestDialog(context, strings);
                } else {
                  if (widget.userId != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(receiverId: widget.userId!, receiverName: _userName)));
                  }
                }
              },
              icon: Icons.chat_bubble_rounded,
              label: strings['message'] ?? 'Message',
              color: const Color(0xFF3B82F6)
            )
          ),
        ]),
        if (_userType == 'worker') ...[
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _showReviewDialog(strings, existingReview: existingReview),
            child: Container(
              height: 56, width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 1.5)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(existingReview != null ? Icons.edit_note_rounded : Icons.star_rounded, color: const Color(0xFFD97706), size: 24),
                const SizedBox(width: 10),
                Text(existingReview != null ? (strings['edit_review'] ?? 'Edit Review') : (strings['add_review'] ?? 'Add Review'), style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildActionBtn({required VoidCallback onTap, required IconData icon, required String label, required Color color}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
  }
}

class AddProjectPage extends StatefulWidget {
  final Map<String, String> localizedStrings;

  const AddProjectPage({
    super.key,
    required this.localizedStrings,
  });

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedFile;
  bool _isUploading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() {
          _pickedFile = image;
        });
      }
    } catch (e) {
      debugPrint("PICK ERROR: $e");
    }
  }

  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path = "${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg";

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      path,
      quality: 85,
      minWidth: 1024,
      minHeight: 1024,
    );

    return File(result!.path);
  }

  Future<void> _uploadProject() async {
    if (_pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      File compressedFile = await _compressImage(File(_pickedFile!.path));

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('projects/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(compressedFile);
      final downloadUrl = await storageRef.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).collection('projects').add({
        'imageUrl': downloadUrl,
        'description': _descriptionController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${widget.localizedStrings['error']}: $e"))
        );
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        title: Text(widget.localizedStrings['add_project'] ?? 'Add Project'),
        elevation: 0,
      ),
      body: _isUploading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: _pickedFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              File(_pickedFile!.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 250,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                widget.localizedStrings['pick_gallery'] ?? 'Pick from Gallery',
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.localizedStrings['description'] ?? 'Description',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: widget.localizedStrings['write_on_image'] ?? 'Write on image (Optional)',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    onPressed: _pickedFile == null ? null : _uploadProject,
                    child: Text(
                      widget.localizedStrings['add'] ?? 'Add',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class ProjectDetailPage extends StatefulWidget {
  final Map<String, dynamic> project;
  final String userId;
  final Map<String, String> localizedStrings;
  final VoidCallback? onDelete;

  const ProjectDetailPage({
    super.key,
    required this.project,
    required this.userId,
    required this.localizedStrings,
    this.onDelete,
  });

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _comments = [];
  StreamSubscription? _commentsSubscription;

  @override
  void initState() {
    super.initState();
    _listenToComments();
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  void _listenToComments() {
    _commentsSubscription = _firestore.collection('users')
        .doc(widget.userId)
        .collection('projects')
        .doc(widget.project['id'])
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      final loaded = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
      if (mounted) setState(() => _comments = loaded);
    });
  }

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    if (_commentController.text.trim().isEmpty) return;

    String authorName = user.displayName ?? "User";
    if (authorName == "User") {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) authorName = userDoc.data()?['name'] ?? "User";
    }

    await _firestore.collection('users')
        .doc(widget.userId)
        .collection('projects')
        .doc(widget.project['id'])
        .collection('comments')
        .add({
      'userId': user.uid,
      'userName': authorName,
      'text': _commentController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            pinned: true,
            actions: [
              if (widget.onDelete != null)
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () { widget.onDelete!(); Navigator.pop(context); }),
            ],
          ),
          SliverToBoxAdapter(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: widget.project['imageUrl'] ?? widget.project['image'] ?? "",
                fit: BoxFit.contain,
                width: double.infinity,
                placeholder: (context, url) => Container(height: 300, color: Colors.grey[900]),
                errorWidget: (context, url, error) => Container(
                  height: 300,
                  color: Colors.grey[900],
                  child: const Icon(Icons.broken_image, color: Colors.white54, size: 50),
                ),
              )
            ),
          ),
          if (widget.project['description'] != null && widget.project['description'].toString().isNotEmpty)
            SliverToBoxAdapter(
              child: Container(padding: const EdgeInsets.all(24), color: Colors.black54, child: Text(widget.project['description'], style: const TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center)),
            ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: Container(
              margin: const EdgeInsets.only(top: 20),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
              child: Column(children: [
                Padding(padding: const EdgeInsets.all(20), child: Text(widget.localizedStrings['comments'] ?? 'Comments', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final c = _comments[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(c['userName'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1976D2))),
                              if (c['timestamp'] != null) Text(_formatTimestamp(c['timestamp']), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(c['text'] ?? "", style: const TextStyle(fontSize: 15, color: Color(0xFF334155))),
                        ]),
                      );
                    },
                  ),
                ),
                if (FirebaseAuth.instance.currentUser != null && !FirebaseAuth.instance.currentUser!.isAnonymous)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(hintText: widget.localizedStrings['add_comment'] ?? 'Add a comment...', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(backgroundColor: const Color(0xFF1976D2), child: IconButton(onPressed: _addComment, icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
                    ]),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}/${date.month}/${date.year}";
    }
    return "";
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._child);
  final Widget _child;
  @override double get minExtent => 48;
  @override double get maxExtent => 48;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => _child;
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
