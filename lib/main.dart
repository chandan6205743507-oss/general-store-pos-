import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase init fallback: $e');
  }
  runApp(VanikPosApp(firebaseReady: firebaseReady));
}

// ============================================================================
// COLOR PALETTE (EXACT VANIK WARM CREAM, OLIVE & EMERALD THEME)
// ============================================================================
class AppColors {
  static const Color bgCream = Color(0xFFFAF8F2);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color sandLight = Color(0xFFF2EFE6);
  static const Color sandMedium = Color(0xFFE5DFCE);
  static const Color sandBorder = Color(0xFFD6CEB8);
  static const Color oliveText = Color(0xFF5C5847);
  static const Color darkText = Color(0xFF23221D);
  static const Color mutedText = Color(0xFF7D7969);
  static const Color primaryGreen = Color(0xFF6E9E4B);
  static const Color darkGreen = Color(0xFF4E7A31);
  static const Color amberGold = Color(0xFFD28A1E);
  static const Color dangerRed = Color(0xFFD32F2F);
}

// ============================================================================
// DATA MODELS
// ============================================================================
class ProductItem {
  String id;
  String name;
  String barcode;
  bool isLoose;
  String unit; // 'piece' or 'kg'
  double buyPrice;
  double sellPrice;
  double stock;
  String imagePath;
  String imageBase64;
  bool isPending;
  int soldCount;

  ProductItem({
    required this.id,
    required this.name,
    this.barcode = '',
    this.isLoose = false,
    this.unit = 'piece',
    this.buyPrice = 0,
    required this.sellPrice,
    this.stock = 0,
    this.imagePath = '',
    this.imageBase64 = '',
    this.isPending = false,
    this.soldCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'barcode': barcode,
        'isLoose': isLoose,
        'unit': unit,
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'stock': stock,
        'imagePath': imagePath,
        'imageBase64': imageBase64,
        'isPending': isPending,
        'soldCount': soldCount,
      };

  factory ProductItem.fromMap(Map<String, dynamic> m) => ProductItem(
        id: m['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: m['name'] ?? 'Item',
        barcode: m['barcode'] ?? '',
        isLoose: m['isLoose'] ?? false,
        unit: m['unit'] ?? 'piece',
        buyPrice: (m['buyPrice'] ?? 0).toDouble(),
        sellPrice: (m['sellPrice'] ?? 0).toDouble(),
        stock: (m['stock'] ?? 0).toDouble(),
        imagePath: m['imagePath'] ?? '',
        imageBase64: m['imageBase64'] ?? '',
        isPending: m['isPending'] ?? false,
        soldCount: (m['soldCount'] ?? 0).toInt(),
      );
}

class CartItem {
  ProductItem product;
  double qty;
  double customTotal;

  CartItem({
    required this.product,
    required this.qty,
    required this.customTotal,
  });

  Map<String, dynamic> toMap() => {
        'productId': product.id,
        'name': product.name,
        'unit': product.unit,
        'isLoose': product.isLoose,
        'qty': qty,
        'buyPrice': product.buyPrice,
        'sellPrice': product.sellPrice,
        'total': customTotal,
        'imagePath': product.imagePath,
        'imageBase64': product.imageBase64,
      };
}

class BillRecord {
  String id;
  DateTime date;
  String paymentMode; // 'Online', 'Cash', 'Udhaar'
  String customerName;
  String customerPhone;
  double totalAmount;
  double totalProfit;
  List> items;

  BillRecord({
    required this.id,
    required this.date,
    required this.paymentMode,
    this.customerName = '',
    this.customerPhone = '',
    required this.totalAmount,
    required this.totalProfit,
    required this.items,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'paymentMode': paymentMode,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'totalAmount': totalAmount,
        'totalProfit': totalProfit,
        'items': items,
      };

  factory BillRecord.fromMap(Map<String, dynamic> m) => BillRecord(
        id: m['id'] ?? '',
        date: DateTime.tryParse(m['date'] ?? '') ?? DateTime.now(),
        paymentMode: m['paymentMode'] ?? 'Cash',
        customerName: m['customerName'] ?? '',
        customerPhone: m['customerPhone'] ?? '',
        totalAmount: (m['totalAmount'] ?? 0).toDouble(),
        totalProfit: (m['totalProfit'] ?? 0).toDouble(),
        items: List.from(m['items'] ?? []),
      );
}

class UdhaarEntry {
  String id;
  DateTime date;
  bool isPayment; // false = udhaar liya, true = jama kiya
  double amount;
  String note;
  List> items;

  UdhaarEntry({
    required this.id,
    required this.date,
    required this.isPayment,
    required this.amount,
    this.note = '',
    this.items = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'isPayment': isPayment,
        'amount': amount,
        'note': note,
        'items': items,
      };

  factory UdhaarEntry.fromMap(Map<String, dynamic> m) => UdhaarEntry(
        id: m['id'] ?? '',
        date: DateTime.tryParse(m['date'] ?? '') ?? DateTime.now(),
        isPayment: m['isPayment'] ?? false,
        amount: (m['amount'] ?? 0).toDouble(),
        note: m['note'] ?? '',
        items: List.from(m['items'] ?? []),
      );
}

class UdhaarCustomer {
  String id;
  String name;
  String phone;
  double totalDue;
  List<UdhaarEntry> history;

  UdhaarCustomer({
    required this.id,
    required this.name,
    required this.phone,
    this.totalDue = 0,
    this.history = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'totalDue': totalDue,
        'history': history.map((e) => e.toMap()).toList(),
      };

  factory UdhaarCustomer.fromMap(Map<String, dynamic> m) => UdhaarCustomer(
        id: m['id'] ?? '',
        name: m['name'] ?? 'Customer',
        phone: m['phone'] ?? '',
        totalDue: (m['totalDue'] ?? 0).toDouble(),
        history: (m['history'] as List<dynamic>? ?? [])
            .map((e) => UdhaarEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class StaffMember {
  String uid;
  String name;
  String contact;
  String role; // 'billing' or 'full'
  String status; // 'pending', 'approved'

  StaffMember({
    required this.uid,
    required this.name,
    required this.contact,
    this.role = 'billing',
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'contact': contact,
        'role': role,
        'status': status,
      };

  factory StaffMember.fromMap(Map<String, dynamic> m) => StaffMember(
        uid: m['uid'] ?? '',
        name: m['name'] ?? 'Staff',
        contact: m['contact'] ?? '',
        role: m['role'] ?? 'billing',
        status: m['status'] ?? 'pending',
      );
}

class ExpenseRecord {
  String id;
  String title;
  double amount;
  DateTime date;

  ExpenseRecord({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory ExpenseRecord.fromMap(Map<String, dynamic> m) => ExpenseRecord(
        id: m['id'] ?? '',
        title: m['title'] ?? 'Expense',
        amount: (m['amount'] ?? 0).toDouble(),
        date: DateTime.tryParse(m['date'] ?? '') ?? DateTime.now(),
      );
}

// ============================================================================
// APP ROOT & STATE CONTROLLER
// ============================================================================
class VanikPosApp extends StatelessWidget {
  final bool firebaseReady;
  const VanikPosApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vanik Kirana POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bgCream,
        primaryColor: AppColors.primaryGreen,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          surface: AppColors.bgCream,
        ),
        useMaterial3: true,
      ),
      home: AppBootstrapScreen(firebaseReady: firebaseReady),
    );
  }
}

class AppBootstrapScreen extends StatefulWidget {
  final bool firebaseReady;
  const AppBootstrapScreen({super.key, required this.firebaseReady});

  @override
  State<AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<AppBootstrapScreen> {
  bool _loading = true;
  bool _isLoggedIn = false;
  String _shopId = '';
  String _shopName = '';
  String _ownerPhone = '';
  String _joinCode = '';
  String _upiId = '';
  String _language = 'English';
  String _userRole = 'owner'; // 'owner', 'full', 'billing', 'pending_staff'
  String _userUid = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _shopId = prefs.getString('shopId') ?? '';
      _shopName = prefs.getString('shopName') ?? '';
      _ownerPhone = prefs.getString('ownerPhone') ?? '';
      _joinCode = prefs.getString('joinCode') ?? '';
      _upiId = prefs.getString('upiId') ?? '';
      _language = prefs.getString('language') ?? 'English';
      _userRole = prefs.getString('userRole') ?? 'owner';
      _userUid = prefs.getString('userUid') ?? '';
      _userName = prefs.getString('userName') ?? '';
      _loading = false;
    });
  }

  Future<void> _onAuthComplete({
    required String uid,
    required String name,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userUid', uid);
    await prefs.setString('userName', name);
    await prefs.setString('ownerPhone', phone);

    // Check if user already has a shop in Firestore
    if (widget.firebaseReady) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          final savedShopId = data['shopId'] ?? '';
          if (savedShopId.isNotEmpty) {
            final shopDoc = await FirebaseFirestore.instance
                .collection('shops')
                .doc(savedShopId)
                .get();
            if (shopDoc.exists && shopDoc.data() != null) {
              final sData = shopDoc.data()!;
              await prefs.setString('shopId', savedShopId);
              await prefs.setString('shopName', sData['shopName'] ?? name);
              await prefs.setString('joinCode', sData['joinCode'] ?? '765177');
              await prefs.setString('upiId', sData['upiId'] ?? '');
              await prefs.setString('userRole', data['role'] ?? 'owner');
              await _loadSession();
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('User fetch error: $e');
      }
    }

    setState(() {
      _isLoggedIn = true;
      _userUid = uid;
      _userName = name;
      _ownerPhone = phone;
    });
  }

  Future<void> _onShopReady({
    required String shopId,
    required String shopName,
    required String joinCode,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shopId', shopId);
    await prefs.setString('shopName', shopName);
    await prefs.setString('joinCode', joinCode);
    await prefs.setString('userRole', role);
    await _loadSession();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (widget.firebaseReady) {
      try {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    setState(() {
      _isLoggedIn = false;
      _shopId = '';
      _shopName = '';
      _userRole = 'owner';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (!_isLoggedIn) {
      return LoginScreen(
        firebaseReady: widget.firebaseReady,
        onAuthSuccess: _onAuthComplete,
      );
    }

    if (_shopId.isEmpty) {
      return ShopOnboardingScreen(
        firebaseReady: widget.firebaseReady,
        userUid: _userUid,
        userName: _userName,
        userPhone: _ownerPhone,
        onShopCreatedOrJoined: _onShopReady,
        onLogout: _logout,
      );
    }

    if (_userRole == 'pending_staff') {
      return PendingApprovalScreen(
        firebaseReady: widget.firebaseReady,
        shopId: _shopId,
        shopName: _shopName,
        userUid: _userUid,
        onApproved: (role) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userRole', role);
          setState(() => _userRole = role);
        },
        onLogout: _logout,
      );
    }

    return MainPosHomeScreen(
      firebaseReady: widget.firebaseReady,
      shopId: _shopId,
      shopName: _shopName,
      ownerPhone: _ownerPhone,
      joinCode: _joinCode,
      initialUpiId: _upiId,
      initialLanguage: _language,
      userRole: _userRole,
      userUid: _userUid,
      onLogout: _logout,
    );
  }
}

// ============================================================================
// SCREEN 1: LOGIN SCREEN (GOOGLE + MOBILE OTP + INSTANT OFFLINE ACCESS)
// ============================================================================
class LoginScreen extends StatefulWidget {
  final bool firebaseReady;
  final Future<void> Function({
    required String uid,
    required String name,
    required String phone,
  }) onAuthSuccess;

  const LoginScreen({
    super.key,
    required this.firebaseReady,
    required this.onAuthSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  bool _otpSent = false;
  String _verificationId = '';
  bool _busy = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      if (widget.firebaseReady) {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser != null) {
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          final UserCredential userCred =
              await FirebaseAuth.instance.signInWithCredential(credential);
          final user = userCred.user;
          if (user != null) {
            await widget.onAuthSuccess(
              uid: user.uid,
              name: user.displayName ?? 'Kirana Owner',
              phone: user.phoneNumber ?? user.email ?? '',
            );
            return;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Login Note: $e. Use Mobile Login below.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid 10-digit mobile number')),
      );
      return;
    }
    setState(() => _busy = true);
    final formattedPhone = phone.startsWith('+') ? phone : '+91$phone';

    if (widget.firebaseReady) {
      try {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: formattedPhone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            final res =
                await FirebaseAuth.instance.signInWithCredential(credential);
            if (res.user != null) {
              await widget.onAuthSuccess(
                uid: res.user!.uid,
                name: _nameCtrl.text.trim().isEmpty
                    ? 'Shop Owner'
                    : _nameCtrl.text.trim(),
                phone: phone,
              );
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            setState(() {
              _otpSent = true;
              _busy = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'OTP Demo Mode Ready (${e.message ?? "Enter 123456"})'),
              ),
            );
          },
          codeSent: (String verId, int? resendToken) {
            setState(() {
              _verificationId = verId;
              _otpSent = true;
              _busy = false;
            });
          },
          codeAutoRetrievalTimeout: (String verId) {
            _verificationId = verId;
          },
        );
        return;
      } catch (_) {}
    }

    setState(() {
      _otpSent = true;
      _busy = false;
    });
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    final name = _nameCtrl.text.trim().isEmpty
        ? 'Shop Owner'
        : _nameCtrl.text.trim();

    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid OTP')),
      );
      return;
    }

    setState(() => _busy = true);
    if (widget.firebaseReady && _verificationId.isNotEmpty) {
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId,
          smsCode: otp,
        );
        final res =
            await FirebaseAuth.instance.signInWithCredential(credential);
        if (res.user != null) {
          await widget.onAuthSuccess(
            uid: res.user!.uid,
            name: name,
            phone: phone,
          );
          return;
        }
      } catch (_) {}
    }

    // Fallback instant local + Firestore UID based on phone
    await widget.onAuthSuccess(
      uid: 'phone_$phone',
      name: name,
      phone: phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Vanik Kirana POS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Smart Billing, Stock, Udhaar Khata & Cloud Sync',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.mutedText),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.sandBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      label: const Text(
                        'Continue with Google Account',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sandLight,
                        foregroundColor: AppColors.darkText,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppColors.sandBorder),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.sandBorder)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('OR MOBILE OTP',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedText,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Expanded(child: Divider(color: AppColors.sandBorder)),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Your Name / Shop Owner Name',
                        filled: true,
                        fillColor: AppColors.bgCream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number (10 Digits)',
                        prefixText: '+91 ',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.bgCream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (_otpSent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _otpCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'Enter 6-Digit OTP',
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.bgCream,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          _busy ? null : (_otpSent ? _verifyOtp : _sendOtp),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _otpSent ? 'Verify & Continue' : 'Send OTP',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
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
}
// ============================================================================
// SCREEN 2: CREATE NEW SHOP OR JOIN EXISTING SHOP VIA 6-DIGIT CODE
// ============================================================================
class ShopOnboardingScreen extends StatefulWidget {
  final bool firebaseReady;
  final String userUid;
  final String userName;
  final String userPhone;
  final Future<void> Function({
    required String shopId,
    required String shopName,
    required String joinCode,
    required String role,
  }) onShopCreatedOrJoined;
  final VoidCallback onLogout;

  const ShopOnboardingScreen({
    super.key,
    required this.firebaseReady,
    required this.userUid,
    required this.userName,
    required this.userPhone,
    required this.onShopCreatedOrJoined,
    required this.onLogout,
  });

  @override
  State<ShopOnboardingScreen> createState() => _ShopOnboardingScreenState();
}

class _ShopOnboardingScreenState extends State<ShopOnboardingScreen> {
  final TextEditingController _shopNameCtrl = TextEditingController();
  final TextEditingController _joinCodeCtrl = TextEditingController();
  bool _isCreating = true;
  bool _busy = false;

  Future<void> _createShop() async {
    final name = _shopNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Shop Name')),
      );
      return;
    }
    setState(() => _busy = true);
    final code = (100000 + Random().nextInt(900000)).toString();
    final shopId = 'shop_${widget.userUid}';

    if (widget.firebaseReady) {
      try {
        await FirebaseFirestore.instance.collection('shops').doc(shopId).set({
          'shopId': shopId,
          'shopName': name,
          'ownerUid': widget.userUid,
          'ownerName': widget.userName,
          'ownerPhone': widget.userPhone,
          'joinCode': code,
          'upiId': '',
          'createdAt': DateTime.now().toIso8601String(),
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userUid)
            .set({
          'uid': widget.userUid,
          'name': widget.userName,
          'phone': widget.userPhone,
          'shopId': shopId,
          'role': 'owner',
        });
      } catch (e) {
        debugPrint('Create shop cloud error: $e');
      }
    }

    await widget.onShopCreatedOrJoined(
      shopId: shopId,
      shopName: name,
      joinCode: code,
      role: 'owner',
    );
  }

  Future<void> _joinShopWithCode() async {
    final code = _joinCodeCtrl.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid 6-digit Shop Code')),
      );
      return;
    }
    setState(() => _busy = true);

    if (widget.firebaseReady) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('shops')
            .where('joinCode', isEqualTo: code)
            .limit(1)
            .get();

        if (snap.docs.isEmpty) {
          setState(() => _busy = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Invalid 6-digit code! Check with Shop Owner.')),
            );
          }
          return;
        }

        final shopDoc = snap.docs.first;
        final shopId = shopDoc.id;
        final shopName = shopDoc.data()['shopName'] ?? 'Kirana Store';

        await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('staff')
            .doc(widget.userUid)
            .set({
          'uid': widget.userUid,
          'name': widget.userName,
          'contact': widget.userPhone,
          'role': 'billing',
          'status': 'pending',
          'requestedAt': DateTime.now().toIso8601String(),
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userUid)
            .set({
          'uid': widget.userUid,
          'name': widget.userName,
          'phone': widget.userPhone,
          'shopId': shopId,
          'role': 'pending_staff',
        });

        await widget.onShopCreatedOrJoined(
          shopId: shopId,
          shopName: shopName,
          joinCode: code,
          role: 'pending_staff',
        );
        return;
      } catch (e) {
        debugPrint('Join shop error: $e');
      }
    }

    setState(() => _busy = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Internet & Firebase required to join another shop')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        backgroundColor: AppColors.bgCream,
        elevation: 0,
        title: const Text('Setup Your Shop',
            style: TextStyle(
                color: AppColors.darkText, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: widget.onLogout,
            child: const Text('Logout',
                style: TextStyle(color: AppColors.dangerRed)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.sandLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sandBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isCreating = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _isCreating
                              ? AppColors.sandMedium
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Create New Shop',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isCreating = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: !_isCreating
                              ? AppColors.sandMedium
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Join a Shop (Staff)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.sandBorder),
              ),
              child: _isCreating
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Apni Dukaan Ka Naam Likhein',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _shopNameCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. Damodar Kirana Store',
                            filled: true,
                            fillColor: AppColors.bgCream,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: _busy ? null : _createShop,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Start My Shop',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Enter 6-Digit Code Given by Owner',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Code dalne ke baad Shop Owner ke phone par approval request jayegi.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.mutedText),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _joinCodeCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6),
                          decoration: InputDecoration(
                            hintText: '765177',
                            counterText: '',
                            filled: true,
                            fillColor: AppColors.bgCream,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: _busy ? null : _joinShopWithCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.amberGold,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Send Join Request',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
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
// ============================================================================
// SCREEN 3: WAITING FOR OWNER APPROVAL (STAFF SECURITY GATE)
// ============================================================================
class PendingApprovalScreen extends StatelessWidget {
  final bool firebaseReady;
  final String shopId;
  final String shopName;
  final String userUid;
  final Future<void> Function(String role) onApproved;
  final VoidCallback onLogout;

  const PendingApprovalScreen({
    super.key,
    required this.firebaseReady,
    required this.shopId,
    required this.shopName,
    required this.userUid,
    required this.onApproved,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: StreamBuilder<DocumentSnapshot>(
            stream: firebaseReady
                ? FirebaseFirestore.instance
                    .collection('shops')
                    .doc(shopId)
                    .collection('staff')
                    .doc(userUid)
                    .snapshots()
                : null,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                if (data['status'] == 'approved') {
                  Future.microtask(
                      () => onApproved(data['role'] ?? 'billing'));
                }
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_clock_rounded,
                      size: 80, color: AppColors.amberGold),
                  const SizedBox(height: 20),
                  Text(
                    'Waiting for Approval from\n"$shopName"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Shop Owner ko aapki details bhej di gayi hain. Jaise hi Owner aapko approve karenge, aapki screen apne aap khul jayegi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 30),
                  const CircularProgressIndicator(color: AppColors.primaryGreen),
                  const SizedBox(height: 30),
                  OutlinedButton(
                    onPressed: onLogout,
                    child: const Text('Cancel & Logout'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HELPER WIDGET: PERMANENT PRODUCT IMAGE (LOCAL FILE + BASE64 + DEFAULT BAG)
// ============================================================================
Widget buildProductAvatar(
  ProductItem? item, {
  double size = 48,
  bool isLooseDefault = false,
}) {
  Widget fallback = Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.sandLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.sandBorder),
    ),
    child: Icon(
      isLooseDefault ? Icons.shopping_bag_rounded : Icons.inventory_2_rounded,
      color: AppColors.amberGold,
      size: size * 0.55,
    ),
  );

  if (item == null) return fallback;

  if (item.imagePath.isNotEmpty && File(item.imagePath).existsSync()) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(item.imagePath),
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  if (item.imageBase64.isNotEmpty) {
    try {
      final bytes = base64Decode(item.imageBase64);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {}
  }

  return fallback;
}

// ============================================================================
// MAIN POS DASHBOARD (MY SHOP | MAKE BILL | MY SALES)
// ============================================================================
class MainPosHomeScreen extends StatefulWidget {
  final bool firebaseReady;
  final String shopId;
  final String shopName;
  final String ownerPhone;
  final String joinCode;
  final String initialUpiId;
  final String initialLanguage;
  final String userRole;
  final String userUid;
  final VoidCallback onLogout;

  const MainPosHomeScreen({
    super.key,
    required this.firebaseReady,
    required this.shopId,
    required this.shopName,
    required this.ownerPhone,
    required this.joinCode,
    required this.initialUpiId,
    required this.initialLanguage,
    required this.userRole,
    required this.userUid,
    required this.onLogout,
  });

  @override
  State<MainPosHomeScreen> createState() => _MainPosHomeScreenState();
}

class _MainPosHomeScreenState extends State<MainPosHomeScreen> {
  int _bottomIndex = 0; // 0 = My Shop, 1 = Make Bill, 2 = My Sales
  late String _shopName;
  late String _upiId;
  late String _language;

  List<ProductItem> _products = [];
  List<BillRecord> _bills = [];
  List<UdhaarCustomer> _customers = [];
  List<ExpenseRecord> _expenses = [];
  List<StaffMember> _staffList = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _shopName = widget.shopName;
    _upiId = widget.initialUpiId;
    _language = widget.initialLanguage;
    _loadAllData();
  }
  // ==========================================================================
  // PERMANENT STORAGE & FIREBASE CLOUD SYNC
  // ==========================================================================
  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final prodJson = prefs.getString('products_${widget.shopId}');
    final billJson = prefs.getString('bills_${widget.shopId}');
    final custJson = prefs.getString('customers_${widget.shopId}');
    final expJson = prefs.getString('expenses_${widget.shopId}');

    if (prodJson != null) {
      final list = jsonDecode(prodJson) as List<dynamic>;
      _products = list
          .map((e) => ProductItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (billJson != null) {
      final list = jsonDecode(billJson) as List<dynamic>;
      _bills = list
          .map((e) => BillRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (custJson != null) {
      final list = jsonDecode(custJson) as List<dynamic>;
      _customers = list
          .map((e) => UdhaarCustomer.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (expJson != null) {
      final list = jsonDecode(expJson) as List<dynamic>;
      _expenses = list
          .map((e) => ExpenseRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (mounted) setState(() {});

    // Sync from Firebase Firestore if available
    if (widget.firebaseReady) {
      _syncFromCloud();
    }
  }

  Future<void> _syncFromCloud() async {
    try {
      final shopRef =
          FirebaseFirestore.instance.collection('shops').doc(widget.shopId);

      final prodSnap = await shopRef.collection('products').get();
      if (prodSnap.docs.isNotEmpty) {
        _products =
            prodSnap.docs.map((d) => ProductItem.fromMap(d.data())).toList();
      }

      final billSnap = await shopRef
          .collection('bills')
          .orderBy('date', descending: true)
          .limit(200)
          .get();
      if (billSnap.docs.isNotEmpty) {
        _bills =
            billSnap.docs.map((d) => BillRecord.fromMap(d.data())).toList();
      }

      final custSnap = await shopRef.collection('customers').get();
      if (custSnap.docs.isNotEmpty) {
        _customers = custSnap.docs
            .map((d) => UdhaarCustomer.fromMap(d.data()))
            .toList();
      }

      final staffSnap = await shopRef.collection('staff').get();
      _staffList =
          staffSnap.docs.map((d) => StaffMember.fromMap(d.data())).toList();

      await _saveLocalCache();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Cloud sync read note: $e');
    }
  }

  Future<void> _saveLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('products_${widget.shopId}',
        jsonEncode(_products.map((e) => e.toMap()).toList()));
    await prefs.setString('bills_${widget.shopId}',
        jsonEncode(_bills.map((e) => e.toMap()).toList()));
    await prefs.setString('customers_${widget.shopId}',
        jsonEncode(_customers.map((e) => e.toMap()).toList()));
    await prefs.setString('expenses_${widget.shopId}',
        jsonEncode(_expenses.map((e) => e.toMap()).toList()));
  }

  Future<void> _saveProduct(ProductItem item) async {
    final idx = _products.indexWhere((p) => p.id == item.id);
    if (idx >= 0) {
      _products[idx] = item;
    } else {
      _products.insert(0, item);
    }
    setState(() {});
    await _saveLocalCache();

    if (widget.firebaseReady) {
      try {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('products')
            .doc(item.id)
            .set(item.toMap());

        // Also save to global catalog if barcode exists
        if (item.barcode.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('global_catalog')
              .doc(item.barcode)
              .set({
            'barcode': item.barcode,
            'name': item.name,
            'sellPrice': item.sellPrice,
            'imageBase64': item.imageBase64,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Cloud product save: $e');
      }
    }
  }

  Future<void> _deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
    setState(() {});
    await _saveLocalCache();
    if (widget.firebaseReady) {
      try {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('products')
            .doc(id)
            .delete();
      } catch (_) {}
    }
  }

  Future<void> _saveCustomer(UdhaarCustomer cust) async {
    final idx = _customers.indexWhere((c) => c.id == cust.id);
    if (idx >= 0) {
      _customers[idx] = cust;
    } else {
      _customers.insert(0, cust);
    }
    setState(() {});
    await _saveLocalCache();

    if (widget.firebaseReady) {
      try {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('customers')
            .doc(cust.id)
            .set(cust.toMap());
      } catch (_) {}
    }
  }

  Future<void> _completeBill(BillRecord bill, List<CartItem> cartItems) async {
    _bills.insert(0, bill);

    // Deduct stock & increment soldCount
    for (final c in cartItems) {
      final idx = _products.indexWhere((p) => p.id == c.product.id);
      if (idx >= 0) {
        _products[idx].stock =
            max(0, _products[idx].stock - c.qty);
        _products[idx].soldCount += 1;
        await _saveProduct(_products[idx]);
      }
    }

    setState(() {});
    await _saveLocalCache();

    if (widget.firebaseReady) {
      try {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('bills')
            .doc(bill.id)
            .set(bill.toMap());
      } catch (_) {}
    }
  }
  // Permanent Image Capture & Storage (App Documents + Base64)
  Future> _pickPermanentImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 65,
      );
      if (picked == null) return {};

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'prod_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await File(picked.path).copy('${dir.path}/$fileName');
      final bytes = await savedFile.readAsBytes();
      final b64 = base64Encode(bytes);

      return {
        'path': savedFile.path,
        'base64': b64,
      };
    } catch (e) {
      debugPrint('Image pick error: $e');
      return {};
    }
  }

  // ==========================================================================
  // TOP HEADER BAR (MATCHES VANIK EXACT HEADER)
  // ==========================================================================
  Widget _buildTopHeader() {
    final pendingStaffCount =
        _staffList.where((s) => s.status == 'pending').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          // Profile Button
          Expanded(
            child: GestureDetector(
              onTap: () => _openMyProfileScreen(),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.sandLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.sandBorder),
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: AppColors.primaryGreen, size: 24),
                      ),
                      if (pendingStaffCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.dangerRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      _shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Orders Pill
          GestureDetector(
            onTap: () => _openMyProfileScreen(initialTab: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sandBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      size: 18, color: AppColors.primaryGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Bills: ${_bills.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.darkText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Cloud Sync Shield Icon
          GestureDetector(
            onTap: () async {
              await _syncFromCloud();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cloud Data Synced!')),
                );
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sandBorder),
              ),
              child: const Icon(Icons.verified_user_rounded,
                  color: AppColors.primaryGreen, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  void _openMyProfileScreen({int initialTab = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyProfileScreen(
          firebaseReady: widget.firebaseReady,
          shopId: widget.shopId,
          shopName: _shopName,
          ownerPhone: widget.ownerPhone,
          joinCode: widget.joinCode,
          upiId: _upiId,
          language: _language,
          userRole: widget.userRole,
          staffList: _staffList,
          bills: _bills,
          initialTab: initialTab,
          onSaveUpi: (newUpi) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('upiId', newUpi);
            setState(() => _upiId = newUpi);
            if (widget.firebaseReady) {
              try {
                await FirebaseFirestore.instance
                    .collection('shops')
                    .doc(widget.shopId)
                    .update({'upiId': newUpi});
              } catch (_) {}
            }
          },
          onApproveStaff: (staff, role) async {
            if (widget.firebaseReady) {
              await FirebaseFirestore.instance
                  .collection('shops')
                  .doc(widget.shopId)
                  .collection('staff')
                  .doc(staff.uid)
                  .update({'status': 'approved', 'role': role});
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(staff.uid)
                  .update({'role': role});
            }
            await _syncFromCloud();
          },
          onRemoveStaff: (staff) async {
            if (widget.firebaseReady) {
              await FirebaseFirestore.instance
                  .collection('shops')
                  .doc(widget.shopId)
                  .collection('staff')
                  .doc(staff.uid)
                  .delete();
            }
            await _syncFromCloud();
          },
          onLogout: () {
            Navigator.pop(context);
            widget.onLogout();
          },
        ),
      ),
    );
  }
  // ==========================================================================
  // BOTTOM NAVIGATION BAR (EXACT VANIK 3-BUTTON DOCK WITH BIG GREEN MAKE BILL)
  // ==========================================================================
  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: AppColors.sandBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // My Shop
          GestureDetector(
            onTap: () => setState(() => _bottomIndex = 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storefront_rounded,
                  size: 28,
                  color: _bottomIndex == 0
                      ? AppColors.primaryGreen
                      : AppColors.mutedText,
                ),
                const SizedBox(height: 4),
                Text(
                  'My Shop',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _bottomIndex == 0
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: _bottomIndex == 0
                        ? AppColors.darkText
                        : AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          // Center Big Green Make Bill Button
          GestureDetector(
            onTap: () => _openMakeBillScreen(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.point_of_sale_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Make Bill',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
          // My Sales
          GestureDetector(
            onTap: () => setState(() => _bottomIndex = 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 28,
                  color: _bottomIndex == 2
                      ? AppColors.primaryGreen
                      : AppColors.mutedText,
                ),
                const SizedBox(height: 4),
                Text(
                  'My Sales',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _bottomIndex == 2
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: _bottomIndex == 2
                        ? AppColors.darkText
                        : AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openMakeBillScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MakeBillScreen(
          firebaseReady: widget.firebaseReady,
          shopName: _shopName,
          upiId: _upiId,
          products: _products,
          customers: _customers,
          onSaveNewProduct: _saveProduct,
          onPickImage: _pickPermanentImage,
          onSaveCustomer: _saveCustomer,
          onCompleteBill: _completeBill,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: _bottomIndex == 0
                  ? MyShopTab(
                      products: _products,
                      userRole: widget.userRole,
                      firebaseReady: widget.firebaseReady,
                      onSaveProduct: _saveProduct,
                      onDeleteProduct: _deleteProduct,
                      onPickImage: _pickPermanentImage,
                    )
                  : MySalesTab(
                      bills: _bills,
                      customers: _customers,
                      products: _products,
                      expenses: _expenses,
                      shopName: _shopName,
                      onSaveCustomer: _saveCustomer,
                      onAddExpense: (exp) async {
                        _expenses.insert(0, exp);
                        setState(() {});
                        await _saveLocalCache();
                      },
                      onGoToPending: () => setState(() => _bottomIndex = 0),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}
// ============================================================================
// TAB 1: MY SHOP (SHOP ITEMS + PENDING + BARCODE / LOOSE POTLI SWITCHER)
// ============================================================================
class MyShopTab extends StatefulWidget {
  final List<ProductItem> products;
  final String userRole;
  final bool firebaseReady;
  final Future<void> Function(ProductItem) onSaveProduct;
  final Future<void> Function(String) onDeleteProduct;
  final Future Function(ImageSource) onPickImage;
  const MyShopTab({
    super.key,
    required this.products,
    required this.userRole,
    required this.firebaseReady,
    required this.onSaveProduct,
    required this.onDeleteProduct,
    required this.onPickImage,
  });

  @override
  State<MyShopTab> createState() => _MyShopTabState();
}

class _MyShopTabState extends State<MyShopTab> {
  int _topTab = 0; // 0 = Shop items, 1 = Pending
  bool _showLoose = false; // false = Barcode items, true = Loose items
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final savedItems = widget.products.where((p) => !p.isPending).toList();
    final pendingItems = widget.products.where((p) => p.isPending).toList();

    final filteredList = savedItems.where((p) {
      final matchesMode = p.isLoose == _showLoose;
      final matchesQuery =
          p.name.toLowerCase().contains(_search.toLowerCase()) ||
              p.barcode.contains(_search);
      return matchesMode && matchesQuery;
    }).toList();

    return Column(
      children: [
        // Shop items vs Pending Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _topTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _topTab == 0
                          ? AppColors.sandMedium
                          : AppColors.cardWhite,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                      border: Border.all(color: AppColors.sandBorder),
                    ),
                    child: Text(
                      'Shop items: ${savedItems.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _topTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _topTab == 1
                          ? AppColors.sandMedium
                          : AppColors.cardWhite,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                      border: Border.all(color: AppColors.sandBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Pending',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.oliveText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: pendingItems.isNotEmpty
                                ? AppColors.amberGold
                                : AppColors.sandBorder,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${pendingItems.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_topTab == 0) ...[
          // Search + Barcode / Potli Toggle + Stock Action Button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sandLight,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border.all(color: AppColors.sandBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: InputDecoration(
                          hintText: _showLoose
                              ? 'Search loose item'
                              : 'Search barcode item',
                          prefixIcon: const Icon(Icons.search,
                              color: AppColors.mutedText),
                          filled: true,
                          fillColor: AppColors.cardWhite,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.sandBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.sandBorder),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Barcode vs Potli Switcher
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.sandBorder),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _showLoose = false),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: !_showLoose
                                    ? AppColors.sandMedium
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.qr_code_scanner_rounded,
                                  size: 22, color: AppColors.darkText),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showLoose = true),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _showLoose
                                    ? AppColors.sandMedium
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.shopping_bag_rounded,
                                  size: 22, color: AppColors.amberGold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_showLoose) {
                        _openLooseStockSheet();
                      } else {
                        _openBarcodeStockScanner();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amberGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _showLoose ? 'Stock loose item' : 'Stock barcode items',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Saved Items List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Text(
                      _showLoose
                          ? 'No loose items yet.\nTap "Stock loose item" above to add.'
                          : 'No barcode items yet.\nTap "Stock barcode items" above to scan & add.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final isLowStock = item.stock <= 5;
                      return GestureDetector(
                        onTap: () => _showEditItemDialog(item),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.sandBorder),
                          ),
                          child: Row(
                            children: [
                              buildProductAvatar(item,
                                  size: 50, isLooseDefault: item.isLoose),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkText,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item.stock % 1 == 0 ? item.stock.toInt() : item.stock.toStringAsFixed(2)} ${item.unit == 'kg' ? 'kilo' : 'piece'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isLowStock
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isLowStock
                                            ? AppColors.dangerRed
                                            : AppColors.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${item.sellPrice % 1 == 0 ? item.sellPrice.toInt() : item.sellPrice}${item.unit == 'kg' ? ' kg' : ''}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ] else ...[
          // Pending Items Tab (Items scanned during billing without buying price)
          Expanded(
            child: pendingItems.isEmpty
                ? const Center(
                    child: Text(
                      'No Pending Items! All prices & stocks are updated.',
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: pendingItems.length,
                    itemBuilder: (context, idx) {
                      final pItem = pendingItems[idx];
                      return _PendingItemCard(
                        item: pItem,
                        onPickImage: widget.onPickImage,
                        onSave: (updated) async {
                          updated.isPending = false;
                          await widget.onSaveProduct(updated);
                        },
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
  // Edit Existing Item Dialog (Matches Vanik Update Popup)
  void _showEditItemDialog(ProductItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final buyCtrl = TextEditingController(
        text: item.buyPrice % 1 == 0
            ? item.buyPrice.toInt().toString()
            : item.buyPrice.toString());
    final sellCtrl = TextEditingController(
        text: item.sellPrice % 1 == 0
            ? item.sellPrice.toInt().toString()
            : item.sellPrice.toString());
    final stockCtrl = TextEditingController(
        text: item.stock % 1 == 0
            ? item.stock.toInt().toString()
            : item.stock.toString());
    String imgPath = item.imagePath;
    String imgB64 = item.imageBase64;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.barcode.isNotEmpty)
                  Text(item.barcode,
                      style: const TextStyle(
                          color: AppColors.mutedText, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final res =
                            await widget.onPickImage(ImageSource.camera);
                        if (res.isNotEmpty) {
                          setDlgState(() {
                            imgPath = res['path']!;
                            imgB64 = res['base64']!;
                          });
                        }
                      },
                      child: Stack(
                        children: [
                          buildProductAvatar(
                            ProductItem(
                              id: item.id,
                              name: item.name,
                              sellPrice: item.sellPrice,
                              imagePath: imgPath,
                              imageBase64: imgB64,
                              isLoose: item.isLoose,
                            ),
                            size: 68,
                            isLooseDefault: item.isLoose,
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 14, color: AppColors.darkText),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Product name',
                          filled: true,
                          fillColor: AppColors.sandLight,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _numRow(
                    'Buying price of 1 ${item.unit == 'kg' ? 'Kg' : 'Piece'}',
                    buyCtrl),
                const SizedBox(height: 10),
                _numRow(
                    'Selling price of 1 ${item.unit == 'kg' ? 'Kg' : 'Piece'} (₹)',
                    sellCtrl),
                const SizedBox(height: 10),
                _numRow(
                    'Current ${item.unit == 'kg' ? 'kilos' : 'pieces'} in shop',
                    stockCtrl),
                const SizedBox(height: 18),
                Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        await widget.onDeleteProduct(item.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.dangerRed),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          item.name = nameCtrl.text.trim().isEmpty
                              ? item.name
                              : nameCtrl.text.trim();
                          item.buyPrice =
                              double.tryParse(buyCtrl.text) ?? item.buyPrice;
                          item.sellPrice =
                              double.tryParse(sellCtrl.text) ?? item.sellPrice;
                          item.stock =
                              double.tryParse(stockCtrl.text) ?? item.stock;
                          item.imagePath = imgPath;
                          item.imageBase64 = imgB64;
                          await widget.onSaveProduct(item);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.amberGold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Update',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _numRow(String label, TextEditingController ctrl) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.darkText)),
        ),
        SizedBox(
          width: 90,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // Open Barcode Stocking Screen
  void _openBarcodeStockScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockBarcodeScreen(
          products: widget.products.where((p) => !p.isLoose).toList(),
          firebaseReady: widget.firebaseReady,
          onSaveProduct: widget.onSaveProduct,
          onPickImage: widget.onPickImage,
        ),
      ),
    );
  }

  // Open Loose Item Stocking / Add Screen
  void _openLooseStockSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockLooseItemScreen(
          looseProducts: widget.products.where((p) => p.isLoose).toList(),
          onSaveProduct: widget.onSaveProduct,
          onPickImage: widget.onPickImage,
        ),
      ),
    );
  }
}

class _PendingItemCard extends StatefulWidget {
  final ProductItem item;
  final Future Function(ImageSource) onPickImage;
  final Future<void> Function(ProductItem) onSave;

  const _PendingItemCard({
    required this.item,
    required this.onPickImage,
    required this.onSave,
  });

  @override
  State<_PendingItemCard> createState() => _PendingItemCardState();
}

class _PendingItemCardState extends State<_PendingItemCard> {
  late TextEditingController _nameCtrl;
  final TextEditingController _buyCtrl = TextEditingController();
  late TextEditingController _sellCtrl;
  final TextEditingController _stockCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _sellCtrl = TextEditingController(
        text: widget.item.sellPrice.toInt().toString());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sandBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final res = await widget.onPickImage(ImageSource.camera);
                  if (res.isNotEmpty) {
                    setState(() {
                      widget.item.imagePath = res['path']!;
                      widget.item.imageBase64 = res['base64']!;
                    });
                  }
                },
                child: buildProductAvatar(widget.item,
                    size: 64, isLooseDefault: widget.item.isLoose),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.item.barcode.isNotEmpty)
                      Text(widget.item.barcode,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.mutedText)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Product name',
                        filled: true,
                        fillColor: AppColors.sandLight,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _buyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Buying price of 1 Piece / Kg (₹)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sellCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Your selling price (₹)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _stockCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Current pieces / kilos in shop',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.item.name = _nameCtrl.text.trim().isEmpty
                    ? widget.item.name
                    : _nameCtrl.text.trim();
                widget.item.buyPrice = double.tryParse(_buyCtrl.text) ?? 0;
                widget.item.sellPrice =
                    double.tryParse(_sellCtrl.text) ?? widget.item.sellPrice;
                widget.item.stock = double.tryParse(_stockCtrl.text) ?? 0;
                widget.onSave(widget.item);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================================
// SCREEN: STOCK BARCODE ITEMS (CAMERA SCANNER + BULK STOCK ENTRY POPUP)
// ============================================================================
class StockBarcodeScreen extends StatefulWidget {
  final List<ProductItem> products;
  final bool firebaseReady;
  final Future<void> Function(ProductItem) onSaveProduct;
  final Future Function(ImageSource) onPickImage;
  const StockBarcodeScreen({
    super.key,
    required this.products,
    required this.firebaseReady,
    required this.onSaveProduct,
    required this.onPickImage,
  });

  @override
  State<StockBarcodeScreen> createState() => _StockBarcodeScreenState();
}

class _StockBarcodeScreenState extends State<StockBarcodeScreen> {
  final MobileScannerController _scannerCtrl = MobileScannerController();
  String _search = '';
  bool _popupOpen = false;

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(String code) async {
    if (_popupOpen || code.isEmpty) return;
    _popupOpen = true;

    ProductItem? existing = widget.products
        .cast<ProductItem?>()
        .firstWhere((p) => p?.barcode == code, orElse: () => null);

    // Check global catalog if not in shop yet
    if (existing == null && widget.firebaseReady) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('global_catalog')
            .doc(code)
            .get();
        if (doc.exists && doc.data() != null) {
          final d = doc.data()!;
          existing = ProductItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: d['name'] ?? '',
            barcode: code,
            sellPrice: (d['sellPrice'] ?? 0).toDouble(),
            imageBase64: d['imageBase64'] ?? '',
          );
        }
      } catch (_) {}
    }

    if (!mounted) return;
    await _showAddStockPopup(
      barcode: code,
      item: existing,
    );
    _popupOpen = false;
  }

  Future<void> _showAddStockPopup({
    required String barcode,
    ProductItem? item,
  }) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final wholePaidCtrl = TextEditingController();
    final piecesBoughtCtrl = TextEditingController();
    final sellPriceCtrl = TextEditingController(
        text: item != null && item.sellPrice > 0
            ? item.sellPrice.toInt().toString()
            : '');
    String imgPath = item?.imagePath ?? '';
    String imgB64 = item?.imageBase64 ?? '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (barcode.isNotEmpty)
                  Text(barcode,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.mutedText)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final res =
                            await widget.onPickImage(ImageSource.camera);
                        if (res.isNotEmpty) {
                          setDlg(() {
                            imgPath = res['path']!;
                            imgB64 = res['base64']!;
                          });
                        }
                      },
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppColors.sandLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.sandBorder),
                        ),
                        child: imgPath.isNotEmpty || imgB64.isNotEmpty
                            ? buildProductAvatar(
                                ProductItem(
                                    id: 'tmp',
                                    name: '',
                                    sellPrice: 0,
                                    imagePath: imgPath,
                                    imageBase64: imgB64),
                                size: 68,
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_rounded,
                                      color: AppColors.amberGold),
                                  Text('Photo', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Product name',
                          filled: true,
                          fillColor: AppColors.sandLight,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _stockField('Money you paid for whole stock (₹)', wholePaidCtrl),
                const SizedBox(height: 10),
                _stockField(
                    'No. of pieces bought in that money', piecesBoughtCtrl),
                const SizedBox(height: 10),
                _stockField(
                    'Your selling price of 1 Piece (₹)', sellPriceCtrl),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final pName = nameCtrl.text.trim();
                      if (pName.isEmpty) return;

                      final paid = double.tryParse(wholePaidCtrl.text) ?? 0;
                      final qtyBought =
                          double.tryParse(piecesBoughtCtrl.text) ?? 0;
                      final sell = double.tryParse(sellPriceCtrl.text) ?? 0;
                      final buyPerPiece =
                          qtyBought > 0 ? (paid / qtyBought) : (item?.buyPrice ?? 0);

                      final prod = ProductItem(
                        id: item?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        name: pName,
                        barcode: barcode,
                        isLoose: false,
                        unit: 'piece',
                        buyPrice: buyPerPiece,
                        sellPrice: sell,
                        stock: (item?.stock ?? 0) + qtyBought,
                        imagePath: imgPath,
                        imageBase64: imgB64,
                        isPending: false,
                        soldCount: item?.soldCount ?? 0,
                      );

                      await widget.onSaveProduct(prod);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$pName Stock Added!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amberGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Add stock',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stockField(String label, TextEditingController ctrl) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.darkText)),
        ),
        SizedBox(
          width: 85,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '00',
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.products
        .where((p) => p.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A473E),
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on_rounded),
            onPressed: () => _scannerCtrl.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 220,
            child: MobileScanner(
              controller: _scannerCtrl,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  if (barcode.rawValue != null) {
                    _onBarcodeDetected(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search barcode item',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.cardWhite,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: list.length,
              itemBuilder: (context, idx) {
                final item = list[idx];
                return GestureDetector(
                  onTap: () => _showAddStockPopup(
                      barcode: item.barcode, item: item),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.sandBorder),
                    ),
                    child: Row(
                      children: [
                        buildProductAvatar(item, size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(item.name,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                        Text('Stock: ${item.stock.toInt()}',
                            style: const TextStyle(color: AppColors.mutedText)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.darkText,
        foregroundColor: Colors.white,
        onPressed: () => _showAddStockPopup(
          barcode: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Manual Item'),
      ),
    );
  }
}
// ============================================================================
// SCREEN: STOCK LOOSE ITEM / ADD NEW LOOSE ITEM (PIECE OR KILO + PHOTO)
// ============================================================================
class StockLooseItemScreen extends StatefulWidget {
  final List<ProductItem> looseProducts;
  final Future<void> Function(ProductItem) onSaveProduct;
  final Future> Function(ImageSource) onPickImage;
  const StockLooseItemScreen({
    super.key,
    required this.looseProducts,
    required this.onSaveProduct,
    required this.onPickImage,
  });

  @override
  State<StockLooseItemScreen> createState() => _StockLooseItemScreenState();
}

class _StockLooseItemScreenState extends State<StockLooseItemScreen> {
  String _search = '';

  void _openAddOrRestockLooseDialog({ProductItem? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final buyCtrl = TextEditingController(
        text: existing != null && existing.buyPrice > 0
            ? existing.buyPrice.toString()
            : '');
    final sellCtrl = TextEditingController(
        text: existing != null && existing.sellPrice > 0
            ? existing.sellPrice.toString()
            : '');
    final stockCtrl = TextEditingController();
    String unit = existing?.unit ?? 'kg'; // 'piece' or 'kg'
    String imgPath = existing?.imagePath ?? '';
    String imgB64 = existing?.imageBase64 ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final res =
                            await widget.onPickImage(ImageSource.camera);
                        if (res.isNotEmpty) {
                          setDlg(() {
                            imgPath = res['path']!;
                            imgB64 = res['base64']!;
                          });
                        }
                      },
                      child: Stack(
                        children: [
                          buildProductAvatar(
                            ProductItem(
                              id: 'tmp',
                              name: '',
                              sellPrice: 0,
                              imagePath: imgPath,
                              imageBase64: imgB64,
                              isLoose: true,
                            ),
                            size: 66,
                            isLooseDefault: true,
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Product name',
                          filled: true,
                          fillColor: AppColors.sandLight,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Piece vs Kilo Switcher (Matches Vanik Screenshot)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.sandBorder),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => setDlg(() => unit = 'piece'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: unit == 'piece'
                                    ? AppColors.sandMedium
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(9)),
                              ),
                              child: const Text('Piece',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setDlg(() => unit = 'kg'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: unit == 'kg'
                                    ? AppColors.sandMedium
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(9)),
                              ),
                              child: const Text('Kilo',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: buyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        'Buying price of 1 ${unit == 'kg' ? 'Kg' : 'Piece'} (₹)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sellCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        'Your selling price of 1 ${unit == 'kg' ? 'Kg' : 'Piece'} (₹)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stockCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        'Add stock (${unit == 'kg' ? 'kilos' : 'pieces'})',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final pName = nameCtrl.text.trim();
                      if (pName.isEmpty) return;
                      final buy = double.tryParse(buyCtrl.text) ?? 0;
                      final sell = double.tryParse(sellCtrl.text) ?? 0;
                      final addQty = double.tryParse(stockCtrl.text) ?? 0;

                      final prod = ProductItem(
                        id: existing?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        name: pName,
                        isLoose: true,
                        unit: unit,
                        buyPrice: buy,
                        sellPrice: sell,
                        stock: (existing?.stock ?? 0) + addQty,
                        imagePath: imgPath,
                        imageBase64: imgB64,
                        isPending: false,
                        soldCount: existing?.soldCount ?? 0,
                      );
                      await widget.onSaveProduct(prod);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amberGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Add stock',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.looseProducts
        .where((p) => p.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        backgroundColor: AppColors.bgCream,
        elevation: 0,
        title: const Text('Select item below to restock it',
            style: TextStyle(fontSize: 16, color: AppColors.oliveText)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search loose item',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.cardWhite,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: list.length,
              itemBuilder: (context, idx) {
                final item = list[idx];
                return GestureDetector(
                  onTap: () => _openAddOrRestockLooseDialog(existing: item),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.sandBorder),
                    ),
                    child: Row(
                      children: [
                        buildProductAvatar(item,
                            size: 46, isLooseDefault: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(item.name,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                        Text(
                          '${item.stock} ${item.unit == 'kg' ? 'kg' : 'pc'}',
                          style: const TextStyle(color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.sandLight,
              border: Border(top: BorderSide(color: AppColors.sandBorder)),
            ),
            child: Column(
              children: [
                const Text('Want to add new loose Item? Click below',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.oliveText)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openAddOrRestockLooseDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amberGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Add photo of loose item',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================================
// TAB 2: MAKE BILL SCREEN (LIVE BARCODE + LOOSE ITEM + DYNAMIC UPI QR + UDHAAR)
// ============================================================================
class MakeBillScreen extends StatefulWidget {
  final bool firebaseReady;
  final String shopName;
  final String upiId;
  final List<ProductItem> products;
  final List<UdhaarCustomer> customers;
  final Future<void> Function(ProductItem) onSaveNewProduct;
  final Future Function(ImageSource) onPickImage;
  final Future<void> Function(UdhaarCustomer) onSaveCustomer;
  final Future<void> Function(BillRecord, List<CartItem>) onCompleteBill;

  const MakeBillScreen({
    super.key,
    required this.firebaseReady,
    required this.shopName,
    required this.upiId,
    required this.products,
    required this.customers,
    required this.onSaveNewProduct,
    required this.onPickImage,
    required this.onSaveCustomer,
    required this.onCompleteBill,
  });

  @override
  State<MakeBillScreen> createState() => _MakeBillScreenState();
}

class _MakeBillScreenState extends State<MakeBillScreen> {
  final MobileScannerController _scannerCtrl = MobileScannerController();
  final List<CartItem> _cart = [];
  String _lastScanned = '';
  DateTime _lastScanTime = DateTime.now().subtract(const Duration(seconds: 5));
  bool _dialogOpen = false;

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  double get _billTotal =>
      _cart.fold(0, (sum, item) => sum + item.customTotal);

  double get _billProfit => _cart.fold(
      0,
      (sum, item) =>
          sum + (item.customTotal - (item.product.buyPrice * item.qty)));

  Future<void> _handleScan(String code) async {
    if (_dialogOpen || code.isEmpty) return;
    final now = DateTime.now();
    if (code == _lastScanned &&
        now.difference(_lastScanTime).inMilliseconds < 1800) {
      return;
    }
    _lastScanned = code;
    _lastScanTime = now;

    ProductItem? found = widget.products
        .cast<ProductItem?>()
        .firstWhere((p) => p?.barcode == code, orElse: () => null);

    if (found != null) {
      _addToCart(found, 1, found.sellPrice);
      return;
    }

    // Unknown barcode during billing -> Ask Selling Price & Add to Pending
    _dialogOpen = true;
    String fetchedName = 'New Item ($code)';
    String fetchedB64 = '';
    if (widget.firebaseReady) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('global_catalog')
            .doc(code)
            .get();
        if (doc.exists && doc.data() != null) {
          fetchedName = doc.data()!['name'] ?? fetchedName;
          fetchedB64 = doc.data()!['imageBase64'] ?? '';
        }
      } catch (_) {}
    }

    if (!mounted) return;
    final priceCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: fetchedName);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(code,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.mutedText)),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sandLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text('Selling Price (₹)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.oliveText)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: priceCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: '00',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final sp = double.tryParse(priceCtrl.text) ?? 0;
                  if (sp <= 0) return;
                  final newProd = ProductItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text.trim().isEmpty
                        ? fetchedName
                        : nameCtrl.text.trim(),
                    barcode: code,
                    sellPrice: sp,
                    imageBase64: fetchedB64,
                    isPending: true,
                  );
                  await widget.onSaveNewProduct(newProd);
                  _addToCart(newProd, 1, sp);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amberGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('OK',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
    _dialogOpen = false;
  }

  void _addToCart(ProductItem item, double qty, double totalPrice) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == item.id);
      if (idx >= 0 && !item.isLoose) {
        _cart[idx].qty += qty;
        _cart[idx].customTotal = _cart[idx].qty * item.sellPrice;
      } else {
        _cart.add(CartItem(
          product: item,
          qty: qty,
          customTotal: totalPrice,
        ));
      }
    });
  }
  // Loose Item Selection & Instant New Loose Item Billing
  void _openLooseItemSelector() {
    final looseList = widget.products.where((p) => p.isLoose).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Select Loose Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: looseList.length,
                itemBuilder: (c, idx) {
                  final item = looseList[idx];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showLooseWeightOrRupeePopup(item);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.sandBorder),
                      ),
                      child: Row(
                        children: [
                          buildProductAvatar(item,
                              size: 46, isLooseDefault: true),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(item.name,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                          Text(
                              '₹${item.sellPrice}/${item.unit == 'kg' ? 'kg' : 'pc'}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showInstantNewLooseItemBillDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amberGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add New loose item',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dual Calculator: Calculate by Weight (Kg/Gm) OR Direct Rupees (₹)
  void _showLooseWeightOrRupeePopup(ProductItem item) {
    final qtyCtrl = TextEditingController(text: '1');
    final rupeeCtrl =
        TextEditingController(text: item.sellPrice.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${item.name} (₹${item.sellPrice}/${item.unit})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: item.unit == 'kg'
                    ? 'Weight in Kg (e.g. 0.5 for 500gm)'
                    : 'Quantity (Pieces)',
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                final q = double.tryParse(v) ?? 0;
                rupeeCtrl.text = (q * item.sellPrice).toStringAsFixed(1);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rupeeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Or Enter Amount (₹)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                final r = double.tryParse(v) ?? 0;
                if (item.sellPrice > 0) {
                  qtyCtrl.text = (r / item.sellPrice).toStringAsFixed(3);
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final q = double.tryParse(qtyCtrl.text) ?? 1;
                  final amt = double.tryParse(rupeeCtrl.text) ?? item.sellPrice;
                  _addToCart(item, q, amt);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Add to Bill',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Matches Vanik Screenshots: Add New Loose Item during billing (Piece/Kilo + Photo)
  void _showInstantNewLooseItemBillDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final rateCtrl = TextEditingController();
    String unit = 'piece';
    String imgPath = '';
    String imgB64 = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final res =
                            await widget.onPickImage(ImageSource.camera);
                        if (res.isNotEmpty) {
                          setDlg(() {
                            imgPath = res['path']!;
                            imgB64 = res['base64']!;
                          });
                        }
                      },
                      child: buildProductAvatar(
                        ProductItem(
                          id: 'tmp',
                          name: '',
                          sellPrice: 0,
                          imagePath: imgPath,
                          imageBase64: imgB64,
                          isLoose: true,
                        ),
                        size: 62,
                        isLooseDefault: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Product name',
                          filled: true,
                          fillColor: AppColors.sandLight,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      children: [
                        InkWell(
                          onTap: () => setDlg(() => unit = 'piece'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            color: unit == 'piece'
                                ? AppColors.sandMedium
                                : AppColors.sandLight,
                            child: const Text('Piece',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        InkWell(
                          onTap: () => setDlg(() => unit = 'kg'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            color: unit == 'kg'
                                ? AppColors.sandMedium
                                : AppColors.sandLight,
                            child: const Text('Kilo',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: unit == 'kg'
                        ? 'How many kilos?'
                        : 'How many Pieces?',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: unit == 'kg'
                        ? 'Your selling price of 1 Kg (₹)'
                        : 'Your selling price of 1 Piece (₹)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final qty = double.tryParse(qtyCtrl.text) ?? 1;
                      final rate = double.tryParse(rateCtrl.text) ?? 0;
                      if (name.isEmpty || rate <= 0) return;

                      final newProd = ProductItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        isLoose: true,
                        unit: unit,
                        sellPrice: rate,
                        imagePath: imgPath,
                        imageBase64: imgB64,
                        isPending: true,
                      );
                      await widget.onSaveNewProduct(newProd);
                      _addToCart(newProd, qty, qty * rate);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amberGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('OK',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Dynamic UPI QR Code Dialog (Matches Vanik Screenshot)
  void _showOnlineUpiQrDialog() {
    if (_cart.isEmpty) return;
    if (widget.upiId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set your UPI ID first in Profile -> Settings!'),
        ),
      );
      return;
    }

    final amountStr = _billTotal.toStringAsFixed(2);
    final upiPayload =
        'upi://pay?pa=${widget.upiId.trim()}&pn=${Uri.encodeComponent(widget.shopName)}&am=$amountStr&cu=INR';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Customers can scan this QR to pay',
              style: TextStyle(fontSize: 14, color: AppColors.mutedText),
            ),
            const SizedBox(height: 10),
            Text(
              '₹${_billTotal % 1 == 0 ? _billTotal.toInt() : _billTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 210,
              height: 210,
              child: QrImageView(
                data: upiPayload,
                version: QrVersions.auto,
                size: 210,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Click on the button below once you receive payment',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _finalizeBill(paymentMode: 'Online');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Payment received',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // Udhaar Customer Select / New Person Popup (Matches Vanik Screenshot)
  void _showUdhaarCustomerDialog() {
    if (_cart.isEmpty) return;
    bool isNewPerson = widget.customers.isEmpty;
    UdhaarCustomer? selectedCust =
        widget.customers.isNotEmpty ? widget.customers.first : null;
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDlg(() => isNewPerson = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isNewPerson
                                ? AppColors.sandMedium
                                : AppColors.sandLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Select person',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDlg(() => isNewPerson = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isNewPerson
                                ? AppColors.sandMedium
                                : AppColors.sandLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('New person',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!isNewPerson) ...[
                  if (widget.customers.isEmpty)
                    const Text('No saved customers yet. Switch to New person.')
                  else
                    DropdownButtonFormField<UdhaarCustomer>(
                      value: selectedCust,
                      items: widget.customers
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text('${c.name} (${c.phone})'),
                              ))
                          .toList(),
                      onChanged: (v) => setDlg(() => selectedCust = v),
                      decoration: const InputDecoration(
                        labelText: 'Choose Customer',
                        border: OutlineInputBorder(),
                      ),
                    ),
                ] else ...[
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Person name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      UdhaarCustomer target;
                      if (!isNewPerson && selectedCust != null) {
                        target = selectedCust!;
                      } else {
                        final pName = nameCtrl.text.trim();
                        final pPhone = phoneCtrl.text.trim();
                        if (pName.isEmpty) return;
                        target = UdhaarCustomer(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: pName,
                          phone: pPhone,
                          totalDue: 0,
                          history: [],
                        );
                      }

                      final entry = UdhaarEntry(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        date: DateTime.now(),
                        isPayment: false,
                        amount: _billTotal,
                        items: _cart.map((c) => c.toMap()).toList(),
                      );

                      target.totalDue += _billTotal;
                      target.history = [entry, ...target.history];
                      await widget.onSaveCustomer(target);

                      if (ctx.mounted) Navigator.pop(ctx);
                      await _finalizeBill(
                        paymentMode: 'Udhaar',
                        custName: target.name,
                        custPhone: target.phone,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Add Udhaar',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finalizeBill({
    required String paymentMode,
    String custName = '',
    String custPhone = '',
  }) async {
    if (_cart.isEmpty) return;
    final bill = BillRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      paymentMode: paymentMode,
      customerName: custName,
      customerPhone: custPhone,
      totalAmount: _billTotal,
      totalProfit: _billProfit,
      items: _cart.map((c) => c.toMap()).toList(),
    );

    final completedItems = List<CartItem>.from(_cart);
    await widget.onCompleteBill(bill, completedItems);

    if (!mounted) return;
    setState(() => _cart.clear());

    // Open Thermal Receipt ("See Bill" screen with WhatsApp Share)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThermalBillReceiptScreen(
          shopName: widget.shopName,
          bill: bill,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A473E),
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on_rounded),
            onPressed: () => _scannerCtrl.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Half: Live Camera Barcode Scanner
          SizedBox(
            height: 215,
            child: MobileScanner(
              controller: _scannerCtrl,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  if (barcode.rawValue != null) {
                    _handleScan(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),
          // Middle Bar: "Bill" + "Loose Item" Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bill',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                ElevatedButton(
                  onPressed: _openLooseItemSelector,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sandMedium,
                    foregroundColor: AppColors.oliveText,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Loose Item',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.sandBorder),
          // Cart Items List
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Text(
                      'Scan any packet barcode or tap "Loose Item"',
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.sandBorder),
                    itemBuilder: (context, idx) {
                      final cItem = _cart[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            buildProductAvatar(cItem.product,
                                size: 42,
                                isLooseDefault: cItem.product.isLoose),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cItem.product.name,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              cItem.product.unit == 'kg'
                                  ? '${cItem.qty} kg'
                                  : '${cItem.qty.toInt()} pc',
                              style:
                                  const TextStyle(color: AppColors.mutedText),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              '₹${cItem.customTotal % 1 == 0 ? cItem.customTotal.toInt() : cItem.customTotal.toStringAsFixed(1)}',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded,
                                  size: 20, color: AppColors.primaryGreen),
                              onPressed: () {
                                final qCtrl = TextEditingController(
                                    text: cItem.qty.toString());
                                showDialog(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    title: Text('Edit ${cItem.product.name}'),
                                    content: TextField(
                                      controller: qCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                          labelText: 'Quantity'),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          final nq =
                                              double.tryParse(qCtrl.text) ??
                                                  cItem.qty;
                                          setState(() {
                                            cItem.qty = nq;
                                            cItem.customTotal =
                                                nq * cItem.product.sellPrice;
                                          });
                                          Navigator.pop(dCtx);
                                        },
                                        child: const Text('Update'),
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 20, color: AppColors.amberGold),
                              onPressed: () =>
                                  setState(() => _cart.removeAt(idx)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Bottom Total + Online / Cash / Udhaar Payment Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 14, 14),
            decoration: const BoxDecoration(
              color: AppColors.cardWhite,
              border: Border(top: BorderSide(color: AppColors.sandBorder)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.mutedText)),
                    Text(
                      '₹${_billTotal % 1 == 0 ? _billTotal.toInt() : _billTotal.toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _cart.isEmpty ? null : _showOnlineUpiQrDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Online',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _cart.isEmpty
                              ? null
                              : () => _finalizeBill(paymentMode: 'Cash'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.amberGold,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cash',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _cart.isEmpty
                              ? null
                              : _showUdhaarCustomerDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sandMedium,
                            foregroundColor: AppColors.oliveText,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Udhaar',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SCREEN: THERMAL RECEIPT ("SEE BILL" + SHARE ON WHATSAPP)
// ============================================================================
class ThermalBillReceiptScreen extends StatelessWidget {
  final String shopName;
  final BillRecord bill;

  const ThermalBillReceiptScreen({
    super.key,
    required this.shopName,
    required this.bill,
  });

  Future<void> _shareOnWhatsApp() async {
    final buffer = StringBuffer();
    buffer.writeln('*$shopName*');
    buffer.writeln(
        'Date: ${DateFormat('dd/MM/yyyy hh:mm a').format(bill.date)}');
    buffer.writeln('Mode: ${bill.paymentMode}');
    buffer.writeln('----------------------');
    for (final item in bill.items) {
      buffer.writeln(
          '${item['name']} (${item['qty']} ${item['unit'] == 'kg' ? 'kg' : 'pc'}) - ₹${item['total']}');
    }
    buffer.writeln('----------------------');
    buffer.writeln('*Total: ₹${bill.totalAmount}*');

    final url = Uri.parse(
        'https://wa.me/${bill.customerPhone.isNotEmpty ? "91${bill.customerPhone}" : ""}?text=${Uri.encodeComponent(buffer.toString())}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        backgroundColor: AppColors.bgCream,
        elevation: 0,
        title: const Text('See Bill',
            style: TextStyle(
                color: AppColors.darkText, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // Thermal Printer Slot Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF282723),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    shopName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            // Receipt Paper
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(18)),
                  border: Border.all(color: AppColors.sandBorder),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('d/M h:mm a').format(bill.date),
                      style: const TextStyle(
                          color: AppColors.mutedText, fontSize: 13),
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: ListView.builder(
                        itemCount: bill.items.length,
                        itemBuilder: (_, idx) {
                          final it = bill.items[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('${it['name']}',
                                      style: const TextStyle(fontSize: 15)),
                                ),
                                Text(
                                    '${it['qty']} ${it['unit'] == 'kg' ? 'kg' : 'pc'}',
                                    style: const TextStyle(
                                        color: AppColors.mutedText)),
                                const SizedBox(width: 16),
                                Text('₹${it['total']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${bill.items.length} items',
                            style: const TextStyle(color: AppColors.mutedText)),
                        Text(
                          '₹${bill.totalAmount % 1 == 0 ? bill.totalAmount.toInt() : bill.totalAmount}',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _shareOnWhatsApp,
                icon: const Icon(Icons.share_rounded, color: Colors.green),
                label: const Text('Share on whatsapp',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sandMedium,
                  foregroundColor: AppColors.oliveText,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.point_of_sale_rounded),
                label: const Text('New bill',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 3: MY SALES (SALES GRAPH + CHAT-STYLE UDHAAR KHATA + TOP 50 ITEMS)
// ============================================================================
class MySalesTab extends StatefulWidget {
  final List<BillRecord> bills;
  final List<UdhaarCustomer> customers;
  final List<ProductItem> products;
  final List<ExpenseRecord> expenses;
  final String shopName;
  final Future<void> Function(UdhaarCustomer) onSaveCustomer;
  final Future<void> Function(ExpenseRecord) onAddExpense;
  final VoidCallback onGoToPending;

  const MySalesTab({
    super.key,
    required this.bills,
    required this.customers,
    required this.products,
    required this.expenses,
    required this.shopName,
    required this.onSaveCustomer,
    required this.onAddExpense,
    required this.onGoToPending,
  });

  @override
  State<MySalesTab> createState() => _MySalesTabState();
}

class _MySalesTabState extends State<MySalesTab> {
  int _subTab = 0; // 0 = Sales, 1 = Udhaar, 2 = Top 50 Medal
  String _udhaarSearch = '';
  UdhaarCustomer? _selectedCustomer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top 3 Sub-Tabs: Sales | Udhaar | Top 50 Medal
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () => setState(() => _subTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _subTab == 0
                          ? AppColors.sandMedium
                          : AppColors.cardWhite,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                      border: Border.all(color: AppColors.sandBorder),
                    ),
                    child: const Text('Sales',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () => setState(() => _subTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _subTab == 1
                          ? AppColors.sandMedium
                          : AppColors.cardWhite,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                      border: Border.all(color: AppColors.sandBorder),
                    ),
                    child: const Text('Udhaar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => setState(() => _subTab = 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _subTab == 2
                          ? AppColors.sandMedium
                          : AppColors.cardWhite,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                      border: Border.all(color: AppColors.sandBorder),
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: AppColors.amberGold, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _subTab == 0
              ? _buildSalesView()
              : (_subTab == 1 ? _buildUdhaarSplitView() : _buildTop50View()),
        ),
      ],
    );
  }

  // Sub-Tab 1: Daily Sales + 5-Day Bar Chart + Expenses + Bills of the day
  Widget _buildSalesView() {
    final now = DateTime.now();
    final todayBills = widget.bills
        .where((b) =>
            b.date.year == now.year &&
            b.date.month == now.month &&
            b.date.day == now.day)
        .toList();
    final todaySales =
        todayBills.fold<double>(0, (s, b) => s + b.totalAmount);
    final todayGrossProfit =
        todayBills.fold<double>(0, (s, b) => s + b.totalProfit);
    final todayExpenses = widget.expenses
        .where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day)
        .fold<double>(0, (s, e) => s + e.amount);
    final netProfit = todayGrossProfit - todayExpenses;
    final pendingCount = widget.products.where((p) => p.isPending).length;

    // Last 5 days bar values
    final last5Days = List.generate(5, (i) {
      final d = now.subtract(Duration(days: 4 - i));
      final total = widget.bills
          .where((b) =>
              b.date.year == d.year &&
              b.date.month == d.month &&
              b.date.day == d.day)
          .fold<double>(0, (s, b) => s + b.totalAmount);
      return {'date': d, 'total': total};
    });
    final maxBar = last5Days.fold<double>(
        10, (m, e) => max(m, (e['total'] as double)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.sandBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sales of day',
                            style: TextStyle(
                                color: AppColors.mutedText, fontSize: 13)),
                        Text(
                          '₹${todaySales.toInt()}',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Net Profit: ₹${netProfit.toInt()} (Exp: ₹${todayExpenses.toInt()})',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.sandLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.sandBorder),
                          ),
                          child: Text(
                            DateFormat('MMMM yy').format(now),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddExpenseDialog,
                          icon: const Icon(Icons.add_circle_outline, size: 16),
                          label: const Text('+ Add Kharcha',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                if (pendingCount > 0)
                  GestureDetector(
                    onTap: widget.onGoToPending,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Clear Pending items to see exact profit >',
                        style: TextStyle(
                          color: AppColors.amberGold,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                // 5-Day Sales Bar Graph
                SizedBox(
                  height: 130,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: last5Days.map((entry) {
                      final dt = entry['date'] as DateTime;
                      final val = entry['total'] as double;
                      final isToday = dt.day == now.day;
                      final barHeight = max(6.0, (val / maxBar) * 85);

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('₹${val.toInt()}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.mutedText)),
                          const SizedBox(height: 4),
                          Container(
                            width: 34,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppColors.primaryGreen
                                  : AppColors.sandBorder,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isToday
                                ? 'Today'
                                : DateFormat('d MMM').format(dt),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isToday ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('Bills of the day',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.oliveText)),
          const SizedBox(height: 8),
          ...todayBills.map((b) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sandBorder),
                ),
                child: Row(
                  children: [
                    Text(DateFormat('HH:mm').format(b.date),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: b.paymentMode == 'Udhaar'
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        b.paymentMode,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: b.paymentMode == 'Udhaar'
                              ? AppColors.dangerRed
                              : AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text('${b.items.length} Items',
                        style: const TextStyle(color: AppColors.mutedText)),
                    const SizedBox(width: 14),
                    Text('₹${b.totalAmount.toInt()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Shop Expense (Kharcha)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration:
                  const InputDecoration(labelText: 'Detail (e.g. Chai, Bijli)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text) ?? 0;
              if (amt <= 0) return;
              await widget.onAddExpense(ExpenseRecord(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleCtrl.text.trim().isEmpty
                    ? 'Shop Kharcha'
                    : titleCtrl.text.trim(),
                amount: amt,
                date: DateTime.now(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Sub-Tab 2: Chat-Style Udhaar Khata Split View ("Got money" Partial Payment + WhatsApp Reminder)
  Widget _buildUdhaarSplitView() {
    final filtered = widget.customers
        .where((c) =>
            c.name.toLowerCase().contains(_udhaarSearch.toLowerCase()) ||
            c.phone.contains(_udhaarSearch))
        .toList();

    if (_selectedCustomer != null) {
      final refreshed = widget.customers
          .cast<UdhaarCustomer?>()
          .firstWhere((c) => c?.id == _selectedCustomer!.id, orElse: () => null);
      _selectedCustomer = refreshed;
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _udhaarSearch = v),
            decoration: InputDecoration(
              hintText: 'Search name or phone number',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.cardWhite,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sandBorder),
              ),
              child: Row(
                children: [
                  // Left Column: Customer List
                  SizedBox(
                    width: 132,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(6),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final cust = filtered[idx];
                        final isSel = _selectedCustomer?.id == cust.id;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCustomer = cust),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.sandMedium
                                  : AppColors.sandLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.sandBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cust.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  cust.phone,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.mutedText),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.sandBorder),
                  // Right Column: Selected Customer Chat-Style Ledger
                  Expanded(
                    child: _selectedCustomer == null
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_rounded,
                                    size: 36, color: AppColors.amberGold),
                                SizedBox(height: 8),
                                Text(
                                  'Select Customer to see\nudhaar khaata',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(color: AppColors.mutedText),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // Total Udhaar + WhatsApp Reminder Header
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Total Udhaar',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.mutedText)),
                                        Text(
                                          '₹${_selectedCustomer!.totalDue.toStringAsFixed(1)}',
                                          style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      onPressed: () => _sendWhatsAppReminder(
                                          _selectedCustomer!),
                                      icon: const Icon(Icons.chat_rounded,
                                          color: Colors.green, size: 28),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              // Chat History (Items Taken vs Partial Payments Received)
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _selectedCustomer!.history.length,
                                  itemBuilder: (ctx, idx) {
                                    final entry =
                                        _selectedCustomer!.history[idx];
                                    return Align(
                                      alignment: entry.isPayment
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: entry.isPayment
                                              ? Colors.green.shade50
                                              : AppColors.sandLight,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: entry.isPayment
                                                ? Colors.green.shade200
                                                : AppColors.sandBorder,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  DateFormat('d MMM, H:mm')
                                                      .format(entry.date),
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          AppColors.mutedText),
                                                ),
                                                Text(
                                                  entry.isPayment
                                                      ? '- ₹${entry.amount} Jama'
                                                      : '₹${entry.amount}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: entry.isPayment
                                                        ? AppColors.primaryGreen
                                                        : AppColors.darkText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (entry.items.isNotEmpty) ...[
                                              const Divider(height: 8),
                                              ...entry.items.map((it) => Text(
                                                    '• ${it['name']} (${it['qty']} ${it['unit'] == 'kg' ? 'kg' : 'pc'})',
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  )),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Partial / Full Payment Receive Button ("Got money")
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _showGotMoneyDialog(_selectedCustomer!),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Got money',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGotMoneyDialog(UdhaarCustomer cust) {
    final amtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Receive Payment from ${cust.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Baaki: ₹${cust.totalDue.toStringAsFixed(1)}'),
            const SizedBox(height: 10),
            TextField(
              controller: amtCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Kitna rupaya jama kiya? (₹)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final paid = double.tryParse(amtCtrl.text) ?? 0;
              if (paid <= 0) return;

              final entry = UdhaarEntry(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                date: DateTime.now(),
                isPayment: true,
                amount: paid,
              );
              cust.totalDue = max(0, cust.totalDue - paid);
              cust.history = [entry, ...cust.history];
              await widget.onSaveCustomer(cust);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white),
            child: const Text('Save Jama'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWhatsAppReminder(UdhaarCustomer cust) async {
    final msg =
        'Namaste *${cust.name}*,\n\nThis is a gentle reminder regarding your pending udhaar at *${widget.shopName}*:\n💰 *Total Pending: ₹${cust.totalDue.toStringAsFixed(0)}*';
    final url = Uri.parse(
        'https://wa.me/91${cust.phone}?text=${Uri.encodeComponent(msg)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // Sub-Tab 3: Top 50 Selling Items Ranking (Matches Vanik Medal Screen)
  Widget _buildTop50View() {
    final ranked = List<ProductItem>.from(widget.products)
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    final top50 = ranked.take(50).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.sandLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.sandBorder),
          ),
          child: const Text(
            'Top 50 selling items of your shop',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.oliveText),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: top50.length,
            itemBuilder: (_, idx) {
              final item = top50[idx];
              final unitProfit = max(0, item.sellPrice - item.buyPrice);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.sandBorder),
                ),
                child: Row(
                  children: [
                    buildProductAvatar(item,
                        size: 48, isLooseDefault: item.isLoose),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text('₹${item.sellPrice.toInt()}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text('₹${unitProfit.toStringAsFixed(1)} profit',
                                  style: const TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text('Sold ${item.soldCount}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.mutedText)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SCREEN: MY PROFILE (MY PLAN | SETTINGS: UPI QR & 6-DIGIT STAFF APPROVAL | ORDERS)
// ============================================================================
class MyProfileScreen extends StatefulWidget {
  final bool firebaseReady;
  final String shopId;
  final String shopName;
  final String ownerPhone;
  final String joinCode;
  final String upiId;
  final String language;
  final String userRole;
  final List<StaffMember> staffList;
  final List<BillRecord> bills;
  final int initialTab;
  final Future<void> Function(String) onSaveUpi;
  final Future<void> Function(StaffMember, String) onApproveStaff;
  final Future<void> Function(StaffMember) onRemoveStaff;
  final VoidCallback onLogout;

  const MyProfileScreen({
    super.key,
    required this.firebaseReady,
    required this.shopId,
    required this.shopName,
    required this.ownerPhone,
    required this.joinCode,
    required this.upiId,
    required this.language,
    required this.userRole,
    required this.staffList,
    required this.bills,
    this.initialTab = 0,
    required this.onSaveUpi,
    required this.onApproveStaff,
    required this.onRemoveStaff,
    required this.onLogout,
  });

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late int _tab;
  late TextEditingController _upiCtrl;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _upiCtrl = TextEditingController(text: widget.upiId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        backgroundColor: AppColors.bgCream,
        elevation: 0,
        title: const Text('My profile',
            style: TextStyle(
                color: AppColors.darkText, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Owner Info + Log Out
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.sandLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.sandBorder),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.primaryGreen, size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.shopName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(widget.ownerPhone,
                          style: const TextStyle(color: AppColors.mutedText)),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: widget.onLogout,
                  child: const Text('Log Out'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 3 Tabs: My Plan | Settings | Orders
            Row(
              children: [
                _profileTabBtn('My Plan', 0),
                const SizedBox(width: 6),
                _profileTabBtn('Settings', 1),
                const SizedBox(width: 6),
                _profileTabBtn('Orders', 2),
              ],
            ),
            const SizedBox(height: 16),
            if (_tab == 0) _buildPlanTab(),
            if (_tab == 1) _buildSettingsTab(),
            if (_tab == 2) _buildOrdersTab(),
          ],
        ),
      ),
    );
  }

  Widget _profileTabBtn(String label, int idx) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.sandMedium : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.sandBorder),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPlanTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sandBorder),
      ),
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cloud POS Active',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Unlimited Bills, Cloud Sync & Staff Access',
                      style: TextStyle(color: AppColors.mutedText)),
                ],
              ),
              Icon(Icons.verified_rounded,
                  color: AppColors.primaryGreen, size: 34),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Column(
      children: [
        // UPI ID Box for Dynamic QR Code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.sandLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.sandBorder),
          ),
          child: Column(
            children: [
              const Text('Enter UPI ID to make QR code',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.oliveText)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _upiCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. 6202187843@ybl',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await widget.onSaveUpi(_upiCtrl.text.trim());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('UPI ID Saved!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amberGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Icon(Icons.check_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 6-Digit Staff Joining Code + Owner Approval List
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.sandLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.sandBorder),
          ),
          child: Column(
            children: [
              const Text('Joining code for your staff to join your shop',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.oliveText)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.joinCode.isEmpty ? '765177' : widget.joinCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4),
                ),
              ),
              if (widget.userRole == 'owner') ...[
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Staff & Family Requests / Permissions:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                if (widget.staffList.isEmpty)
                  const Text('No staff requests yet.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.mutedText))
                else
                  ...widget.staffList.map((s) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s.name} (${s.contact})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('Status: ${s.status.toUpperCase()} | Role: ${s.role}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.mutedText)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (s.status == 'pending') ...[
                                  ElevatedButton(
                                    onPressed: () =>
                                        widget.onApproveStaff(s, 'billing'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryGreen,
                                        foregroundColor: Colors.white),
                                    child: const Text('Approve (Billing)'),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton(
                                    onPressed: () =>
                                        widget.onApproveStaff(s, 'full'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.amberGold,
                                        foregroundColor: Colors.white),
                                    child: const Text('Full Access'),
                                  ),
                                ],
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.dangerRed),
                                  onPressed: () => widget.onRemoveStaff(s),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    if (widget.bills.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No bills generated yet.'),
      );
    }
    return Column(
      children: widget.bills
          .take(30)
          .map((b) => ListTile(
                tileColor: Colors.white,
                title: Text(
                    'Bill ₹${b.totalAmount.toInt()} (${b.paymentMode})'),
                subtitle:
                    Text(DateFormat('dd MMM yyyy, hh:mm a').format(b.date)),
                trailing: Text('${b.items.length} items'),
              ))
          .toList(),
    );
  }
}
