import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' as intl;

class AnalyticsPage extends StatefulWidget {
  final String userId;
  final Map<String, String> strings;

  const AnalyticsPage({
    super.key,
    required this.userId,
    required this.strings,
  });

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _isLoading = true;
  int _totalJobs = 0;
  int _profileViews = 0;
  double _totalEarnings = 0.0;
  double _avgRating = 0.0;
  
  double _avgPrice = 0.0;
  double _avgService = 0.0;
  double _avgTiming = 0.0;
  
  List<FlSpot> _earningsSpots = [];
  List<BarChartGroupData> _viewGroups = [];
  
  String _performanceOverview = "";
  String _topServices = "";
  double _conversionRate = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;
        _totalJobs = data['totalJobs'] ?? 0;
        _profileViews = data['profileViews'] ?? 0;
        _totalEarnings = (data['totalEarnings'] ?? 0.0).toDouble();
        _avgRating = (data['avgRating'] ?? 0.0).toDouble();
      }

      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('reviews')
          .get();
      
      if (_totalJobs == 0) {
        _totalJobs = reviewsSnapshot.docs.length;
      }

      Map<String, int> professionCounts = {};
      double sumPrice = 0, sumService = 0, sumTiming = 0;
      int countPrice = 0, countService = 0, countTiming = 0;

      for (var doc in reviewsSnapshot.docs) {
        final r = doc.data();
        String? prof = r['profession'];
        if (prof != null) {
          professionCounts[prof] = (professionCounts[prof] ?? 0) + 1;
        }
        
        if (r['starsPrice'] != null) { sumPrice += (r['starsPrice'] as num).toDouble(); countPrice++; }
        if (r['starsService'] != null) { sumService += (r['starsService'] as num).toDouble(); countService++; }
        if (r['starsTiming'] != null) { sumTiming += (r['starsTiming'] as num).toDouble(); countTiming++; }
      }

      _avgPrice = countPrice > 0 ? sumPrice / countPrice : 0.0;
      _avgService = countService > 0 ? sumService / countService : 0.0;
      _avgTiming = countTiming > 0 ? sumTiming / countTiming : 0.0;

      if (professionCounts.isNotEmpty) {
        var sortedProfs = professionCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        _topServices = sortedProfs.first.key;
      } else {
        _topServices = widget.strings['no_reviews'] ?? "No data";
      }

      if (_profileViews > 0) {
        _conversionRate = (_totalJobs / _profileViews) * 100;
      } else {
        _conversionRate = 0.0;
      }

      // Logic for overview
      if (_conversionRate > 20) {
        _performanceOverview = "Excellent conversion! Your profile is highly effective at turning views into jobs.";
      } else if (_profileViews > 20 && _conversionRate < 5) {
        _performanceOverview = "High visibility but low conversion. Consider updating your profile photo or bio.";
      } else if (_totalJobs < 3) {
        _performanceOverview = "Welcome! Focus on completing more jobs to build your analytics history.";
      } else {
        _performanceOverview = "Consistent performance. Try asking happy customers for reviews to boost your rating.";
      }

      _generateChartData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Analytics Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _generateChartData() {
    double base = _totalEarnings / 7;
    _earningsSpots = List.generate(7, (i) {
      return FlSpot(i.toDouble(), (base * (i + 0.5) * (0.8 + (i % 3) * 0.1)).clamp(0, _totalEarnings * 1.5));
    });

    double baseViews = _profileViews / 7;
    _viewGroups = List.generate(7, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (baseViews * (0.7 + (i % 5) * 0.15)).clamp(1, _profileViews.toDouble() + 5),
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
            width: 14,
            borderRadius: BorderRadius.circular(4),
          )
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _totalJobs == 0) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.strings['analytics_title'] ?? 'Business Dashboard', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAnalytics,
        color: const Color(0xFF1976D2),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMainBalanceCard(),
              const SizedBox(height: 24),
              _buildMetricsGrid(),
              const SizedBox(height: 32),
              _buildChartCard("Earnings Trend (Last 7 Days)", _buildEarningsChart(), const Color(0xFF3B82F6)),
              const SizedBox(height: 24),
              _buildChartCard("Profile Reach", _buildViewsChart(), const Color(0xFFF59E0B)),
              const SizedBox(height: 32),
              _buildSectionHeader("Service Quality Breakdown"),
              const SizedBox(height: 16),
              _buildRatingsSection(),
              const SizedBox(height: 32),
              _buildAITipCard(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)));
  }

  Widget _buildMainBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.strings['total_earnings'] ?? 'Estimated Earnings', style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.bold)),
              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white30),
            ],
          ),
          const SizedBox(height: 12),
          Text("₪${intl.NumberFormat('#,###').format(_totalEarnings)}", style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickStat(widget.strings['total_jobs'] ?? 'Jobs', _totalJobs.toString(), Icons.check_circle_outline),
              _buildQuickStat('Rating', _avgRating.toStringAsFixed(1), Icons.star_border_rounded),
              _buildQuickStat('Views', _profileViews.toString(), Icons.bar_chart_rounded),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: Colors.blueAccent, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return Row(
      children: [
        Expanded(child: _buildInfoTile("Conversion", "${_conversionRate.toStringAsFixed(1)}%", Icons.swap_calls_rounded, Colors.teal)),
        const SizedBox(width: 16),
        Expanded(child: _buildInfoTile("Top Skill", _topServices, Icons.auto_graph_rounded, Colors.indigo)),
      ],
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
          const SizedBox(height: 24),
          SizedBox(height: 180, child: chart),
        ],
      ),
    );
  }

  Widget _buildRatingsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          _buildRatingProgress(widget.strings['price'] ?? "Price", _avgPrice, Colors.amber),
          const SizedBox(height: 20),
          _buildRatingProgress(widget.strings['service'] ?? "Service", _avgService, Colors.blueAccent),
          const SizedBox(height: 20),
          _buildRatingProgress(widget.strings['timing'] ?? "Timing", _avgTiming, Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildRatingProgress(String label, double value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(value.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (value / 5.0).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildAITipCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Growth Recommendation", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text(_performanceOverview, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEarningsChart() {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _earningsSpots,
            isCurved: true,
            gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)]),
            barWidth: 6,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(colors: [const Color(0xFF3B82F6).withOpacity(0.3), const Color(0xFF3B82F6).withOpacity(0)]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewsChart() {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: _viewGroups,
      ),
    );
  }
}
