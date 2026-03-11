import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/language_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AveragePricesPage extends StatefulWidget {
  final String? initialProfession;
  final String? proPhoneNumber;
  final String? proName;

  const AveragePricesPage({
    super.key, 
    this.initialProfession, 
    this.proPhoneNumber, 
    this.proName
  });

  @override
  State<AveragePricesPage> createState() => _AveragePricesPageState();
}

class _AveragePricesPageState extends State<AveragePricesPage> {
  String _searchQuery = "";
  late String? _currentProfessionKey;

  @override
  void initState() {
    super.initState();
    _currentProfessionKey = _mapProfessionToKey(widget.initialProfession);
  }

  String? _mapProfessionToKey(String? name) {
    if (name == null) return null;
    final lowerName = name.toLowerCase();
    if (lowerName.contains('electrician') || lowerName.contains('חשמלאי') || lowerName.contains('كهربائي')) return 'electrician';
    if (lowerName.contains('plumber') || lowerName.contains('אינסטלטור') || lowerName.contains('سباك')) return 'plumber';
    if (lowerName.contains('painter') || lowerName.contains('צבעי') || lowerName.contains('دهان')) return 'painter';
    if (lowerName.contains('carpenter') || lowerName.contains('נגר') || lowerName.contains('نجار')) return 'carpenter';
    if (lowerName.contains('ac') || lowerName.contains('מזגנים') || lowerName.contains('تكييف')) return 'ac_technician';
    if (lowerName.contains('locksmith') || lowerName.contains('מנעולן') || lowerName.contains('أقفال')) return 'locksmith';
    if (lowerName.contains('cleaner') || lowerName.contains('ניקיון') || lowerName.contains('تنظيف')) return 'cleaner';
    return null;
  }

  Map<String, dynamic> _getProfessionData(String locale) {
    final isHe = locale == 'he';
    final isAr = locale == 'ar';

    return {
      'electrician': {
        'name': isHe ? 'חשמלאי' : (isAr ? 'كهربائي' : 'Electrician'),
        'icon': Icons.bolt_rounded,
        'color': Colors.amber,
        'tasks': [
          {
            'task': isHe ? 'התקנת שקע' : (isAr ? 'تركيب مقبس' : 'Socket Installation'),
            'price': '150 - 300 ₪',
            'time': isHe ? '30 - 60 דק\'' : (isAr ? '30 - 60 دقيقة' : '30 - 60 min')
          },
          {
            'task': isHe ? 'החלפת מפסק פחת' : (isAr ? 'استبدال قاطع الدائرة' : 'Circuit Breaker Replacement'),
            'price': '250 - 500 ₪',
            'time': isHe ? '45 - 90 דק\'' : (isAr ? '45 - 90 دقيقة' : '45 - 90 min')
          },
          {
            'task': isHe ? 'התקנת מאוורר תקרה' : (isAr ? 'تركيب مروحة سقف' : 'Ceiling Fan Installation'),
            'price': '300 - 600 ₪',
            'time': isHe ? '1 - 2 שעות' : (isAr ? '1 - 2 ساعة' : '1 - 2 hours')
          },
          {
            'task': isHe ? 'בדיקת הארקה' : (isAr ? 'فحص التأريض' : 'Earthing Check'),
            'price': '400 - 800 ₪',
            'time': isHe ? '2 - 3 שעות' : (isAr ? '2 - 3 ساعات' : '2 - 3 hours')
          },
        ]
      },
      'plumber': {
        'name': isHe ? 'אינסטלטור' : (isAr ? 'سباك' : 'Plumber'),
        'icon': Icons.water_drop_rounded,
        'color': Colors.blue,
        'tasks': [
          {
            'task': isHe ? 'פתיחת סתימה' : (isAr ? 'تسليك مجاري' : 'Unclogging Drain'),
            'price': '250 - 450 ₪',
            'time': isHe ? '30 - 60 דק\'' : (isAr ? '30 - 60 دقيقة' : '30 - 60 min')
          },
          {
            'task': isHe ? 'החלפת ברז' : (isAr ? 'استبدال صنبور' : 'Faucet Replacement'),
            'price': '300 - 550 ₪',
            'time': isHe ? '45 - 90 דק\'' : (isAr ? '45 - 90 دقيقة' : '45 - 90 min')
          },
          {
            'task': isHe ? 'תיקון ניאגרה' : (isAr ? 'إصلاح صندوق الطرد' : 'Toilet Flush Repair'),
            'price': '250 - 500 ₪',
            'time': isHe ? 'שעה אחת' : (isAr ? 'ساعة واحدة' : '1 hour')
          },
        ]
      },
      'painter': {
        'name': isHe ? 'צבעי' : (isAr ? 'دهان' : 'Painter'),
        'icon': Icons.format_paint_rounded,
        'color': Colors.deepOrange,
        'tasks': [
          {
            'task': isHe ? 'צביעת חדר' : (isAr ? 'دهان غرفة' : 'Room Painting'),
            'price': '800 - 1500 ₪',
            'time': isHe ? 'יום אחד' : (isAr ? 'يوم واحد' : '1 day')
          },
          {
            'task': isHe ? 'תיקוני שפכטל' : (isAr ? 'إصلاحات المعجون' : 'Wall Patching'),
            'price': '150 - 350 ₪',
            'time': isHe ? '1 - 2 שעות' : (isAr ? '1 - 2 ساعة' : '1 - 2 hours')
          },
        ]
      },
      'carpenter': {
        'name': isHe ? 'נגר' : (isAr ? 'نجار' : 'Carpenter'),
        'icon': Icons.handyman_rounded,
        'color': Colors.brown,
        'tasks': [
          {
            'task': isHe ? 'תיקון ציר ארון' : (isAr ? 'إصلاح مفصلة خزانة' : 'Cabinet Hinge Repair'),
            'price': '150 - 300 ₪',
            'time': isHe ? '30 - 60 דק\'' : (isAr ? '30 - 60 دقيقة' : '30 - 60 min')
          },
          {
            'task': isHe ? 'הרכבת רהיטים' : (isAr ? 'تجميع أثاث' : 'Furniture Assembly'),
            'price': '250 - 600 ₪',
            'time': isHe ? '1 - 3 שעות' : (isAr ? '1 - 3 ساعات' : '1 - 3 hours')
          },
        ]
      },
      'ac_technician': {
        'name': isHe ? 'טכנאי מזגנים' : (isAr ? 'فني تكييف' : 'AC Technician'),
        'icon': Icons.ac_unit_rounded,
        'color': Colors.cyan,
        'tasks': [
          {
            'task': isHe ? 'ניקוי מזגן' : (isAr ? 'تنظيف مكيف' : 'AC Cleaning'),
            'price': '250 - 450 ₪',
            'time': isHe ? 'שעה אחת' : (isAr ? 'ساعة واحدة' : '1 hour')
          },
          {
            'task': isHe ? 'מילוי גז' : (isAr ? 'تعبئة غاز' : 'Gas Refill'),
            'price': '350 - 600 ₪',
            'time': isHe ? 'שעה אחת' : (isAr ? 'ساعة واحدة' : '1 hour')
          },
        ]
      },
      'locksmith': {
        'name': isHe ? 'מנעולן' : (isAr ? 'فني أقفال' : 'Locksmith'),
        'icon': Icons.vpn_key_rounded,
        'color': Colors.grey,
        'tasks': [
          {
            'task': isHe ? 'פריצת דלת' : (isAr ? 'فتح باب مقفل' : 'Door Unlocking'),
            'price': '250 - 500 ₪',
            'time': isHe ? '30 - 60 דק\'' : (isAr ? '30 - 60 دقيقة' : '30 - 60 min')
          },
          {
            'task': isHe ? 'החלפת צילינדר' : (isAr ? 'استبدال أسطوانة القفل' : 'Cylinder Replacement'),
            'price': '300 - 700 ₪',
            'time': isHe ? '1 - 2 שעות' : (isAr ? '1 - 2 ساعة' : '1 - 2 hours')
          },
        ]
      },
      'cleaner': {
        'name': isHe ? 'ניקיון' : (isAr ? 'عامل نظافة' : 'Cleaner'),
        'icon': Icons.cleaning_services_rounded,
        'color': Colors.lightBlue,
        'tasks': [
          {
            'task': isHe ? 'ניקיון דירה' : (isAr ? 'تنظيف شقة' : 'Apartment Cleaning'),
            'price': '400 - 1000 ₪',
            'time': isHe ? '4 - 8 שעות' : (isAr ? '4 - 8 ساعات' : '4 - 8 hours')
          },
          {
            'task': isHe ? 'ניקוי חלונות' : (isAr ? 'تنظيف نوافذ' : 'Window Cleaning'),
            'price': '200 - 500 ₪',
            'time': isHe ? '2 - 4 שעות' : (isAr ? '2 - 4 ساعات' : '2 - 4 hours')
          },
        ]
      },
    };
  }

  Map<String, String> _getLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'title': 'מחירון שירותים',
          'subtitle': 'הערכת מחירים וזמנים ממוצעים',
          'search_hint': 'חפש סוג שירות...',
          'price_label': 'מחיר משוער',
          'time_label': 'זמן עבודה',
          'no_results': 'לא נמצאו תוצאות',
          'tasks_listed': 'שירותים רשומים',
          'back': 'חזור',
          'call_pro': 'התקשר לבעל מקצוע',
          'call_specific': 'התקשר ל',
        };
      case 'ar':
        return {
          'title': 'دليل الأسعار',
          'subtitle': 'تقديرات الأسعار والأوقات المتوسطة',
          'search_hint': 'ابحث عن خدمة...',
          'price_label': 'السعر التقديري',
          'time_label': 'وقت العمل',
          'no_results': 'لم يتم العثور على نتائج',
          'tasks_listed': 'خدمات مدرجة',
          'back': 'عودة',
          'call_pro': 'اتصل بالمحترف',
          'call_specific': 'اتصل بـ',
        };
      default:
        return {
          'title': 'Price Guide',
          'subtitle': 'Average price and time estimates',
          'search_hint': 'Search for a service...',
          'price_label': 'Estimated Price',
          'time_label': 'Working Time',
          'no_results': 'No results found',
          'tasks_listed': 'tasks listed',
          'back': 'Back',
          'call_pro': 'Call a Pro',
          'call_specific': 'Call ',
        };
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isRtl = locale == 'he' || locale == 'ar';
    final data = _getProfessionData(locale);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(strings['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: _currentProfessionKey != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => setState(() => _currentProfessionKey = null),
                )
              : null,
        ),
        body: Column(
          children: [
            if (_currentProfessionKey == null) _buildHeader(strings),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _currentProfessionKey != null
                    ? _buildDetailsView(_currentProfessionKey!, data[_currentProfessionKey], strings)
                    : _buildProfessionsList(data, strings),
              ),
            ),
          ],
        ),
        floatingActionButton: widget.proPhoneNumber != null && widget.proPhoneNumber!.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () => _makePhoneCall(widget.proPhoneNumber!),
                backgroundColor: const Color(0xFF22C55E),
                icon: const Icon(Icons.call, color: Colors.white),
                label: Text(
                  widget.proName != null 
                      ? "${strings['call_specific']}${widget.proName}"
                      : strings['call_pro']!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildHeader(Map<String, String> strings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1976D2),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings['subtitle']!, style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: strings['search_hint'],
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                icon: const Icon(Icons.search_rounded, color: Color(0xFF1976D2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionsList(Map<String, dynamic> data, Map<String, String> strings) {
    final filteredProfessions = data.entries.where((entry) {
      final name = entry.value['name'].toString().toLowerCase();
      final key = entry.key.toLowerCase();
      return name.contains(_searchQuery) || key.contains(_searchQuery);
    }).toList();

    if (filteredProfessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE2E8F0))),
              child: const Icon(Icons.search_off_rounded, size: 64, color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 24),
            Text(strings['no_results']!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: filteredProfessions.length,
      itemBuilder: (context, index) {
        final entry = filteredProfessions[index];
        final key = entry.key;
        final prof = entry.value;
        final Color themeColor = prof['color'] ?? const Color(0xFF1976D2);

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: themeColor.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _currentProfessionKey = key),
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(prof['icon'] as IconData, color: themeColor, size: 32),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prof['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1E293B))),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.list_alt_rounded, size: 14, color: themeColor.withOpacity(0.6)),
                              const SizedBox(width: 6),
                              Text("${prof['tasks'].length} ${strings['tasks_listed']}", style: TextStyle(color: themeColor.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: themeColor.withOpacity(0.3), size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsView(String key, dynamic prof, Map<String, String> strings) {
    final List<dynamic> tasks = prof['tasks'];
    final Color themeColor = prof['color'] ?? const Color(0xFF1976D2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: themeColor,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(prof['icon'] as IconData, color: Colors.white, size: 40),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prof['name'].toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(strings['subtitle']!, style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task['task']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildInfoItem(Icons.payments_rounded, strings['price_label']!, task['price']!, Colors.green),
                        const SizedBox(width: 16),
                        _buildInfoItem(Icons.timer_rounded, strings['time_label']!, task['time']!, Colors.blue),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
          ],
        ),
      ),
    );
  }
}
