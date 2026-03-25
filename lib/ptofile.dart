import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';

import 'package:untitled1/services/language_provider.dart';
import 'package:untitled1/sighn_in.dart';
import 'package:untitled1/pages/schedule.dart';
import 'package:untitled1/pages/settings.dart';
import 'package:untitled1/pages/subscription.dart';
import 'package:untitled1/pages/invoice_builder.dart';
import 'package:untitled1/pages/verify_business.dart';
import 'package:untitled1/pages/chat_page.dart';
import 'package:untitled1/pages/analytics_page.dart';
import 'package:untitled1/pages/add_project.dart';
import 'package:untitled1/pages/add_review.dart';


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
  String _userCollection = "normal_users";
  List<String> _userProfessions = [];
  List<Map<String, dynamic>> _userReviews = [];
  List<Map<String, dynamic>> _projects = [];
  int _profileViews = 0;
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
    int tabCount = (_userType == 'worker' || _isOwnProfile) ? 4 : 2;
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
      DocumentSnapshot? userDoc;
      String foundInCollection = "normal_users";
      
      final collections = ['normal_users', 'workers', 'users'];
      for (var col in collections) {
        final doc = await _firestore.collection(col).doc(targetUid).get();
        if (doc.exists) {
          userDoc = doc;
          foundInCollection = col;
          break;
        }
      }

      if (userDoc != null && userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;

        String oldType = _userType;
        setState(() {
          _userCollection = foundInCollection;
          _userName = data['name']?.toString() ?? "";
          _bio = data['description']?.toString() ?? "";
          _phoneNumber = data['phone']?.toString() ?? "";
          _altPhoneNumber = data['optionalPhone']?.toString() ?? "";
          _email = data['email']?.toString() ?? "";
          _town = data['town']?.toString() ?? "";
          _profileImageUrl = data['profileImageUrl']?.toString() ?? "";
          _profileViews = data['profileViews'] ?? 0;

          if (foundInCollection == 'workers') {
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

        final reviews = await _fetchSubcollection(targetUid, foundInCollection, 'reviews');
        final projects = await _fetchSubcollection(targetUid, foundInCollection, 'projects');

        if (mounted) {
          setState(() {
            _userReviews = reviews;
            _projects = projects;
          });
        }

        if (currentUser != null && !_isOwnProfile) {
          DocumentSnapshot? favDoc;
          for (var col in collections) {
            final doc = await _firestore.collection(col).doc(currentUser.uid).collection('favorites').doc(targetUid).get();
            if (doc.exists) {
              favDoc = doc;
              break;
            }
          }
          if (mounted) setState(() => _isFavorite = favDoc?.exists ?? false);
        }

        if (!_isOwnProfile) {
          _firestore.collection(foundInCollection).doc(targetUid).update({
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

    String currentUserCol = "normal_users";
    final collections = ['normal_users', 'workers', 'users'];
    for (var col in collections) {
      final doc = await _firestore.collection(col).doc(currentUser.uid).get();
      if (doc.exists) {
        currentUserCol = col;
        break;
      }
    }

    final favRef = _firestore.collection(currentUserCol).doc(currentUser.uid).collection('favorites').doc(targetUid);

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
          'targetCollection': _userCollection,
        });
        if (mounted) setState(() => _isFavorite = true);
      }
    } catch (e) {
      debugPrint("FAVORITE TOGGLE ERROR: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSubcollection(String uid, String collection, String subcollectionName) async {
    try {
      final snapshot = await _firestore.collection(collection).doc(uid).collection(subcollectionName).orderBy('timestamp', descending: true).get();
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint("Subcollection error ($subcollectionName): $e");
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
          'bio_title': 'אודות',
          'projects': 'פרויקטים',
          'reviews': 'ביקורות',
          'about': 'מידע',
          'schedule': 'לוח זמנים',
          'add_project': 'הוסף פרויקט',
          'call': 'התקשר',
          'message': 'הודעה',
          'contact_info': 'מידע ליצירת קשר',
          'no_reviews': 'אין עדיין ביקורות',
          'no_projects': 'אין עדיין פרויקטים להצגה',
          'guest_title': 'התחבר למערכת',
          'guest_msg': 'פעולה זו דורשת התחברות לחשבון שלך.',
          'login': 'התחבר',
          'cancel': 'ביטול',
          'report': 'דווח על משתמש',
          'rating_hint': 'כתוב סיבה לדיווח...',
          'add': 'הוסף',
          'analytics': 'אנליטיקה',
          'invoice_builder': 'בונה חשבוניות',
          'verify_business': 'אימות עסק',
          'business_tools': 'כלים לניהול עסק',
          'verified_id': 'מזהה מאומת',
          'verified_biz': 'עסק מאומת',
          'insured': 'מבוטח',
          'views': 'צפיות',
          'rating': 'דירוג',
          'write_review': 'כתוב ביקורת',
          'edit_review': 'ערוך ביקורת',
          'upgrade_worker': 'שדרג לחשבון עובד',
          'upgrade_msg': 'האם אתה בטוח שברצונך לשדרג לחשבון עובד? תוכל להוסיף פרויקטים ולקבל ביקורות.',
          'confirm': 'שדרג',
        };
      default:
        return {
          'title': 'Profile',
          'user_name': _userName.isNotEmpty ? _userName : 'User Name',
          'edit_profile': 'Edit Profile',
          'share_profile': 'Share Profile',
          'bio': _bio.isNotEmpty ? _bio : 'Your bio will appear here...',
          'bio_title': 'Biography',
          'projects': 'Projects',
          'reviews': 'Reviews',
          'about': 'About',
          'schedule': 'Schedule',
          'add_project': 'Add Project',
          'call': 'Call',
          'message': 'Message',
          'contact_info': 'Contact Information',
          'no_reviews': 'No reviews yet',
          'no_projects': 'No projects to show yet',
          'guest_title': 'Sign In Required',
          'guest_msg': 'This action requires you to be signed in to your account.',
          'login': 'Sign In',
          'cancel': 'Cancel',
          'report': 'Report User',
          'rating_hint': 'Write reason for report...',
          'add': 'Add',
          'analytics': 'Analytics',
          'invoice_builder': 'Invoice Builder',
          'verify_business': 'Verify Business',
          'business_tools': 'Business Tools',
          'verified_id': 'ID Verified',
          'verified_biz': 'Business Verified',
          'insured': 'Insured',
          'views': 'Views',
          'rating': 'Rating',
          'write_review': 'Write a Review',
          'edit_review': 'Edit your Review',
          'upgrade_worker': 'Upgrade to Worker',
          'upgrade_msg': 'Are you sure you want to upgrade to a worker account? You will be able to add projects and receive reviews.',
          'confirm': 'Upgrade',
        };
    }
  }

  void _showGuestDialog(BuildContext context, Map<String, String> strings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(strings['guest_title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(strings['guest_msg']!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(strings['cancel']!)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(strings['login']!),
          ),
        ],
      ),
    );
  }

  bool _isGuest() => FirebaseAuth.instance.currentUser == null;

  Future<void> _addProject() async {
    final strings = _getLocalizedStrings(context);
    if (_isGuest()) {
      _showGuestDialog(context, strings);
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProjectPage()),
    );

    if (result == true) {
      _fetchUserData(); // Refresh data to show new project
    }
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
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(strings['cancel']!)),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              await _firestore.collection('reports').add({
                'reporterId': FirebaseAuth.instance.currentUser!.uid,
                'targetId': widget.userId ?? FirebaseAuth.instance.currentUser!.uid,
                'reason': reasonController.text.trim(),
                'timestamp': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _addReview(Map<String, String> strings) async {
    if (_isGuest()) {
      _showGuestDialog(context, strings);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    Map<String, dynamic>? existingReview;
    
    if (currentUser != null) {
      try {
        existingReview = _userReviews.firstWhere(
          (r) => r['userId'] == currentUser.uid,
        );
      } catch (_) {
        existingReview = null;
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddReviewPage(
          targetUserId: widget.userId ?? "",
          targetCollection: _userCollection,
          professions: _userProfessions,
          existingReview: existingReview,
        ),
      ),
    );

    if (result == true) {
      _fetchUserData();
    }
  }

  Future<void> _upgradeToWorker() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final strings = _getLocalizedStrings(context);
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(strings['upgrade_worker']!, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(strings['upgrade_msg']!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings['cancel']!)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
            child: Text(strings['confirm']!),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final docRef = _firestore.collection(_userCollection).doc(user.uid);
        final docSnap = await docRef.get();
        
        if (docSnap.exists) {
          final data = docSnap.data() as Map<String, dynamic>;
          data['role'] = 'worker'; // Update role field
          
          await _firestore.collection('workers').doc(user.uid).set(data);
          await docRef.delete();
          
          await _fetchUserData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account upgraded to worker successfully!')));
          }
        }
      } catch (e) {
        debugPrint("Upgrade error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upgrade failed: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareProfile(Map<String, String> strings) async {
    final profileUrl = "https://hirehub.app/profile/${widget.userId ?? FirebaseAuth.instance.currentUser?.uid}";
    await Share.share("${strings['share_profile']} - $_userName: $profileUrl");
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final isRtl = Provider.of<LanguageProvider>(context).locale.languageCode == 'he' || 
                 Provider.of<LanguageProvider>(context).locale.languageCode == 'ar';

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF1976D2))));
    }

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
                backgroundColor: const Color(0xFF1976D2),
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
                    Hero(
                      tag: widget.userId ?? (FirebaseAuth.instance.currentUser?.uid ?? 'profile'),
                      child: _profileImageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _profileImageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: const Color(0xFF1E3A8A)),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          )
                        : Container(color: const Color(0xFF1E3A8A), child: const Icon(Icons.person, size: 100, color: Colors.white24)),
                    ),
                    Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.8)]))),
                    Positioned(bottom: 60, left: 24, right: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: -0.5))),
                        if (_userType == 'worker') const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.verified, color: Color(0xFF60A5FA), size: 24)),
                      ]),
                      const SizedBox(height: 6),
                      if (_userProfessions.isNotEmpty)
                        Text(_userProfessions.join(' • '), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w400)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(_projects.length.toString(), strings['projects']!),
                          _buildStatItem(_userReviews.length.toString(), strings['reviews']!),
                          _buildStatItem(_profileViews.toString(), strings['views']!),
                          if (_userReviews.isNotEmpty) _buildStatItem(_calculateAverageRating().toStringAsFixed(1), strings['rating']!),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          if (_isIdVerified) _buildHeaderBadge(Icons.assignment_ind, strings['verified_id']!, Colors.greenAccent),
                          if (_isBusinessVerified) _buildHeaderBadge(Icons.business_center, strings['verified_biz']!, Colors.orangeAccent),
                          if (_isInsured) _buildHeaderBadge(Icons.shield, strings['insured']!, Colors.blueAccent),
                        ]),
                      ),
                    ])),
                    Positioned(bottom: -1, left: 0, right: 0, child: Container(height: 30, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))))),
                  ]),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    indicatorColor: const Color(0xFF1976D2),
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: const Color(0xFF1976D2),
                    unselectedLabelColor: Colors.grey[400],
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: _buildTabs(strings),
                  ),
                ),
              ),
            ],
            body: Container(
              color: Colors.white,
              child: TabBarView(
                controller: _tabController,
                children: _buildTabViews(strings),
              ),
            ),
          ),
        ),
        bottomNavigationBar: (!_isOwnProfile && _userType == 'worker') ? _buildBottomBar(strings) : null,
        floatingActionButton: _isOwnProfile ? FloatingActionButton.extended(
          onPressed: _addProject,
          backgroundColor: const Color(0xFF1976D2),
          icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
          label: Text(strings['add']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ) : null,
      ),
    );
  }

  double _calculateAverageRating() {
    if (_userReviews.isEmpty) return 0.0;
    double total = 0;
    for (var r in _userReviews) {
      total += (r['rating'] ?? 0).toDouble();
    }
    return total / _userReviews.length;
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
      ],
    );
  }

  Widget _buildHeaderBadge(IconData icon, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4), width: 0.5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  List<Widget> _buildTabs(Map<String, String> strings) {
    if (_userType == 'worker' || _isOwnProfile) {
      return [
        Tab(text: strings['projects']),
        Tab(text: strings['reviews']),
        Tab(text: strings['schedule']),
        Tab(text: strings['about']),

      ];
    }
    return [Tab(text: strings['about']), Tab(text: "Activity")];
  }

  List<Widget> _buildTabViews(Map<String, String> strings) {
    if (_userType == 'worker' || _isOwnProfile) {
      final currentUserId = widget.userId ?? FirebaseAuth.instance.currentUser!.uid;
      return [
        _buildProjectsGrid(strings),
        _buildReviewsList(strings),
        SchedulePage(workerId: currentUserId, workerName: _userName),
        _buildAboutSection(strings),
      ];
    }
    return [
      _buildAboutSection(strings),
      const Center(child: Text("Activity Feed")),
    ];
  }

  Widget _buildProjectsGrid(Map<String, String> strings) {
    if (_projects.isEmpty && !_isOwnProfile) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[200]), const SizedBox(height: 16), Text(strings['no_projects']!, style: TextStyle(color: Colors.grey[400]))]));
    }

    bool canAdd = _isOwnProfile;

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85),
      itemCount: _projects.length + (canAdd ? 1 : 0),
      itemBuilder: (context, index) {
        if (canAdd && index == 0) {
          return InkWell(
            onTap: _addProject,
            child: Container(
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue[100]!, width: 1.5, style: BorderStyle.solid)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_outlined, color: Colors.blue[300], size: 40),
                const SizedBox(height: 8),
                Text(strings['add_project']!, textAlign: TextAlign.center, style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600, fontSize: 13)),
              ])
            )
          );
        }
        final project = _projects[canAdd ? index - 1 : index];
        return GestureDetector(
          onTap: () => _showProjectDetail(project),
          onLongPress: () => _confirmDeleteProject(project),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: project['imageUrl'] ?? project['image'] ?? "",
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[100]),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                  if ((project['imageUrls'] as List?) != null && (project['imageUrls'] as List).length > 1)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.copy, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text("${(project['imageUrls'] as List).length}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)])), child: Text(project['description'] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProjectDetail(Map<String, dynamic> project) {
    final List<dynamic> images = project['imageUrls'] ?? [project['imageUrl'] ?? project['image'] ?? ""];
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (images.length > 1)
                SizedBox(
                  height: 300,
                  child: PageView.builder(
                    itemCount: images.length,
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                      child: CachedNetworkImage(
                        imageUrl: images[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  child: CachedNetworkImage(
                    imageUrl: images[0],
                    fit: BoxFit.cover,
                  ),
                ),
              if (project['description'] != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(project['description'], style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteProject(Map<String, dynamic> project) async {
    if (!_isOwnProfile) return;
    
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project?'),
        content: const Text('Are you sure you want to remove this project from your profile?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 1. Delete image(s) from Firebase Storage
        final List<dynamic> imageUrls = project['imageUrls'] ?? [];
        final String? singleImageUrl = project['imageUrl'] ?? project['image'];
        
        if (imageUrls.isNotEmpty) {
          for (var url in imageUrls) {
            await FirebaseStorage.instance.refFromURL(url).delete();
          }
        } else if (singleImageUrl != null && singleImageUrl.isNotEmpty) {
          await FirebaseStorage.instance.refFromURL(singleImageUrl).delete();
        }

        // 2. Delete document from Firestore
        await _firestore.collection(_userCollection).doc(FirebaseAuth.instance.currentUser!.uid).collection('projects').doc(project['id']).delete();
        
        _fetchUserData();
      } catch (e) {
        debugPrint("Delete project error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting project: $e")));
        }
      }
    }
  }

  Widget _buildReviewsList(Map<String, String> strings) {
    final currentUser = FirebaseAuth.instance.currentUser;
    bool hasReviewed = false;
    if (currentUser != null) {
      hasReviewed = _userReviews.any((r) => r['userId'] == currentUser.uid);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!_isOwnProfile)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton.icon(
              onPressed: () => _addReview(strings),
              icon: Icon(hasReviewed ? Icons.edit_note_outlined : Icons.rate_review_outlined),
              label: Text(hasReviewed ? strings['edit_review']! : strings['write_review']!),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasReviewed ? Colors.orange[800] : const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (_userReviews.isEmpty)
          Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(height: 40), Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[200]), const SizedBox(height: 16), Text(strings['no_reviews']!, style: TextStyle(color: Colors.grey[400]))]))
        else
          ..._userReviews.map((review) {
            final List<dynamic> reviewImages = review['imageUrls'] ?? [];
            final bool isMyReview = currentUser != null && review['userId'] == currentUser.uid;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(20), 
                border: Border.all(color: isMyReview ? Colors.orange[200]! : Colors.grey[100]!, width: isMyReview ? 2 : 1), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(review['userName'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
                          if (review['profession'] != null)
                            Text(review['profession'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                      Row(
                        children: [
                          if (isMyReview)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20, color: Colors.orange),
                              onPressed: () => _addReview(strings),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          const SizedBox(width: 8),
                          Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 18, color: i < (review['rating'] ?? 0) ? Colors.amber : Colors.grey[300]))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (review['priceRating'] != null || review['workRating'] != null || review['professionalismRating'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 12,
                        children: [
                          if (review['priceRating'] != null) _buildSmallRatingBadge(Icons.attach_money, review['priceRating'].toString()),
                          if (review['workRating'] != null) _buildSmallRatingBadge(Icons.build_circle_outlined, review['workRating'].toString()),
                          if (review['professionalismRating'] != null) _buildSmallRatingBadge(Icons.stars_outlined, review['professionalismRating'].toString()),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(review['comment'] ?? '', style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 14)),
                  if (reviewImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: reviewImages.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: reviewImages[i],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildSmallRatingBadge(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 2),
        Text(value, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAboutSection(Map<String, String> strings) {
    final currentUserId = widget.userId ?? FirebaseAuth.instance.currentUser!.uid;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(strings['bio_title']!),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20)),
            child: Text(strings['bio']!, style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800])),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(strings['contact_info']!),
          const SizedBox(height: 16),
          _buildInfoCard([
            _buildInfoRow(Icons.phone_rounded, strings['call']!, _phoneNumber),
            if (_altPhoneNumber.isNotEmpty) _buildInfoRow(Icons.phone_iphone_rounded, "Secondary", _altPhoneNumber),
            _buildInfoRow(Icons.email_rounded, "Email", _email),
            _buildInfoRow(Icons.location_city_rounded, "Town", _town),
            if (_distanceStr.isNotEmpty) _buildInfoRow(Icons.straighten_rounded, "Distance", _distanceStr),
          ]),

          if (_isOwnProfile) ...[
            const SizedBox(height: 32),
            _buildSectionTitle(_userType == 'worker' ? strings['business_tools']! : strings['upgrade_worker']!),
            const SizedBox(height: 16),
            if (_userType == 'worker')
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildModernToolCard(Icons.analytics_outlined, strings['analytics']!, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsPage(userId: currentUserId, strings: strings)))),
                  _buildModernToolCard(Icons.description_outlined, strings['invoice_builder']!, Colors.teal, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceBuilderPage(workerName: _userName, workerPhone: _phoneNumber, workerEmail: _email)));
                  }),
                  _buildModernToolCard(Icons.verified_user_outlined, strings['verify_business']!, Colors.deepOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyBusinessPage()))),
                ],
              )
            else
              _buildModernToolCard(Icons.upgrade_rounded, strings['upgrade_worker']!, Colors.purple, _upgradeToWorker),
          ]
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)));
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey[100]!), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Column(children: children),
    );
  }

  Widget _buildModernToolCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.15))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color.withOpacity(0.9))),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF1976D2), size: 18)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500)),
                Text(value.isNotEmpty ? value : 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E3A8A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Map<String, String> strings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[100]!)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))]),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse("tel:$_phoneNumber")),
              icon: const Icon(Icons.call, size: 20),
              label: Text(strings['call']!),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                if (_isGuest()) {
                  _showGuestDialog(context, strings);
                  return;
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(receiverId: widget.userId!, receiverName: _userName)));
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              label: Text(strings['message']!),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1976D2), side: const BorderSide(color: Color(0xFF1976D2), width: 1.5), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
