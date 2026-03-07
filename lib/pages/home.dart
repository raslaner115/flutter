
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
    databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
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
          
          double totalStars = 0;
          int reviewCount = 0;
          
          if (userData['reviews'] != null && userData['reviews'] is Map) {
            final Map<dynamic, dynamic> reviews = userData['reviews'] as Map;
            reviewCount = reviews.length;
            reviews.forEach((key, value) {
              if (value is Map) {
                final reviewData = Map<String, dynamic>.from(value);
                totalStars += (reviewData['stars'] as num).toDouble();
              }
            });
          }
          
          userData['avgRating'] = reviewCount > 0 ? totalStars / reviewCount : 0.0;
          userData['reviewCount'] = reviewCount;
          
          workers.add(userData);
        }
      }

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

  Map<String, dynamic> _getLocalizedStrings(BuildContext context, {bool listen = true}) {
    final locale = Provider.of<LanguageProvider>(context, listen: listen).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'welcome': 'שלום,',
          'find_pros': 'איזה שירות דרוש לך היום?',
          'search_hint': 'חפש מקצוען (למשל: אינסטלטור)...',
          'categories': 'קטגוריות פופולריות',
          'see_all': 'הכל',
          'top_rated': 'מקצוענים מובילים בשבילך',
          'view_all': 'ראה עוד',
          'cat_names': {
            'plumber': 'אינסטלציה',
            'Carpenter': 'נגרות',
            'Electrician': 'חשמל',
            'Painter': 'צבע',
            'Cleaner': 'ניקיון',
            'Handyman': 'תיקונים',
            'Landscaper': 'גינון',
            'HVAC': 'מיזוג'
          }
        };
      case 'ar':
        return {
          'welcome': 'أهلاً بك،',
          'find_pros': 'ما هي الخدمة التي تحتاجها اليوم؟',
          'search_hint': 'ابحث عن محترف...',
          'categories': 'الفئات الأكثر شعبية',
          'see_all': 'الكل',
          'top_rated': 'أفضل المحترفين لك',
          'view_all': 'عرض المزيد',
          'cat_names': {
            'plumber': 'سباكة',
            'Carpenter': 'نجارة',
            'Electrician': 'كهرباء',
            'Painter': 'دهان',
            'Cleaner': 'تنظيف',
            'Handyman': 'صيانة',
            'Landscaper': 'حدائق',
            'HVAC': 'تكييف'
          }
        };
      case 'ru':
        return {
          'welcome': 'Привет,',
          'find_pros': 'Какая услуга вам нужна сегодня?',
          'search_hint': 'Найти профессионала...',
          'categories': 'Популярные категории',
          'see_all': 'Все',
          'top_rated': 'Лучшие специалисты',
          'view_all': 'Смотреть все',
          'cat_names': {
            'plumber': 'Сантехник',
            'Carpenter': 'Плотник',
            'Electrician': 'Электрик',
            'Painter': 'Маляр',
            'Cleaner': 'Уборка',
            'Handyman': 'Мастер на час',
            'Landscaper': 'Ландшафт',
            'HVAC': 'Кондиционеры'
          }
        };
      case 'am':
        return {
          'welcome': 'ጤና ይስጥልኝ፣',
          'find_pros': 'ዛሬ ምን ዓይነት አገልግሎት ይፈልጋሉ?',
          'search_hint': 'ባለሙያ ይፈልጉ...',
          'categories': 'ታዋቂ ዘርፎች',
          'see_all': 'ሁሉንም',
          'top_rated': 'ከፍተኛ ደረጃ የተሰጣቸው ባለሙያዎች',
          'view_all': 'ሁሉንም ይመልከቱ',
          'cat_names': {
            'plumber': 'ቧንቧ ሰራተኛ',
            'Carpenter': 'አናጺ',
            'Electrician': 'ኤሌክትሪሻን',
            'Painter': 'ቀለም ቀቢ',
            'Cleaner': 'ፅዳት',
            'Handyman': 'ጥገና',
            'Landscaper': 'አትክልተኛ',
            'HVAC': 'ኤሲ ጥገና'
          }
        };
      default:
        return {
          'welcome': 'Hello,',
          'find_pros': 'What service do you need today?',
          'search_hint': 'Search for a pro (e.g. Plumber)...',
          'categories': 'Popular Categories',
          'see_all': 'See all',
          'top_rated': 'Top Rated Professionals',
          'view_all': 'View all',
          'cat_names': {
            'plumber': 'Plumbing',
            'Carpenter': 'Carpentry',
            'Electrician': 'Electrical',
            'Painter': 'Painting',
            'Cleaner': 'Cleaning',
            'Handyman': 'Handyman',
            'Landscaper': 'Landscaping',
            'HVAC': 'HVAC'
          }
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final localized = _getLocalizedStrings(context);
    final theme = Theme.of(context);
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isRtl = locale == 'he' || locale == 'ar';
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
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategories(context, localized, theme),
                      const SizedBox(height: 8),
                      _buildTopRatedSection(context, localized, theme),
                      const SizedBox(height: 32),
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

  Widget _buildSliverAppBar(Map<String, dynamic> strings, ThemeData theme, User? user) {
    return SliverAppBar(
      expandedHeight: 250,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1976D2),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF1976D2)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.05)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${strings['welcome']} ${user?.displayName?.split(' ').first ?? ''}',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.waving_hand, color: Colors.amber, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings['find_pros'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage())),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                  const SizedBox(width: 12),
                  Text(
                    strings['search_hint'],
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategories(BuildContext context, Map<String, dynamic> strings, ThemeData theme) {
    final catNames = strings['cat_names'] as Map<String, String>;
    final List<Map<String, dynamic>> categories = [
      {'key': 'plumber', 'icon': Icons.plumbing_rounded, 'color': const Color(0xFFDBEAFE), 'iconColor': const Color(0xFF2563EB)},
      {'key': 'Carpenter', 'icon': Icons.handyman_rounded, 'color': const Color(0xFFFFEDD5), 'iconColor': const Color(0xFFEA580C)},
      {'key': 'Electrician', 'icon': Icons.bolt_rounded, 'color': const Color(0xFFFEF9C3), 'iconColor': const Color(0xFFCA8A04)},
      {'key': 'Painter', 'icon': Icons.format_paint_rounded, 'color': const Color(0xFFFCE7F3), 'iconColor': const Color(0xFFDB2777)},
      {'key': 'Cleaner', 'icon': Icons.auto_awesome_rounded, 'color': const Color(0xFFDCFCE7), 'iconColor': const Color(0xFF16A34A)},
      {'key': 'Handyman', 'icon': Icons.architecture_rounded, 'color': const Color(0xFFF3E8FF), 'iconColor': const Color(0xFF9333EA)},
      {'key': 'Landscaper', 'icon': Icons.park_rounded, 'color': const Color(0xFFD1FAE5), 'iconColor': const Color(0xFF059669)},
      {'key': 'HVAC', 'icon': Icons.air_rounded, 'color': const Color(0xFFCFFAFE), 'iconColor': const Color(0xFF0891B2)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings['categories'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage())),
                child: Text(strings['see_all'], style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final categoryName = catNames[cat['key']] ?? cat['key'];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SearchPage(initialTrade: categoryName))),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          color: cat['color'],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(cat['icon'], color: cat['iconColor'], size: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        categoryName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopRatedSection(BuildContext context, Map<String, dynamic> strings, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No pros available right now.", style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
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
