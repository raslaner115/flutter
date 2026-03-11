import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:untitled1/language_provider.dart';

class SchedulePage extends StatefulWidget {
  final String workerId;
  final String workerName;

  const SchedulePage({super.key, required this.workerId, required this.workerName});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot;
  bool _isLoading = false;

  final List<String> _allSlots = [
    '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00', '17:00'
  ];

  List<String> _bookedSlots = [];

  @override
  void initState() {
    super.initState();
    _fetchBookedSlots();
  }

  Future<void> _fetchBookedSlots() async {
    setState(() => _isLoading = true);
    final dateStr = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";
    
    try {
      final dbRef = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
      ).ref();

      final snapshot = await dbRef
          .child('schedules')
          .child(widget.workerId)
          .child(dateStr)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map;
        setState(() {
          _bookedSlots = data.keys.map((e) => e.toString()).toList();
        });
      } else {
        setState(() => _bookedSlots = []);
      }
    } catch (e) {
      debugPrint("Error fetching slots: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, String> _getLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'title': 'קביעת תור',
          'select_date': 'בחר תאריך',
          'select_time': 'בחר שעה',
          'book_now': 'הזמן עכשיו',
          'success': 'התור נקבע בהצלחה!',
          'error': 'שגיאה בקביעת התור',
          'booked': 'תפוס',
          'available': 'פנוי',
          'guest_msg': 'עליך להירשם כדי לקבוע תור',
          'summary': 'סיכום הזמנה',
          'worker': 'בעל מקצוע',
          'date': 'תאריך',
          'time': 'שעה',
        };
      default:
        return {
          'title': 'Schedule Appointment',
          'select_date': 'Select Date',
          'select_time': 'Select Time Slot',
          'book_now': 'Book Appointment',
          'success': 'Appointment booked successfully!',
          'error': 'Error booking appointment',
          'booked': 'Booked',
          'available': 'Available',
          'guest_msg': 'You must sign up to book an appointment',
          'summary': 'Booking Summary',
          'worker': 'Professional',
          'date': 'Date',
          'time': 'Time',
        };
    }
  }

  Future<void> _bookAppointment() async {
    if (_selectedSlot == null) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      final strings = _getLocalizedStrings(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings['guest_msg']!)));
      return;
    }

    setState(() => _isLoading = true);
    final dateStr = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";
    final strings = _getLocalizedStrings(context);

    try {
      final dbRef = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
      ).ref();

      // 1. Add to worker's schedule
      await dbRef.child('schedules').child(widget.workerId).child(dateStr).child(_selectedSlot!).set({
        'userId': user.uid,
        'userName': user.displayName ?? 'Client',
        'timestamp': ServerValue.timestamp,
      });

      // 2. Add to user's appointments
      await dbRef.child('appointments').child(user.uid).push().set({
        'workerId': widget.workerId,
        'workerName': widget.workerName,
        'date': dateStr,
        'time': _selectedSlot,
        'timestamp': ServerValue.timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(strings['success']!),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${strings['error']!}: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final isRtl = Provider.of<LanguageProvider>(context).locale.languageCode == 'he';

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
        ),
        body: Column(
          children: [
            _buildCalendarCard(strings),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _buildTimeSlotsSection(strings),
            ),
            _buildBookingSummary(strings),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard(Map<String, String> strings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1976D2),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings['select_date']!, style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF1976D2),
                        onPrimary: Colors.white,
                        onSurface: Color(0xFF1E293B),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                  _selectedSlot = null;
                });
                _fetchBookedSlots();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: Colors.white),
                  const SizedBox(width: 16),
                  Text(
                    "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                    style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotsSection(Map<String, String> strings) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(strings['select_time']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const Spacer(),
              _buildLegend(strings['available']!, Colors.green),
              const SizedBox(width: 12),
              _buildLegend(strings['booked']!, Colors.red),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _allSlots.length,
              itemBuilder: (context, index) {
                final slot = _allSlots[index];
                final isBooked = _bookedSlots.contains(slot);
                final isSelected = _selectedSlot == slot;

                return InkWell(
                  onTap: isBooked ? null : () => setState(() => _selectedSlot = slot),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isBooked 
                          ? Colors.red.withOpacity(0.05) 
                          : isSelected ? const Color(0xFF1976D2) : Colors.white,
                      border: Border.all(
                        color: isBooked 
                            ? Colors.red.withOpacity(0.1) 
                            : isSelected ? const Color(0xFF1976D2) : const Color(0xFFE2E8F0),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                    ),
                    child: Center(
                      child: Text(
                        slot,
                        style: TextStyle(
                          color: isBooked 
                              ? Colors.red[300] 
                              : isSelected ? Colors.white : const Color(0xFF475569),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBookingSummary(Map<String, String> strings) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedSlot != null) ...[
            _buildSummaryRow(strings['worker']!, widget.workerName),
            const SizedBox(height: 12),
            _buildSummaryRow(strings['date']!, "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
            const SizedBox(height: 12),
            _buildSummaryRow(strings['time']!, _selectedSlot!),
            const SizedBox(height: 24),
          ],
          ElevatedButton(
            onPressed: _selectedSlot == null || _isLoading ? null : _bookAppointment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(strings['book_now']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
      ],
    );
  }
}
