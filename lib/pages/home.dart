import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled1/language_provider.dart';
import 'package:untitled1/pages/search.dart';
import 'package:untitled1/pages/ptofile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: 'https://profis-60aaa-default-rtdb.europe-west1.firebasedatabase.app'
  ).ref();

  List<Map<String, dynamic>> _topRatedWorkers = [];
  bool _isTopRatedLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTopRatedWorkers();
  }

  Future<void> _fetchTopRatedWorkers() async {
    try {
      final usersSnapshot = await _dbRef.child('users').get();
      if (!usersSnapshot.exists) {
        if (mounted) setState(() => _isTopRatedLoading = false);
        return;
      }

      Map<Object?, Object?> allUsers = usersSnapshot.value as Map<Object?, Object?>;
      List<Map<String, dynamic>> workers = [];

      for (var entry in allUsers.entries) {
        var userData = Map<String, dynamic>.from(entry.value as Map);
        if (userData['userType'] == 'worker' && userData['isSubscribed'] == true) {
          userData['uid'] = entry.key;
          workers.add(userData);
        }
      }

      // Calculate ratings
      for (var worker in workers) {
        final reviewsSnapshot = await _dbRef.child('reviews').child(worker['uid']).get();
        double totalStars = 0;
        int reviewCount = 0;

        if (reviewsSnapshot.exists) {
          Map<Object?, Object?> reviews = reviewsSnapshot.value as Map<Object?, Object?>;
          reviewCount = reviews.length;
          reviews.forEach((key, value) {
            final reviewData = Map<String, dynamic>.from(value as Map);
            totalStars += (reviewData['stars'] as num).toDouble();
          });
        }

        worker['avgRating'] = reviewCount > 0 ? totalStars / reviewCount : 0.0;
        worker['reviewCount'] = reviewCount;
      }

      // Sort by avgRating DESC
      workers.sort((a, b) => (b['avgRating'] as double).compareTo(a['avgRating'] as double));
      
      if (mounted) {
        setState(() {
          _topRatedWorkers = workers.take(10).toList();
          _isTopRatedLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching top rated: $e");
      if (mounted) setState(() => _isTopRatedLoading = false);
    }
  }

  Map<String, dynamic> _getLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'welcome': 'שלום,',
          'find_pros': 'איזה שירות דרוש לך היום?',
          'search_hint': 'חפש מקצוען (למשל: אינסטלטור)...',
          'categories': 'קטגוריות פופולריות',
          'see_all': 'הכל',
          'top_rated': 'הכי מדורגים',
          'view_all': 'צפה בהכל',
          'cat_names': {
            'plumber': 'אינסטלטור',
            'Carpenter': 'נגר',
            'Electrician': 'חשמלאי',
            'Painter': 'צבע',
            'Cleaner': 'מנקה',
            'Handyman': 'שיפוצניק',
            'Landscaper': 'גנן',
            'HVAC': 'מיזוג אוויר'
          }
        };
      case 'ar':
        return {
          'welcome': 'مرحباً،',
          'find_pros': 'ما هي الخدمة التي تحتاجها اليوم؟',
          'search_hint': 'ابحث عن מחתרף...',
          'categories': 'الفئات الشائعة',
          'see_all': 'الكل',
          'top_rated': 'الأعلى تقييماً',
          'view_all': 'عرض الكل',
          'cat_names': {
            'plumber': 'سباك',
            'Carpenter': 'نجار',
            'Electrician': 'كهربائي',
            'Painter': 'دهان',
            'Cleaner': 'عامل نظافة',
            'Handyman': 'عامل صيانة',
            'Landscaper': 'منسق حدائق',
            'HVAC': 'تكييف ותبرייد'
          }
        };
      default:
        return {
          'welcome': 'Hello,',
          'find_pros': 'What service do you need today?',
          'search_hint': 'Search for a pro...',
          'categories': 'Popular Categories',
          'see_all': 'See all',
          'top_rated': 'Top Rated',
          'view_all': 'View all',
          'cat_names': {
            'plumber': 'Plumber',
            'Carpenter': 'Carpenter',
            'Electrician': 'Electrician',
            'Painter': 'Painter',
            'Cleaner': 'Cleaner',
            'Handyman': 'Handyman',
            'Landscaper': 'Landscaper',
            'HVAC': 'HVAC'
          }
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final localized = _getLocalizedStrings(context);
    final theme = Theme.of(context);
    final isRtl = Provider.of<LanguageProvider>(context).locale.languageCode == 'he' || 
                  Provider.of<LanguageProvider>(context).locale.languageCode == 'ar';
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          onRefresh: _fetchTopRatedWorkers,
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(localized, theme, user),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategories(context, localized, theme),
                    _buildTopRatedSection(context, localized, theme),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(Map<String, dynamic> strings, ThemeData theme, User? user) {
    return SliverAppBar(
      expandedHeight: 240, // Increased to prevent overflow
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1976D2),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF1976D2)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 70, 24, 20), // Adjusted top padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${strings['welcome']} ${user?.displayName?.split(' ').first ?? ''}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings['find_pros'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 24), // Replaced Spacer() with fixed height to avoid overflow
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: strings['search_hint'],
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1976D2)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategories(BuildContext context, Map<String, dynamic> strings, ThemeData theme) {
    final catNames = strings['cat_names'] as Map<String, String>;
    final List<Map<String, dynamic>> categories = [
      {'key': 'plumber', 'icon': Icons.plumbing_rounded, 'color': const Color(0xFFEEF2FF), 'iconColor': const Color(0xFF6366F1)},
      {'key': 'Carpenter', 'icon': Icons.handyman_rounded, 'color': const Color(0xFFFFF7ED), 'iconColor': const Color(0xFFF97316)},
      {'key': 'Electrician', 'icon': Icons.bolt_rounded, 'color': const Color(0xFFFEFCE8), 'iconColor': const Color(0xFFEAB308)},
      {'key': 'Painter', 'icon': Icons.format_paint_rounded, 'color': const Color(0xFFFDF2F8), 'iconColor': const Color(0xFFEC4899)},
      {'key': 'Cleaner', 'icon': Icons.auto_awesome_rounded, 'color': const Color(0xFFF0FDF4), 'iconColor': const Color(0xFF22C55E)},
      {'key': 'Handyman', 'icon': Icons.architecture_rounded, 'color': const Color(0xFFF5F3FF), 'iconColor': const Color(0xFF8B5CF6)},
      {'key': 'Landscaper', 'icon': Icons.park_rounded, 'color': const Color(0xFFECFDF5), 'iconColor': const Color(0xFF10B981)},
      {'key': 'HVAC', 'icon': Icons.air_rounded, 'color': const Color(0xFFECFEFF), 'iconColor': const Color(0xFF06B6D4)},
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings['categories'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage())),
                child: const Text('See all', style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final categoryName = catNames[cat['key']] ?? cat['key'];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SearchPage(initialTrade: categoryName))),
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cat['color'],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(cat['icon'], color: cat['iconColor'], size: 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      categoryName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopRatedSection(BuildContext context, Map<String, dynamic> strings, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings['top_rated'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage())),
                child: Text(strings['view_all'], style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        if (_isTopRatedLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_topRatedWorkers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text("No pros found yet.", style: TextStyle(color: Colors.grey)),
          )
        else
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _topRatedWorkers.length,
              itemBuilder: (context, index) {
                return _buildTopRatedCard(_topRatedWorkers[index], theme);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTopRatedCard(Map<String, dynamic> worker, ThemeData theme) {
    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => profile(userId: worker['uid']))),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image Placeholder
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                image: worker['profileImageUrl'] != null && worker['profileImageUrl'].toString().isNotEmpty
                    ? DecorationImage(image: NetworkImage(worker['profileImageUrl']), fit: BoxFit.cover)
                    : null,
                color: const Color(0xFFF1F5F9),
              ),
              child: Stack(
                children: [
                  if (worker['profileImageUrl'] == null || worker['profileImageUrl'].toString().isEmpty)
                    const Center(child: Icon(Icons.person_rounded, size: 50, color: Color(0xFF94A3B8))),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            (worker['avgRating'] as double).toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker['name'] ?? 'Worker',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (worker['professions'] is List && (worker['professions'] as List).isNotEmpty)
                        ? (worker['professions'] as List).join(', ')
                        : 'Professional',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFF94A3B8), size: 14),
                      const SizedBox(width: 4),
                      Text(worker['town'] ?? '', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      const Spacer(),
                      if (worker['isPro'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: const Text('PRO', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
