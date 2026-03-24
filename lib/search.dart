import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:untitled1/services/language_provider.dart';
import 'package:untitled1/ptofile.dart';
import 'package:untitled1/pages/average_prices.dart';

class SearchPage extends StatefulWidget {
  final String? initialTrade;
  const SearchPage({super.key, this.initialTrade});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _allWorkers = [];
  List<Map<String, dynamic>> _filteredWorkers = [];
  List<Map<String, dynamic>> _professions = [];
  List<Map<String, dynamic>> _filteredProfessions = [];
  bool _isLoadingWorkers = false;
  bool _isLoadingProfessions = true;

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isFetchingMore = false;

  Map<String, dynamic>? _selectedProfession;
  bool _showWorkerList = false;
  String _sortBy = 'rating';
  Position? _currentPosition;
  bool _filterByRadius = false;
  bool _filterByVerified = false;
  DateTime? _filterByDate;

  final String _googleMapsApiKey = "AIzaSyCL9zie59-f_Hiyqj_dYtaMziReezcd6fU";
  Map<String, Map<String, dynamic>> _matrixDistances = {}; // UID -> { 'text': '1.2 km', 'value': 1200 }

  @override
  void initState() {
    super.initState();
    _loadProfessions();
    _getCurrentLocation(silent: true);
    
    _scrollController.addListener(() {
      // Trigger if user pulls 50 pixels past the end
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent + 50) {
        if (_hasMore && !_isFetchingMore && _showWorkerList) {
          _fetchWorkers();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfessions() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/profeissions.json',
      );
      final List<dynamic> data = json.decode(response);
      setState(() {
        _professions = data.cast<Map<String, dynamic>>();
        _filteredProfessions = _professions;
        _isLoadingProfessions = false;

        if (widget.initialTrade != null) {
          final initial = _professions.firstWhere(
            (p) =>
                p['en'].toString().toLowerCase() ==
                widget.initialTrade!.toLowerCase(),
            orElse: () => {},
          );
          if (initial.isNotEmpty) {
            _selectedProfession = initial;
            _showWorkerList = true;
            _fetchWorkers(isRefresh: true);
            _trackSearch(initial['en']);
          }
        }
      });
    } catch (e) {
      debugPrint("Error loading professions: $e");
      setState(() => _isLoadingProfessions = false);
    }
  }

  Future<void> _trackSearch(String professionEn) async {
    try {
      await _firestore.collection('metadata').doc('analytics').collection('professions').doc(professionEn).set({
        'searchCount': FieldValue.increment(1),
        'lastSearched': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Analytics error: $e");
    }
  }

  Future<void> _fetchWorkers({bool isRefresh = false}) async {
    if (!mounted) return;
    if (_isFetchingMore && !isRefresh) return;

    setState(() {
      if (isRefresh) {
        _allWorkers = [];
        _lastDocument = null;
        _hasMore = true;
        _isLoadingWorkers = true;
      } else {
        _isFetchingMore = true;
      }
    });

    try {
      Query query = _firestore
          .collection('users')
          .where('userType', isEqualTo: 'worker');

      if (_selectedProfession != null) {
        query = query.where('professions', arrayContains: _selectedProfession!['en']);
      }

      if (_sortBy == 'rating') {
        query = query.orderBy('avgRating', descending: true);
      } else {
        query = query.orderBy('name');
      }

      // Setting limit to 5 as requested
      query = query.limit(5);
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.length < 5) {
        _hasMore = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        
        final newWorkers = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['uid'] = doc.id;
          data['avgRating'] = (data['avgRating'] ?? 0.0).toDouble();
          data['reviewCount'] = data['reviewCount'] ?? 0;
          return data;
        }).toList();

        if (mounted) {
          setState(() {
            _allWorkers.addAll(newWorkers);
            _applyFilters();
            _isLoadingWorkers = false;
            _isFetchingMore = false;
          });

          if (_currentPosition != null) {
            _fetchMatrixDistances();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingWorkers = false;
            _isFetchingMore = false;
            _hasMore = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch Workers Error: $e");
      if (mounted) {
        setState(() {
          _isLoadingWorkers = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation({bool silent = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (silent) return;
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        if (!silent) {
           _sortBy = 'distance';
           _fetchWorkers(isRefresh: true);
        }
      });

      if (_allWorkers.isNotEmpty) {
        await _fetchMatrixDistances();
      }

      _applyFilters();
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  Future<void> _fetchMatrixDistances() async {
    if (_currentPosition == null || _allWorkers.isEmpty) return;

    List<Map<String, dynamic>> targets = _allWorkers.where((w) => !_matrixDistances.containsKey(w['uid'])).toList();

    if (targets.isEmpty) return;

    for (var i = 0; i < targets.length; i += 25) {
      final chunk = targets.skip(i).take(25).toList();
      final destinations = chunk.map((w) {
        double? lat = w['lat']?.toDouble();
        double? lng = w['lng']?.toDouble();
        if (lat != null && lng != null) return '$lat,$lng';
        return null;
      }).whereType<String>().join('|');

      if (destinations.isEmpty) continue;

      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/distancematrix/json'
          '?origins=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&destinations=$destinations'
          '&key=$_googleMapsApiKey'
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            final elements = data['rows'][0]['elements'];
            setState(() {
              for (var j = 0; j < chunk.length; j++) {
                if (elements[j]['status'] == 'OK') {
                  _matrixDistances[chunk[j]['uid']] = {
                    'text': elements[j]['distance']['text'],
                    'value': elements[j]['distance']['value'],
                  };
                }
              }
            });
            _applyFilters();
          }
        }
      } catch (e) {
        debugPrint("Matrix API Error: $e");
      }
    }
  }

  bool _isWorkerAvailable(Map<String, dynamic> w, DateTime date) {
    final disabledDays = List<int>.from(w['disabledDays'] ?? []);
    if (disabledDays.contains(date.weekday)) return false;

    final vacations = List<Map<String, dynamic>>.from(w['vacations'] ?? []);
    final d = DateTime(date.year, date.month, date.day);
    for (var v in vacations) {
      try {
        final startParts = v['start']!.split('-');
        final endParts = v['end']!.split('-');
        final start = DateTime(int.parse(startParts[0]), int.parse(startParts[1]), int.parse(startParts[2]));
        final end = DateTime(int.parse(endParts[0]), int.parse(endParts[1]), int.parse(endParts[2]));
        if (d.isAtSameMomentAs(start) || d.isAtSameMomentAs(end) || (d.isAfter(start) && d.isBefore(end))) {
          return false;
        }
      } catch (_) {}
    }

    return true;
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final locale = Provider.of<LanguageProvider>(
      context,
      listen: false,
    ).locale.languageCode;

    setState(() {
      if (_showWorkerList) {
        _filteredWorkers = _allWorkers.where((w) {
          final matchesSearch =
              query.isEmpty ||
              (w['name'] ?? '').toLowerCase().contains(query) ||
              (w['town'] ?? '').toLowerCase().contains(query);

          bool matchesRadius = true;
          if (_filterByRadius && _currentPosition != null) {
            double? radius = w['workRadius']?.toDouble();

            if (_matrixDistances.containsKey(w['uid'])) {
              int distanceMeters = _matrixDistances[w['uid']]!['value'];
              if (radius != null) {
                matchesRadius = distanceMeters <= radius;
              }
            } else {
              double? workerLat = w['workCenterLat']?.toDouble() ?? w['lat']?.toDouble();
              double? workerLng = w['workCenterLng']?.toDouble() ?? w['lng']?.toDouble();

              if (workerLat != null && workerLng != null && radius != null) {
                double distance = Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  workerLat,
                  workerLng,
                );
                matchesRadius = distance <= radius;
              }
            }
          }

          bool matchesVerified = true;
          if (_filterByVerified) {
            matchesVerified = (w['isIdVerified'] == true) || (w['isBusinessVerified'] == true);
          }

          bool matchesDate = true;
          if (_filterByDate != null) {
            matchesDate = _isWorkerAvailable(w, _filterByDate!);
          }

          return matchesSearch && matchesRadius && matchesVerified && matchesDate;
        }).toList();

        if (_sortBy == 'distance' && _currentPosition != null) {
          _filteredWorkers.sort((a, b) {
            if (_matrixDistances.containsKey(a['uid']) && _matrixDistances.containsKey(b['uid'])) {
               return (_matrixDistances[a['uid']]!['value'] as int)
                   .compareTo(_matrixDistances[b['uid']]!['value'] as int);
            }
            return 0;
          });
        }
      } else {
        _filteredProfessions = _professions.where((p) {
          final name = (p[locale] ?? p['en']).toString().toLowerCase();
          final enName = p['en'].toString().toLowerCase();
          return name.contains(query) || enName.contains(query);
        }).toList();
      }
    });
  }

  Color _getThemeColor() {
    if (_showWorkerList && _selectedProfession != null) {
      return _getColorFromHex(_selectedProfession!['color']);
    }
    return const Color(0xFF1E3A8A);
  }

  Color _getColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return const Color(0xFF1E3A8A);
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isRtl = locale == 'he' || locale == 'ar';
    final themeColor = _getThemeColor();

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: _showWorkerList
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () {
                    setState(() {
                      _showWorkerList = false;
                      _selectedProfession = null;
                      _searchController.clear();
                      _applyFilters();
                    });
                  },
                )
              : null,
          title: Text(
            _showWorkerList
                ? (_selectedProfession![locale] ?? _selectedProfession!['en'])
                : (locale == 'he' ? 'בחר מקצוע' : 'Choose Profession'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          actions: [
            if (_showWorkerList)
              IconButton(
                icon: const Icon(Icons.price_change_outlined),
                tooltip: locale == 'he' ? 'מחירון' : 'Price Guide',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AveragePricesPage(
                      initialProfession: _selectedProfession!['en'],
                    ),
                  ),
                ),
              ),
            if (_showWorkerList)
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => _showSortOptions(locale, themeColor),
              ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchHeader(locale, themeColor),
            if (_showWorkerList) _buildQuickFilters(locale, themeColor),
            Expanded(
              child: _showWorkerList
                  ? (_isLoadingWorkers && _allWorkers.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : _buildWorkerList(locale, themeColor))
                  : (_isLoadingProfessions
                        ? const Center(child: CircularProgressIndicator())
                        : _buildProfessionGrid(locale)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilters(String locale, Color themeColor) {
    final bool isHebrew = locale == 'he';
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: Text(isHebrew ? 'היום' : 'Today'),
            selected: _filterByDate != null && isSameDay(_filterByDate!, DateTime.now()),
            onSelected: (val) {
              setState(() => _filterByDate = val ? DateTime.now() : null);
              _applyFilters();
            },
            selectedColor: themeColor.withOpacity(0.2),
            checkmarkColor: themeColor,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(isHebrew ? 'סופ"ש' : 'Weekend'),
            selected: _filterByDate != null && (_filterByDate!.weekday == DateTime.friday || _filterByDate!.weekday == DateTime.saturday),
            onSelected: (val) {
              if (val) {
                DateTime now = DateTime.now();
                int daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;
                setState(() => _filterByDate = now.add(Duration(days: daysUntilFriday)));
              } else {
                setState(() => _filterByDate = null);
              }
              _applyFilters();
            },
            selectedColor: themeColor.withOpacity(0.2),
            checkmarkColor: themeColor,
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.calendar_month, size: 16),
            label: Text(_filterByDate == null 
                ? (isHebrew ? 'תאריך ספציפי' : 'Specific Date')
                : "${_filterByDate!.day}/${_filterByDate!.month}"),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _filterByDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _filterByDate = picked);
                _applyFilters();
              }
            },
            backgroundColor: _filterByDate != null ? themeColor.withOpacity(0.1) : null,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(isHebrew ? 'מאומתים בלבד' : 'Verified Only'),
            selected: _filterByVerified,
            onSelected: (val) {
              setState(() => _filterByVerified = val);
              _applyFilters();
            },
            selectedColor: themeColor.withOpacity(0.2),
            checkmarkColor: themeColor,
          ),
        ],
      ),
    );
  }

  bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Widget _buildSearchHeader(String locale, Color themeColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: themeColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => _applyFilters(),
        decoration: InputDecoration(
          hintText: _showWorkerList
              ? (locale == 'he'
                    ? 'חפש לפי שם או עיר...'
                    : 'Search by name or city...')
              : (locale == 'he' ? 'חפש מקצוע...' : 'Search profession...'),
          prefixIcon: Icon(Icons.search_rounded, color: themeColor),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildProfessionGrid(String locale) {
    if (_filteredProfessions.isEmpty) {
      return Center(
        child: Text(
          locale == 'he' ? 'לא נמצאו מקצועות' : 'No professions found',
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: _filteredProfessions.length,
      itemBuilder: (context, index) {
        final p = _filteredProfessions[index];
        final color = _getColorFromHex(p['color']);

        return InkWell(
          onTap: () {
            setState(() {
              _selectedProfession = p;
              _showWorkerList = true;
              _searchController.clear();
            });
            _fetchWorkers(isRefresh: true);
            _trackSearch(p['en']);
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getIcon(p['logo']), color: color, size: 32),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    p[locale] ?? p['en'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkerList(String locale, Color themeColor) {
    if (_filteredWorkers.isEmpty && !_isLoadingWorkers) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              locale == 'he'
                  ? 'אין עובדים זמינים כרגע'
                  : 'No available workers at the moment',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.all(16),
      itemCount: _filteredWorkers.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredWorkers.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isFetchingMore 
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      const Icon(Icons.arrow_upward, color: Colors.grey, size: 20),
                      Text(
                        locale == 'he' ? 'משוך למעלה לעוד' : 'Pull up to load more',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
            ),
          );
        }

        final w = _filteredWorkers[index];

        String distanceStr = "";
        if (_matrixDistances.containsKey(w['uid'])) {
          distanceStr = _matrixDistances[w['uid']]!['text'];
        } else if (_currentPosition != null && w['lat'] != null && w['lng'] != null) {
          double distance = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, w['lat'], w['lng']);
          if (distance < 1000) {
            distanceStr = "${distance.toStringAsFixed(0)}m";
          } else {
            distanceStr = "${(distance / 1000).toStringAsFixed(1)}km";
          }
        }

        final bool isIdVerified = w['isIdVerified'] ?? false;
        final bool isBusinessVerified = w['isBusinessVerified'] ?? false;
        final bool isInsured = w['isInsured'] ?? false;

        double displayRating = 0.0;
        int displayReviewCount = 0;
        bool isServiceSpecific = false;

        if (_selectedProfession != null) {
          String profKey = _selectedProfession!['en'];
          if (w['professionStats']?[profKey] != null) {
            displayRating = (w['professionStats'][profKey]['avg'] ?? 0.0).toDouble();
            displayReviewCount = w['professionStats'][profKey]['count'] ?? 0;
            isServiceSpecific = true;
          } else {
            displayRating = (w['avgRating'] as num).toDouble();
            displayReviewCount = w['reviewCount'] ?? 0;
          }
        } else {
          displayRating = (w['avgRating'] as num).toDouble();
          displayReviewCount = w['reviewCount'] ?? 0;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Hero(
              tag: w['uid'],
              child: CircleAvatar(
                radius: 30,
                backgroundImage:
                    w['profileImageUrl'] != null &&
                        w['profileImageUrl'].toString().isNotEmpty
                    ? NetworkImage(w['profileImageUrl'])
                    : null,
                backgroundColor: const Color(0xFFF1F5F9),
                child:
                    w['profileImageUrl'] == null ||
                        w['profileImageUrl'].toString().isEmpty
                    ? Icon(Icons.person, color: themeColor)
                    : null,
              ),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    w['name'] ?? 'Worker',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                if (isIdVerified) const Icon(Icons.assignment_ind, color: Colors.green, size: 14),
                if (isBusinessVerified) const Padding(padding: EdgeInsets.only(left: 2), child: Icon(Icons.business_center, color: Colors.orange, size: 14)),
                if (isInsured) const Padding(padding: EdgeInsets.only(left: 2), child: Icon(Icons.shield, color: Colors.blue, size: 14)),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        w['town'] ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (distanceStr.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        distanceStr,
                        style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ]
                  ],
                ),
              ],
            ),
            trailing: SizedBox(
              width: 90,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isServiceSpecific)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        locale == 'he' ? 'דירוג לשירות זה' : 'Rating for service',
                        style: TextStyle(fontSize: 8, color: themeColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          displayRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (displayReviewCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 1, right: 4),
                      child: Text(
                        "($displayReviewCount)",
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Profile(userId: w['uid']),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSortOptions(String locale, Color themeColor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(locale == 'he' ? 'סנן לפי רדיוס עבודה' : 'Filter by Work Radius'),
              subtitle: Text(locale == 'he' ? 'הצג רק עובדים שמגיעים אליך' : 'Show only workers who serve your area'),
              value: _filterByRadius,
              onChanged: (val) {
                setState(() => _filterByRadius = val);
                if (val && _currentPosition == null) {
                   _getCurrentLocation();
                } else {
                  _applyFilters();
                }
                Navigator.pop(context);
              },
              secondary: Icon(Icons.radar, color: themeColor),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.star_rounded, color: Colors.amber),
              title: Text(locale == 'he' ? 'דירוג' : 'Rating'),
              trailing: _sortBy == 'rating'
                  ? Icon(Icons.check_circle, color: themeColor)
                  : null,
              onTap: () {
                setState(() => _sortBy = 'rating');
                _fetchWorkers(isRefresh: true);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.my_location, color: themeColor),
              title: Text(locale == 'he' ? 'הכי קרוב אלי' : 'Nearest to Me'),
              trailing: _sortBy == 'distance' ? Icon(Icons.check_circle, color: themeColor) : null,
              onTap: () {
                Navigator.pop(context);
                _getCurrentLocation();
              },
            ),
            ListTile(
              leading: Icon(Icons.sort_by_alpha_rounded, color: themeColor),
              title: Text(locale == 'he' ? 'שם' : 'Name'),
              trailing: _sortBy == 'name'
                  ? Icon(Icons.check_circle, color: themeColor)
                  : null,
              onTap: () {
                setState(() => _sortBy = 'name');
                _fetchWorkers(isRefresh: true);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }


  IconData _getIcon(String? name) {
    switch (name) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical_services':
        return Icons.electrical_services;
      case 'carpenter':
        return Icons.carpenter;
      case 'format_paint':
        return Icons.format_paint;
      case 'vpn_key':
        return Icons.vpn_key;
      case 'park':
        return Icons.park;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'build':
        return Icons.build;
      case 'handyman':
        return Icons.handyman;
      case 'foundation':
        return Icons.foundation;
      case 'grid_view':
        return Icons.grid_view;
      case 'settings':
        return Icons.settings;
      case 'home_repair_service':
        return Icons.home_repair_service;
      case 'computer':
        return Icons.computer;
      case 'content_cut':
        return Icons.content_cut;
      case 'checkroom':
        return Icons.checkroom;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'pest_control':
        return Icons.pest_control;
      case 'solar_power':
        return Icons.solar_power;
      case 'chair':
        return Icons.chair;
      case 'format_shapes':
        return Icons.format_shapes;
      case 'architecture':
        return Icons.architecture;
      case 'school':
        return Icons.school;
      case 'child_care':
        return Icons.child_care;
      case 'photo_camera':
        return Icons.photo_camera;
      case 'music_note':
        return Icons.music_note;
      case 'face':
        return Icons.face;
      case 'medical_services':
        return Icons.medical_services;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'window':
        return Icons.window;
      case 'pool':
        return Icons.pool;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'pets':
        return Icons.pets;
      case 'home':
        return Icons.home;
      case 'waves':
        return Icons.waves;
      case 'dry_cleaning':
        return Icons.dry_cleaning;
      case 'event':
        return Icons.event;
      case 'restaurant':
        return Icons.restaurant;
      case 'security':
        return Icons.security;
      case 'delivery_dining':
        return Icons.delivery_dining;
      case 'local_car_wash':
        return Icons.local_car_wash;
      case 'spa':
        return Icons.spa;
      case 'restaurant_menu':
        return Icons.restaurant_menu;
      case 'flight':
        return Icons.flight;
      case 'real_estate_agent':
        return Icons.real_estate_agent;
      case 'gavel':
        return Icons.gavel;
      case 'calculate':
        return Icons.calculate;
      case 'translate':
        return Icons.translate;
      case 'format_color_fill':
        return Icons.format_color_fill;
      case 'square_foot':
        return Icons.square_foot;
      case 'videocam':
        return Icons.videocam;
      case 'public':
        return Icons.public;
      case 'psychology':
        return Icons.psychology;
      case 'add_a_photo':
        return Icons.add_a_photo;
      case 'flight_takeoff':
        return Icons.flight_takeoff;
      case 'piano':
        return Icons.piano;
      case 'language':
        return Icons.language;
      case 'functions':
        return Icons.functions;
      case 'science':
        return Icons.science;
      case 'biotech':
        return Icons.biotech;
      case 'eco':
        return Icons.eco;
      case 'history_edu':
        return Icons.history_edu;
      case 'palette':
        return Icons.palette;
      case 'pedal_bike':
        return Icons.pedal_bike;
      case 'engineering':
        return Icons.engineering;
      default:
        return Icons.work_rounded;
    }
  }
}
