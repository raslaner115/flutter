import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:untitled1/language_provider.dart';
import 'package:untitled1/pages/ptofile.dart';

class SearchPage extends StatefulWidget {
  final String? initialTrade;
  const SearchPage({super.key, this.initialTrade});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  
  static const String _dbUrl = 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com';
  late final DatabaseReference _dbRef;

  List<Map<String, dynamic>> _allWorkers = [];
  List<Map<String, dynamic>> _filteredWorkers = [];
  bool _isLoading = true;
  String? _selectedTrade;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _dbRef = FirebaseDatabase.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseURL: _dbUrl
    ).ref();
    
    _selectedTrade = widget.initialTrade;
    _fetchWorkers();
  }

  Future<void> _fetchWorkers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await _dbRef.child('users').get();
      
      if (snapshot.exists && snapshot.value != null) {
        final dynamic rawData = snapshot.value;
        List<Map<String, dynamic>> workers = [];
        
        void processUser(String key, dynamic value) {
          if (value is Map) {
            final Map<String, dynamic> userData = {};
            value.forEach((k, v) => userData[k.toString()] = v);

            final String userType = userData['userType']?.toString() ?? '';
            final bool isSubscribed = userData['isSubscribed'] == true;

            if (userType == 'worker' && isSubscribed) {
              userData['uid'] = key;
              
              // Calculate ratings from nested reviews inside users/{uid}/reviews
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
        }

        if (rawData is Map) {
          rawData.forEach((key, value) => processUser(key.toString(), value));
        } else if (rawData is List) {
          for (int i = 0; i < rawData.length; i++) {
            if (rawData[i] != null) processUser(i.toString(), rawData[i]);
          }
        }

        if (mounted) {
          setState(() {
            _allWorkers = workers;
            _applyFilters();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("FETCH ERROR: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredWorkers = _allWorkers.where((worker) {
        bool matchesTrade = true;
        if (_selectedTrade != null) {
          List<String> workerProfessions = [];
          if (worker['professions'] is List) {
            workerProfessions = (worker['professions'] as List).map((e) => e.toString().toLowerCase()).toList();
          } else if (worker['profession'] != null) {
            workerProfessions = [worker['profession'].toString().toLowerCase()];
          }
          matchesTrade = workerProfessions.contains(_selectedTrade!.toLowerCase());
        }

        bool matchesSearch = true;
        if (_searchController.text.isNotEmpty) {
          final name = (worker['name'] ?? '').toString().toLowerCase();
          final town = (worker['town'] ?? '').toString().toLowerCase();
          matchesSearch = name.contains(_searchController.text.toLowerCase()) || 
                         town.contains(_searchController.text.toLowerCase());
        }

        return matchesTrade && matchesSearch;
      }).toList();
      
      // Default sort by rating
      _filteredWorkers.sort((a, b) => (b['avgRating'] as double).compareTo(a['avgRating'] as double));
    });
  }

  Map<String, dynamic> _getLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final tradeNames = {
      'Plumber': locale == 'he' ? 'אינסטלציה' : (locale == 'ar' ? 'سباكة' : 'Plumbing'),
      'Carpenter': locale == 'he' ? 'נגרות' : (locale == 'ar' ? 'نجارة' : 'Carpentry'),
      'Electrician': locale == 'he' ? 'חשמל' : (locale == 'ar' ? 'كهرباء' : 'Electrical'),
      'Painter': locale == 'he' ? 'צבע' : (locale == 'ar' ? 'دهان' : 'Painting'),
      'Cleaner': locale == 'he' ? 'ניקיון' : (locale == 'ar' ? 'تنظيف' : 'Cleaning'),
      'Handyman': locale == 'he' ? 'תיקונים' : (locale == 'ar' ? 'صيانة' : 'Handyman'),
      'Landscaper': locale == 'he' ? 'גינון' : (locale == 'ar' ? 'حدائق' : 'Landscaping'),
      'HVAC': locale == 'he' ? 'מיזוג' : (locale == 'ar' ? 'تكييف' : 'HVAC'),
    };

    switch (locale) {
      case 'he':
        return {
          'search': 'חפש מקצוען או עיר...',
          'filters': 'פילטרים',
          'trade': 'סוג שירות',
          'found': 'נמצאו ${_filteredWorkers.length} תוצאות',
          'no_results': 'לא נמצאו תוצאות לחיפוש שלך',
          'trades': tradeNames,
        };
      case 'ar':
        return {
          'search': 'ابحث عن محترف أو مدينة...',
          'filters': 'الفلاتر',
          'trade': 'نوع الخدمة',
          'found': 'تم العثور على ${_filteredWorkers.length} نتيجة',
          'no_results': 'لم يتم العثور على نتائج لبحثك',
          'trades': tradeNames,
        };
      default:
        return {
          'search': 'Search pro or city...',
          'filters': 'Filters',
          'trade': 'Service Type',
          'found': '${_filteredWorkers.length} results found',
          'no_results': 'No results found for your search',
          'trades': tradeNames,
        };
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localized = _getLocalizedStrings(context);
    final isRtl = Provider.of<LanguageProvider>(context).locale.languageCode == 'he' || 
                  Provider.of<LanguageProvider>(context).locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(localized['trade']!),
        ),
        body: Column(
          children: [
            _buildSearchHeader(localized, isRtl),
            if (_showFilters) _buildFilterPanel(localized),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredWorkers.isEmpty 
                  ? _buildEmptyState(localized)
                  : _buildResultsList(localized),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(Map<String, dynamic> strings, bool isRtl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1976D2),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => _applyFilters(),
                decoration: InputDecoration(
                  hintText: strings['search'],
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: _showFilters ? const Color(0xFF1E3A8A) : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(Map<String, dynamic> strings) {
    final tradeNames = strings['trades'] as Map<String, String>;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings['trade'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tradeNames.entries.map((e) {
              final isSelected = _selectedTrade == e.key;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTrade = isSelected ? null : e.key;
                    _applyFilters();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1976D2) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? const Color(0xFF1976D2) : Colors.transparent),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(Map<String, dynamic> strings) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredWorkers.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
            child: Text(strings['found'], style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          );
        }
        final worker = _filteredWorkers[index - 1];
        return _buildWorkerCard(worker);
      },
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => profile(userId: worker['uid']))),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'avatar_${worker['uid']}',
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: worker['profileImageUrl'] != null && worker['profileImageUrl'].toString().isNotEmpty
                      ? DecorationImage(image: NetworkImage(worker['profileImageUrl']), fit: BoxFit.cover)
                      : null,
                    color: const Color(0xFFF1F5F9),
                  ),
                  child: worker['profileImageUrl'] == null || worker['profileImageUrl'].toString().isEmpty
                    ? const Icon(Icons.person_rounded, size: 35, color: Color(0xFF94A3B8))
                    : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            worker['name'] ?? 'Worker',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFCA8A04), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                (worker['avgRating'] as double).toStringAsFixed(1),
                                style: const TextStyle(color: Color(0xFFCA8A04), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getProfessionsList(worker).join(', '),
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
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
      ),
    );
  }

  List<String> _getProfessionsList(Map<String, dynamic> worker) {
    if (worker['professions'] is List) {
      return (worker['professions'] as List).map((e) => e.toString()).toList();
    } else if (worker['profession'] != null) {
      return [worker['profession'].toString()];
    }
    return [];
  }

  Widget _buildEmptyState(Map<String, dynamic> strings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(strings['no_results'], textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
