import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:untitled1/sighn_up.dart';


class SubscriptionPage extends StatefulWidget {
  final String email;
  final Map<String, dynamic>? pendingUserData;
  final File? pendingImage;
  final bool isNewRegistration;

  const SubscriptionPage({
    super.key,
    required this.email,
    this.pendingUserData,
    this.pendingImage,
    this.isNewRegistration = false,
  });

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isLoading = true;
  bool _isStoreAvailable = false;

  // We will query both IDs found in your Play Console screenshot
  static const String _proProductId = 'pro_worker_monthly';
  static const String _backwardsCompatibleId =
      'com-hirehub-app-pro-worker-monthly';

  @override
  void initState() {
    super.initState();

    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        debugPrint("Purchase Stream Error: $error");
      },
    );

    _initStoreInfo();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _initStoreInfo() async {
    setState(() => _isLoading = true);
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isLoading = false;
        _isStoreAvailable = false;
      });
      return;
    }

    // Querying both the Product ID and the Base Plan ID to ensure we find it
    const Set<String> kIds = <String>{_proProductId, _backwardsCompatibleId};
    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails(kIds);

    if (response.error != null) {
      debugPrint("Query Product Error: ${response.error}");
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint("IDs NOT FOUND IN STORE: ${response.notFoundIDs}");
    }

    setState(() {
      _products = response.productDetails;
      _isLoading = false;
      _isStoreAvailable = true;
    });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint("Purchase Error: ${purchaseDetails.error}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Purchase failed: ${purchaseDetails.error?.message}"),
          ),
        );
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        _completeSubscription();
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    });
  }

  Future<void> _completeSubscription() async {
    if (widget.isNewRegistration) {
      _showSuccessDialog(isNewReg: true);
    } else {
      setState(() => _isLoading = true);
      bool success = await _finalizeWorkerUpgrade();
      setState(() => _isLoading = false);
      if (success) _showSuccessDialog(isNewReg: false);
    }
  }

  Future<bool> _finalizeWorkerUpgrade() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final firestore = FirebaseFirestore.instance;
      
      // 1. Fetch current data from normal_users (if exists)
      final normalDoc = await firestore.collection('normal_users').doc(user.uid).get();
      Map<String, dynamic> baseData = normalDoc.exists ? (normalDoc.data() ?? {}) : {};

      // 2. Prepare worker data
      Map<String, dynamic> workerData = {
        ...baseData,
        'isPro': true,
        'isSubscribed': true,
        'subscriptionDate': FieldValue.serverTimestamp(),
        'isWorker': true,
        'isNormal': false,
        'isAdmin': false,
      };

      if (widget.pendingUserData != null) {
        workerData.addAll(widget.pendingUserData!);
      }

      if (widget.pendingImage != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
          'profile_pictures/${user.uid}.jpg',
        );
        await storageRef.putFile(widget.pendingImage!);
        workerData['profileImageUrl'] = await storageRef.getDownloadURL();
      }

      // 3. Atomic Migration using WriteBatch
      WriteBatch batch = firestore.batch();
      DocumentReference workerRef = firestore.collection('workers').doc(user.uid);
      DocumentReference normalRef = firestore.collection('normal_users').doc(user.uid);
      
      batch.set(workerRef, workerData, SetOptions(merge: true));
      batch.delete(normalRef);
      
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("Migration Error: $e");
      return false;
    }
  }

  void _buySubscription() {
    // FOR TESTING: Directly complete subscription bypassing real IAP
    _completeSubscription();
  }

  void _showSuccessDialog({required bool isNewReg}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text('You are now a Pro Worker!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isNewReg) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SignUpPage(
                      pendingWorkerData: widget.pendingUserData,
                      pendingWorkerImage: widget.pendingImage,
                      startAtStep: 1,
                    ),
                  ),
                  (route) => false,
                );
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Continue'),
          ),
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
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCard(),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _buySubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Subscribe Now (TEST MODE)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'PRO WORKER PLAN',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _products.isNotEmpty ? _products.first.price : '100 ₪ / Month',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(color: Colors.white24, height: 40),
          const Text(
            '• Priority Listing\n• Unlimited Leads\n• Pro Badge',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
