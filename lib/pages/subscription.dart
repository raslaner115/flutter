import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:untitled1/pages/complete_worker_profile.dart';
import 'package:untitled1/pages/sighn_up.dart';
import '../main.dart';

class SubscriptionPage extends StatefulWidget {
  final String email;
  final Map<String, dynamic>? pendingUserData;
  final File? pendingImage;
  final bool isNewRegistration;

  const SubscriptionPage({
    Key? key, 
    required this.email, 
    this.pendingUserData,
    this.pendingImage,
    this.isNewRegistration = false,
  }) : super(key: key);

  @override 
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isLoading = true;

  static const String _proProductId = 'pro_worker_monthly'; 

  @override
  void initState() {
    super.initState();
    
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint("Purchase Stream Error: $error");
    });

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
          
          if (purchaseDetails.productID == _proProductId) {
            if (widget.isNewRegistration) {
              // New user registration flow: Proceed to Phone Auth
              _showSuccessDialog(false, isNewReg: true);
            } else {
              // Existing user upgrade flow: Finalize DB update
              setState(() => _isLoading = true);
              bool success = await _finalizeWorkerUpgrade();
              setState(() => _isLoading = false);
              
              if (success) {
                _showSuccessDialog(false, isNewReg: false);
              }
            }
          }
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    });
  }

  Future<bool> _finalizeWorkerUpgrade() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final dbRef = FirebaseDatabase.instanceFor(
          app: FirebaseAuth.instance.app,
          databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
      ).ref();

      Map<String, dynamic> updateData = {
        'isPro': true,
        'isSubscribed': true,
        'subscriptionDate': ServerValue.timestamp,
        'lastStatusCheck': ServerValue.timestamp,
        'userType': 'worker',
      };
      
      if (widget.pendingUserData != null) {
        updateData.addAll(widget.pendingUserData!);
      }

      // Upload image if present (for existing user upgrade)
      if (widget.pendingImage != null) {
        final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/${user.uid}.jpg');
        await storageRef.putFile(widget.pendingImage!);
        updateData['profileImageUrl'] = await storageRef.getDownloadURL();
      }
      
      await dbRef.child('users').child(user.uid).update(updateData);
      return true;
    } catch (e) {
      debugPrint("Error finalizing upgrade: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving profile: $e")));
      return false;
    }
  }

  void _buySubscription() {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subscription product not found in the store.")),
      );
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: _products.first);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _showSuccessDialog(bool dummy, {required bool isNewReg}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Successful!'),
        content: Text(isNewReg 
          ? 'Payment confirmed. Now, let\'s verify your phone number to complete your profile.'
          : 'Subscription confirmed. You are now a Pro Worker!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              if (isNewReg) {
                // Return to SignUpPage to finish Phone Auth with the paid status
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage(
                    pendingWorkerData: widget.pendingUserData,
                    pendingWorkerImage: widget.pendingImage,
                    startAtStep: 1, // Step.phone
                  )),
                  (route) => false,
                );
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MyHomePage()),
                  (route) => false
                );
              }
            },
            child: const Text('Continue'),
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
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
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
                  : 'Subscribe Now - 100 ₪',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                await _inAppPurchase.restorePurchases();
              },
              icon: const Icon(Icons.sync),
              label: const Text("Restore / Sync Subscription Status"),
            ),
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
