import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SubscriptionAccessState {
  final String role;
  final bool isSubscribed;
  final String subscriptionStatus;

  const SubscriptionAccessState({
    required this.role,
    required this.isSubscribed,
    required this.subscriptionStatus,
  });

  bool get isWorker => role == 'worker';

  bool get hasActiveWorkerSubscription {
    if (!isWorker) return true;
    // Keep access when a user is marked subscribed even if status is stale.
    return isSubscribed;
  }

  bool get isUnsubscribedWorker => isWorker && !hasActiveWorkerSubscription;
}

class SubscriptionAccessService {
  static bool hasActiveWorkerSubscriptionFromData(Map<String, dynamic>? data) {
    final role = (data?['role'] ?? 'customer').toString().toLowerCase();
    if (role != 'worker') return true;

    final isSubscribed = data?['isSubscribed'] == true;
    return isSubscribed;
  }

  static Future<SubscriptionAccessState> getCurrentUserState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SubscriptionAccessState(
        role: 'guest',
        isSubscribed: false,
        subscriptionStatus: 'inactive',
      );
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? <String, dynamic>{};
    final isSubscribed = data['isSubscribed'] == true;

    return SubscriptionAccessState(
      role: (data['role'] ?? 'customer').toString().toLowerCase(),
      isSubscribed: isSubscribed,
      subscriptionStatus:
          data['subscriptionStatus']?.toString().toLowerCase() ??
          (isSubscribed ? 'active' : 'inactive'),
    );
  }

  static Scaffold buildLockedScaffold({
    required String title,
    required String message,
  }) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1976D2),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 72,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
