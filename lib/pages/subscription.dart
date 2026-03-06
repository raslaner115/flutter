import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:untitled1/pages/complete_worker_profile.dart';

class SubscriptionPage extends StatefulWidget {
  final String email;
  const SubscriptionPage({Key? key, required this.email}) : super(key: key);

  @override 
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isLoading = true;

  // IMPORTANT: This ID must match exactly the Product ID you created in 
  // Google Play Console and App Store Connect.
  static const String _proProductId = 'pro_worker_monthly'; 

  @override
  void initState() {
    super.initState();
    
    // 1. Listen to purchase updates
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint("Purchase Stream Error: $error");
    });

    // 2. Initialize store information
    _initStoreInfo();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isLoading = false;
        _products = [];
      });
      return;
    }

    const Set<String> _kIds = <String>{_proProductId};
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds);

    if (response.error != null || response.productDetails.isEmpty) {
      debugPrint("Store Error or No Products found: ${response.error?.message}");
      setState(() {
        _isLoading = false;
        _products = [];
      });
      return;
    }

    setState(() {
      _products = response.productDetails;
      _isLoading = false;
    });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show loading if needed
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint("Purchase Error: ${purchaseDetails.error}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Purchase failed: ${purchaseDetails.error?.message}")),
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          // If the product ID matches our pro plan, update Firebase
          if (purchaseDetails.productID == _proProductId) {
            String? userType = await _updateUserProStatus(true);
            
            // Only show the success dialog for a fresh purchase
            if (purchaseDetails.status == PurchaseStatus.purchased) {
              _showSuccessDialog(userType == 'normal');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Subscription status restored successfully!")),
              );
              if (mounted) Navigator.pop(context, true);
            }
          }
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
           // User closed the payment sheet without buying
           debugPrint("Purchase Canceled by User");
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    });
  }

  void _buySubscription() {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subscription product not found in the store.")),
      );
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: _products.first);
    
    // buyNonConsumable is used for subscriptions
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Updates the user's Pro status in Firebase.
  /// Returns the current userType ('normal' or 'worker')
  Future<String?> _updateUserProStatus(bool isPro) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final dbRef = FirebaseDatabase.instanceFor(
          app: FirebaseAuth.instance.app,
          databaseURL: 'https://profis-60aaa-default-rtdb.europe-west1.firebasedatabase.app'
      ).ref();

      final snapshot = await dbRef.child('users').child(currentUser.uid).get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final String userType = data['userType'] ?? 'normal';

        // If user is already a worker, we update isSubscribed and isPro immediately
        if (userType == 'worker') {
          await dbRef.child('users').child(currentUser.uid).update({
            'isPro': isPro,
            'isSubscribed': isPro,
            'subscriptionDate': ServerValue.timestamp,
            'lastStatusCheck': ServerValue.timestamp,
          });
        }
        // If userType is 'normal', we wait for them to complete the worker profile 
        // which will set userType to 'worker' and isSubscribed to true.
        // But we can set isPro: true now if we want, or handle it all in the profile page.
        
        return userType;
      }
    }
    return null;
  }

  void _showSuccessDialog(bool shouldCompleteProfile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success!'),
        content: Text(shouldCompleteProfile 
          ? 'Subscription confirmed. Please complete your professional profile to start working!'
          : 'Subscription confirmed. You are now a Pro Worker!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              if (shouldCompleteProfile) {
                // Navigate to complete profile page
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const CompleteWorkerProfilePage()),
                ).then((value) {
                  if (mounted) Navigator.pop(context, true);
                });
              } else {
                Navigator.pop(context, true); // Return to previous screen
              }
            },
            child: const Text('Let\'s Go!'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pro Subscription'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSubscriptionCard(),
            const SizedBox(height: 32),
            const Text(
              'Select Subscription',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              ElevatedButton(
                onPressed: _buySubscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(
                  _products.isNotEmpty 
                    ? 'Subscribe Now - ${_products.first.price}' 
                    : 'Subscription Unavailable',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              
              // This button is critical for when a user cancels then re-subscribes,
              // or moves to a new device.
              TextButton.icon(
                onPressed: () async {
                  await _inAppPurchase.restorePurchases();
                },
                icon: const Icon(Icons.sync),
                label: const Text("Restore / Sync Subscription Status"),
              ),
            ],

            const SizedBox(height: 24),
            Text(
              'Securely managed by ${Platform.isAndroid ? 'Google Play' : 'Apple App Store'}. Your subscription will renew automatically.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        children: [
          Text(
            'PRO WORKER PLAN',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          SizedBox(height: 12),
          Text(
            '100 ₪ / Month',
            style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 24),
          Divider(color: Colors.white24, thickness: 1),
          SizedBox(height: 20),
          _FeatureRow(text: 'Priority listing in search'),
          _FeatureRow(text: 'Unlimited customer leads'),
          _FeatureRow(text: 'Advanced profile analytics'),
          _FeatureRow(text: 'Pro Badge on your profile'),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}
