import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const VanikCompleteMasterApp());
}

// ============================================================================
// 1. VANIK COLOR THEME CONSTANTS
// ============================================================================
class VanikTheme {
  static const Color scaffoldBg = Color(0xFFFBF8F2);
  static const Color darkGreen = Color(0xFF2E6038);
  static const Color accentGreen = Color(0xFF8BB585);
  static const Color darkMustard = Color(0xFFD48B38);
  static const Color borderGrey = Color(0xFFE2DAC8);
  static const Color chipBackground = Color(0xFFF1EBDD);
  static const Color chipHighlight = Color(0xFFE8DECB);
  static const Color alertRed = Color(0xFFD32F2F);
  static const Color textBlack = Color(0xFF212121);
  static const Color textGrey = Color(0xFF757575);
  static const Color scannerYellow = Color(0xFFF59E0B);
}

// ============================================================================
// 2. DATA MODELS
// ============================================================================
class ShopSession {
  String ownerPhone;
  String shopName;
  String joiningCode;
  String language;
  bool isLoggedIn;

  ShopSession({
    this.ownerPhone = '',
    this.shopName = '',
    this.joiningCode = '',
    this.language = 'English',
    this.isLoggedIn = false,
  });
}

class ProductEntity {
  final String id;
  String name;
  String? barcode;
  double buyPrice;
  double sellPrice;
  double stock;
  String unit; // 'kilo' ya 'piece'
  bool isLoose;
  bool isPending;
  String? photoTag;

  ProductEntity({
    required this.id,
    required this.name,
    this.barcode,
    required this.buyPrice,
    required this.sellPrice,
    required this.stock,
    required this.unit,
    this.isLoose = false,
    this.isPending = false,
    this.photoTag,
  });
}

class BillCartEntry {
  final ProductEntity product;
  double quantity;
  double customRupeeOverride;

  BillCartEntry({
    required this.product,
    required this.quantity,
    this.customRupeeOverride = 0.0,
  });

  double get calculatedLineTotal =>
      customRupeeOverride > 0 ? customRupeeOverride : (product.sellPrice * quantity);
}

class UdharCustomerEntity {
  final String id;
  final String personName;
  final String phoneNumber;
  double pendingAmount;
  final DateTime registeredAt;
  bool isPaid;
  final List<String> purchaseSummary;

  UdharCustomerEntity({
    required this.id,
    required this.personName,
    required this.phoneNumber,
    required this.pendingAmount,
    required this.registeredAt,
    this.isPaid = false,
    required this.purchaseSummary,
  });
}

class OrderTransaction {
  final String orderId;
  final DateTime timestamp;
  final double billedAmount;
  final String paymentMode; // 'Online', 'Cash', 'Udhaar'
  final List<BillCartEntry> soldItems;

  OrderTransaction({
    required this.orderId,
    required this.timestamp,
    required this.billedAmount,
    required this.paymentMode,
    required this.soldItems,
  });
}

// ============================================================================
// 3. ROOT WIDGET
// ============================================================================
class VanikCompleteMasterApp extends StatelessWidget {
  const VanikCompleteMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'General Store',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: VanikTheme.scaffoldBg,
        primaryColor: VanikTheme.darkGreen,
        fontFamily: 'sans-serif',
      ),
      home: const OnboardingFlowManager(),
    );
  }
}

// ============================================================================
// 4. ONBOARDING MANAGER (LOGIN WITH MOBILE -> SHOP NAME SETUP)
// ============================================================================
class OnboardingFlowManager extends StatefulWidget {
  const OnboardingFlowManager({super.key});

  @override
  State<OnboardingFlowManager> createState() => _OnboardingFlowManagerState();
}

class _OnboardingFlowManagerState extends State<OnboardingFlowManager> {
  final ShopSession _session = ShopSession();
  int _onboardingStep = 0; // 0: Mobile Input, 1: OTP, 2: Shop Name Setup, 3: App Dashboard

  final TextEditingController _mobilePhoneCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController(text: '1234');
  final TextEditingController _storeNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  Future<void> _checkSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final bool loggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (loggedIn) {
      final String shop = prefs.getString('savedShopName') ?? 'General Store';
      final String phone = prefs.getString('savedPhone') ?? '';
      setState(() {
        _session.shopName = shop;
        _session.ownerPhone = phone;
        _session.isLoggedIn = true;
        _onboardingStep = 3;
      });
    }
  }
  void _proceedToShopName() {
    if (_mobilePhoneCtrl.text.trim().length >= 10) {
      setState(() {
        _session.ownerPhone = _mobilePhoneCtrl.text.trim();
        _onboardingStep = 2;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya sahi 10 digit mobile number dalein')),
      );
    }
  }

  void _completeShopSetup() async {
    if (_storeNameCtrl.text.trim().isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('savedShopName', _storeNameCtrl.text.trim());
      await prefs.setString('savedPhone', _mobilePhoneCtrl.text.trim());

      setState(() {
        _session.shopName = _storeNameCtrl.text.trim();
        _session.ownerPhone = _mobilePhoneCtrl.text.trim();
        _session.joiningCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
        _session.isLoggedIn = true;
        _onboardingStep = 3;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dukan ka naam likhna zaroori hai!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingStep == 3 && _session.isLoggedIn) {
      return VanikAppScaffold(
        session: _session,
        onLogout: () {
          setState(() {
            _session.isLoggedIn = false;
            _onboardingStep = 0;
            _mobilePhoneCtrl.clear();
            _storeNameCtrl.clear();
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: VanikTheme.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: VanikTheme.borderGrey),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo / Banner Header
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: VanikTheme.chipBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.storefront, color: VanikTheme.darkGreen, size: 38),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'General Store POS',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: VanikTheme.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _onboardingStep == 0
                        ? 'Dukandar Mobile Login'
                        : _onboardingStep == 1
                            ? 'OTP Verification'
                            : 'Dukan Setup Karein',
                    style: const TextStyle(fontSize: 14, color: VanikTheme.textGrey),
                  ),
                  const SizedBox(height: 24),

                  // Step 0: Mobile Number
                  if (_onboardingStep == 0) ...[
                    TextField(
                      controller: _mobilePhoneCtrl,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.phone_android, color: VanikTheme.darkMustard),
                        labelText: 'Mobile Number',
                        hintText: 'Enter 10 digit number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VanikTheme.darkGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _proceedToOtp,
                        child: const Text('Continue / OTP Bhejein', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ]
                  // Step 1: OTP Screen
                  else if (_onboardingStep == 1) ...[
                    TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 6),
                    decoration: InputDecoration(
                      labelText: '4-Digit OTP Dalein',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VanikTheme.darkMustard,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _verifyOtp,
                        child: const Text('Verify & Aage Badhein', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ]
                  // Step 2: Dukan Name Input
                  else if (_onboardingStep == 2) ...[
                    TextField(
                      controller: _storeNameCtrl,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.store, color: VanikTheme.darkGreen),
                        labelText: 'Apni Dukan Ka Naam',
                        hintText: 'e.g. Mahato General Store',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VanikTheme.darkGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _completeShopSetup,
                        child: const Text('Dukan Shuru Karein', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. VANIK APP SCAFFOLD (NAVBAR, TOP BAR & TABS)
// ============================================================================
class VanikAppScaffold extends StatefulWidget {
  final ShopSession session;
  final VoidCallback onLogout;

  const VanikAppScaffold({
    super.key,
    required this.session,
    required this.onLogout,
  });

  @override
  State<VanikAppScaffold> createState() => _VanikAppScaffoldState();
}

class _VanikAppScaffoldState extends State<VanikAppScaffold> {
  int _activeNav = 0; // 0: My Shop, 1: Make Bill, 2: My Sales

  // Zero initial items for fresh public store catalog
  final List<ProductEntity> _storeCatalog = [];
  final List<BillCartEntry> _workingCart = [];
  final List<UdharCustomerEntity> _udharCustomerLedger = [];
  final List<OrderTransaction> _pastOrders = [];

  double get _cartGrandTotal =>
      _workingCart.fold(0.0, (acc, entry) => acc + entry.calculatedLineTotal);

  // Open Store Header Profile
  void _openProfileModal() {
    final nameEditor = TextEditingController(text: widget.session.shopName);
    final phoneEditor = TextEditingController(text: widget.session.ownerPhone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 24, left: 20, right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: VanikTheme.chipBackground,
                  child: Icon(Icons.person, color: Color(0xFF6B8065), size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.session.shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(widget.session.ownerPhone, style: const TextStyle(color: VanikTheme.textGrey, fontSize: 13)),
                    ],
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: VanikTheme.borderGrey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onLogout();
                  },
                  child: const Text('Log Out', style: TextStyle(color: VanikTheme.darkMustard, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F4EC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: VanikTheme.borderGrey),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Language', style: TextStyle(color: VanikTheme.textGrey, fontSize: 11)),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('English', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Icon(Icons.arrow_drop_down, size: 20, color: Colors.black54),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F4EC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: VanikTheme.borderGrey),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Joining code', style: TextStyle(color: VanikTheme.textGrey, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(widget.session.joiningCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: VanikTheme.darkGreen)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameEditor,
              decoration: const InputDecoration(labelText: 'Dukan Ka Naam', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneEditor,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VanikTheme.darkMustard,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  setState(() {
                    if (nameEditor.text.trim().isNotEmpty) widget.session.shopName = nameEditor.text.trim();
                    if (phoneEditor.text.trim().isNotEmpty) widget.session.ownerPhone = phoneEditor.text.trim();
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Save Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VanikTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _openProfileModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: VanikTheme.chipBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, color: Color(0xFF6B8065), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            widget.session.shopName.length > 18
                                ? '${widget.session.shopName.substring(0, 16)}...'
                                : widget.session.shopName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: VanikTheme.textBlack),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 12, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: VanikTheme.borderGrey),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, color: VanikTheme.darkMustard, size: 16),
                        const SizedBox(width: 6),
                        Text('Orders: ${_pastOrders.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: VanikTheme.darkGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),

            // Tab View Body
            Expanded(
              child: IndexedStack(
                index: _activeNav,
                children: [
                  MyShopScreenEngine(
                    catalog: _storeCatalog,
                    onSaveItem: (item) => setState(() => _storeCatalog.add(item)),
                    onRefresh: () => setState(() {}),
                    onDelete: (id) => setState(() => _storeCatalog.removeWhere((p) => p.id == id)),
                    pendingItemsCount: _storeCatalog.where((p) => p.isPending).length,
                  ),
                  MakeBillScreenEngine(
                    catalog: _storeCatalog,
                    cartItems: _workingCart,
                    onCartAdd: (item, qty, [customRupee = 0.0]) {
                      setState(() {
                        final found = _workingCart.indexWhere(
                            (c) => c.product.id == item.id && c.customRupeeOverride == customRupee);
                        if (found >= 0) {
                          _workingCart[found].quantity += qty;
                        } else {
                          _workingCart.add(BillCartEntry(product: item, quantity: qty, customRupeeOverride: customRupee));
                        }
                      });
                    },
                    onCartRemove: (idx) => setState(() => _workingCart.removeAt(idx)),
                    onClearCart: () => setState(() => _workingCart.clear()),
                    onCheckoutFinalized: (mode, [name, phone]) {
                      final total = _cartGrandTotal;
                      if (total <= 0) return;
                      setState(() {
                        _pastOrders.add(OrderTransaction(
                          orderId: DateTime.now().millisecondsSinceEpoch.toString(),
                          timestamp: DateTime.now(),
                          billedAmount: total,
                          paymentMode: mode,
                          soldItems: List.from(_workingCart),
                        ));

                        // Minus Stock Automatically
                        for (var c in _workingCart) {
                          c.product.stock = (c.product.stock - c.quantity).clamp(0.0, 999999.0);
                        }

                        if (mode == 'Udhaar') {
                          _udharCustomerLedger.add(UdharCustomerEntity(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            personName: (name != null && name.isNotEmpty) ? name : 'Grahak',
                            phoneNumber: phone ?? '',
                            pendingAmount: total,
                            registeredAt: DateTime.now(),
                            purchaseSummary: _workingCart.map((i) => '${i.product.name} (${i.quantity.toInt()} ${i.product.unit})').toList(),
                          ));
                        }
                      });
                    },
                    onUnknownBarcodeFound: (code, sellRate) {
                      final pendingItem = ProductEntity(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: 'Scanned Item $code',
                        barcode: code,
                        buyPrice: 0.0,
                        sellPrice: sellRate,
                        stock: 10,
                        unit: 'piece',
                        isPending: true,
                      );
                      setState(() {
                        _storeCatalog.add(pendingItem);
                        _workingCart.add(BillCartEntry(product: pendingItem, quantity: 1));
                      });
                    },
                  ),
                  MySalesScreenEngine(
                    orders: _pastOrders,
                    udharLedger: _udharCustomerLedger,
                    onPayMarked: (id) {
                      setState(() {
                        final rec = _udharCustomerLedger.firstWhere((u) => u.id == id);
                        rec.isPaid = true;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // 3D Bottom Navigation
      bottomNavigationBar: Container(
        height: 74,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEFE9DC))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavBtn(0, 'My Shop', Icons.storefront),
            GestureDetector(
              onTap: () => setState(() => _activeNav = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                decoration: BoxDecoration(
                  color: _activeNav == 1 ? const Color(0xFF7CA677) : const Color(0xFF8BB585),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      offset: const Offset(0, 4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, color: Colors.white, size: 24),
                    SizedBox(height: 2),
                    Text(
                      'Make Bill',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomNavBtn(2, 'My Sales', Icons.account_balance_wallet_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBtn(int idx, String title, IconData icon) {
    final isSelected = _activeNav == idx;
    return InkWell(
      onTap: () => setState(() => _activeNav = idx),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? VanikTheme.darkGreen : Colors.grey, size: 24),
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? VanikTheme.darkGreen : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. SCREEN 1: MY SHOP (BARCODE & LOOSE COMMODITY SYSTEM)
// ============================================================================
class MyShopScreenEngine extends StatefulWidget {
  final List<ProductEntity> catalog;
  final Function(ProductEntity) onSaveItem;
  final VoidCallback onRefresh;
  final Function(String) onDelete;
  final int pendingItemsCount;

  const MyShopScreenEngine({
    super.key,
    required this.catalog,
    required this.onSaveItem,
    required this.onRefresh,
    required this.onDelete,
    required this.pendingItemsCount,
  });

  @override
  State<MyShopScreenEngine> createState() => _MyShopScreenEngineState();
}

class _MyShopScreenEngineState extends State<MyShopScreenEngine> {
  int _categoryIndex = 0; // 0: Barcode items, 1: Loose items
  int _statusFilter = 0;   // 0: Shop items, 1: Pending
  String _searchQuery = '';

  // Loose Item Addition Modal (Kilo vs Piece Switch)
  void _openAddLooseItemDialog() {
    String unitMode = 'kilo';
    File? pickedPhotoFile;
    final nameInput = TextEditingController();
    final wholeStockMoneyInput = TextEditingController();
    final quantityBoughtInput = TextEditingController();
    final sellingPriceInput = TextEditingController();
    final currentStockInput = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: EdgeInsets.only(
            top: 20, left: 18, right: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        // Photo Picker Box (Live Camera)
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 60,
                  );
                  if (picked != null) {
                    setDialogState(() {
                      pickedPhotoFile = File(picked.path);
                    });
                  }
                },
                child: Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EBDD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: pickedPhotoFile != null ? Colors.green : const Color(0xFF3B5C35).withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: pickedPhotoFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(pickedPhotoFile!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: Color(0xFF3B5C35), size: 24),
                            SizedBox(height: 2),
                            Text('Photo', style: TextStyle(fontSize: 10, color: Color(0xFF3B5C35), fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
                        const SizedBox(height: 6),
                        // Segmented Kilo vs Piece Switch
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8DECB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => setDialogState(() => unitMode = 'kilo'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: unitMode == 'kilo' ? VanikTheme.darkMustard : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Kilo', style: TextStyle(color: unitMode == 'kilo' ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setDialogState(() => unitMode = 'piece'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: unitMode == 'piece' ? VanikTheme.darkMustard : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Piece', style: TextStyle(color: unitMode == 'piece' ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF8F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: VanikTheme.borderGrey),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Product name', style: TextStyle(color: VanikTheme.darkMustard, fontSize: 11, fontWeight: FontWeight.bold)),
                            TextField(
                              controller: nameInput,
                              decoration: const InputDecoration(hintText: 'Write here', border: InputBorder.none, isDense: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildModalTextField(controller: wholeStockMoneyInput, label: 'Money you paid for whole stock (₹)'),
                const SizedBox(height: 10),
                _buildModalTextField(
                  controller: quantityBoughtInput,
                  label: unitMode == 'kilo' ? 'No. of kilos bought in that money' : 'No. of pieces bought in that money',
                ),
                const SizedBox(height: 10),
                _buildModalTextField(
                  controller: sellingPriceInput,
                  label: unitMode == 'kilo' ? 'Your selling price of 1 Kg' : 'Your selling price of 1 Piece(₹)',
                ),
                const SizedBox(height: 10),
                _buildModalTextField(
                  controller: currentStockInput,
                  label: unitMode == 'kilo' ? 'Current kilos in shop' : 'Current pieces in shop',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VanikTheme.darkMustard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (nameInput.text.isNotEmpty && sellingPriceInput.text.isNotEmpty) {
                        double totalCost = double.tryParse(wholeStockMoneyInput.text) ?? 0.0;
                        double qtyTotal = double.tryParse(quantityBoughtInput.text) ?? 1.0;
                        double calculatedBuy = qtyTotal > 0 ? (totalCost / qtyTotal) : 0.0;

                        widget.onSaveItem(ProductEntity(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameInput.text.trim(),
                          buyPrice: calculatedBuy,
                          sellPrice: double.tryParse(sellingPriceInput.text) ?? 0.0,
                          stock: double.tryParse(currentStockInput.text) ?? qtyTotal,
                          unit: unitMode,
                          isLoose: true,
                          isPending: false,
                        ));
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Add stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Stock Barcode Items Modal
  void _openStockBarcodeItemDialog() {
    final barcodeInput = TextEditingController(text: '8904063254450');
    final nameInput = TextEditingController();
    final wholeStockMoneyInput = TextEditingController();
    final piecesBoughtInput = TextEditingController();
    final sellingPriceInput = TextEditingController();
    final currentPiecesInput = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(top: 20, left: 18, right: 18, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Packet photo captured!')));
                    },
                    child: Container(
                      width: 76, height: 76,
                      decoration: BoxDecoration(color: const Color(0xFFF1EBDD), borderRadius: BorderRadius.circular(12)),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, color: VanikTheme.darkMustard, size: 28),
                          SizedBox(height: 2),
                          Text('Photo', style: TextStyle(fontSize: 10, color: VanikTheme.darkMustard, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(barcodeInput.text, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFFBF8F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: VanikTheme.borderGrey)),
                          child: TextField(
                            controller: nameInput,
                            decoration: const InputDecoration(hintText: 'Product name', border: InputBorder.none, isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildModalTextField(controller: wholeStockMoneyInput, label: 'Money you paid for whole stock (₹)'),
              const SizedBox(height: 10),
              _buildModalTextField(controller: piecesBoughtInput, label: 'No. of pieces bought in that money'),
              const SizedBox(height: 10),
              _buildModalTextField(controller: sellingPriceInput, label: 'Selling price of single unit (₹)'),
              const SizedBox(height: 10),
              _buildModalTextField(controller: currentPiecesInput, label: 'Current pieces in shop'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: VanikTheme.darkMustard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    if (nameInput.text.isNotEmpty && sellingPriceInput.text.isNotEmpty) {
                      double costPaid = double.tryParse(wholeStockMoneyInput.text) ?? 0.0;
                      double pieceCount = double.tryParse(piecesBoughtInput.text) ?? 1.0;
                      double buyPerPiece = pieceCount > 0 ? (costPaid / pieceCount) : 0.0;

                      widget.onSaveItem(ProductEntity(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameInput.text.trim(),
                        barcode: barcodeInput.text.trim(),
                        buyPrice: buyPerPiece,
                        sellPrice: double.tryParse(sellingPriceInput.text) ?? 0.0,
                        stock: double.tryParse(currentPiecesInput.text) ?? pieceCount,
                        unit: 'piece',
                        isLoose: false,
                        isPending: false,
                      ));
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Add stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Update / Settle Item Dialog
  void _openProductEditDialog(ProductEntity item) {
    final buyCtrl = TextEditingController(text: item.buyPrice > 0 ? item.buyPrice.toStringAsFixed(0) : '');
    final sellCtrl = TextEditingController(text: item.sellPrice > 0 ? item.sellPrice.toStringAsFixed(0) : '');
    final stockCtrl = TextEditingController(text: item.stock > 0 ? item.stock.toStringAsFixed(0) : '');
    final nameCtrl = TextEditingController(text: item.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(top: 20, left: 18, right: 18, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.barcode != null) ...[
                Align(alignment: Alignment.centerRight, child: Text(item.barcode!, style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold))),
                const SizedBox(height: 6),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 76, height: 76,
                    decoration: BoxDecoration(color: const Color(0xFFF1EBDD), borderRadius: BorderRadius.circular(12)),
                    child: Icon(item.isLoose ? Icons.shopping_bag : Icons.inventory_2_outlined, color: VanikTheme.darkMustard, size: 36),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFFBF8F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: VanikTheme.borderGrey)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Product name', style: TextStyle(color: VanikTheme.darkMustard, fontSize: 11, fontWeight: FontWeight.bold)),
                          TextField(controller: nameCtrl, decoration: const InputDecoration(border: InputBorder.none, isDense: true)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildModalTextField(controller: buyCtrl, label: item.unit == 'kilo' ? 'Buying price of 1 Kg' : 'Buying price of 1 Piece'),
              const SizedBox(height: 10),
              _buildModalTextField(controller: sellCtrl, label: item.unit == 'kilo' ? 'Your selling price of 1 Kg' : 'Your selling price of 1 Piece(₹)'),
              const SizedBox(height: 10),
              _buildModalTextField(controller: stockCtrl, label: item.unit == 'kilo' ? 'Current kilos in shop' : 'Current pieces in shop'),
              const SizedBox(height: 18),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 28),
                    onPressed: () {
                      widget.onDelete(item.id);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: item.isPending ? VanikTheme.darkGreen : VanikTheme.darkMustard,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() {
                            item.name = nameCtrl.text.trim();
                            item.buyPrice = double.tryParse(buyCtrl.text) ?? item.buyPrice;
                            item.sellPrice = double.tryParse(sellCtrl.text) ?? item.sellPrice;
                            item.stock = double.tryParse(stockCtrl.text) ?? item.stock;
                            item.isPending = false;
                          });
                          widget.onRefresh();
                          Navigator.pop(ctx);
                        },
                        child: Text(item.isPending ? 'Save' : 'Update', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalTextField({required TextEditingController controller, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: VanikTheme.borderGrey)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: VanikTheme.textGrey, fontSize: 11)),
          TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleList = widget.catalog.where((item) {
      final matchesName = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      if (_statusFilter == 1) return matchesName && item.isPending;
      if (_categoryIndex == 1) return matchesName && item.isLoose && !item.isPending;
      return matchesName && !item.isLoose && !item.isPending;
    }).toList();

    return Column(
      children: [
        // Shop items count / Pending badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _statusFilter = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _statusFilter == 0 ? VanikTheme.chipHighlight : const Color(0xFFF3EFE6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Shop items: ${widget.catalog.where((i) => !i.isPending).length}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _statusFilter == 0 ? const Color(0xFF4A3B22) : Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _statusFilter = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _statusFilter == 1 ? VanikTheme.chipHighlight : const Color(0xFFF3EFE6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Pending ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _statusFilter == 1 ? const Color(0xFF4A3B22) : Colors.grey)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusFilter == 1 ? VanikTheme.darkMustard : Colors.grey,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${widget.pendingItemsCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search Bar with Barcode vs Potali Switch
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: VanikTheme.borderGrey)),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      icon: const Icon(Icons.search, color: Colors.black54, size: 20),
                      hintText: _categoryIndex == 0 ? 'Search barcode item' : 'Search loose item',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _categoryIndex = 0),
                child: Container(
                  height: 48, width: 48,
                  decoration: BoxDecoration(color: _categoryIndex == 0 ? VanikTheme.darkMustard : VanikTheme.chipHighlight, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.qr_code_scanner, color: _categoryIndex == 0 ? Colors.white : const Color(0xFF3B5C35), size: 22),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _categoryIndex = 1),
                child: Container(
                  height: 48, width: 48,
                  decoration: BoxDecoration(color: _categoryIndex == 1 ? VanikTheme.darkMustard : VanikTheme.chipHighlight, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.shopping_bag, color: _categoryIndex == 1 ? Colors.white : const Color(0xFF3B5C35), size: 22),
                ),
              ),
            ],
          ),
        ),

        // Action Button: Stock barcode items / Stock loose item
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: GestureDetector(
            onTap: () {
          if (_categoryIndex == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => BarcodeStockScannerScreen(
                  catalog: widget.catalog,
                  onStockAdded: (product, wholeCost, pieces, sellPrice) {
                    setState(() {
                      product.buyPrice = wholeCost > 0 && pieces > 0 ? wholeCost / pieces : product.buyPrice;
                      product.stock += pieces;
                      product.sellPrice = sellPrice;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${product.name} ka stock jud gaya!')),
                    );
                  },
                ),
              ),
            );
          } else {
            _openAddLooseItemDialog();
          }
        },
            child: Container(
              height: 46, width: double.infinity,
              decoration: BoxDecoration(color: VanikTheme.darkMustard, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_categoryIndex == 0 ? Icons.qr_code_2 : Icons.scale, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(_categoryIndex == 0 ? 'Stock barcode items' : 'Stock loose item', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),

        // Items List
        Expanded(
          child: visibleList.isEmpty
              ? Center(child: Text(_statusFilter == 1 ? 'Koi pending item nahi hai!' : 'Dukaan me koi item nahi hai. Stock jodein!', style: const TextStyle(color: Colors.black45, fontSize: 14)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: visibleList.length,
                  itemBuilder: (ctx, i) {
                    final item = visibleList[i];
                    return GestureDetector(
                      onTap: () => _openProductEditDialog(item),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEFEAE1))),
                        child: Row(
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(color: const Color(0xFFF1EBDD), borderRadius: BorderRadius.circular(10)),
                              child: Icon(item.isLoose ? Icons.shopping_bag : Icons.inventory_2_outlined, color: VanikTheme.darkMustard, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: VanikTheme.textBlack)),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item.stock.toInt()} ${item.unit}',
                                    style: TextStyle(
                                      color: item.stock <= 5 ? VanikTheme.alertRed : VanikTheme.darkMustard,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text('₹${item.sellPrice.toInt()}${item.isLoose ? '/${item.unit}' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: VanikTheme.textBlack)),
                          ],
                        ),
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
// 7. SCREEN 2: MAKE BILL (LIVE CAMERA, PENCIL EDIT, LOOSE, PAYMENTS)
// ============================================================================
class MakeBillScreenEngine extends StatefulWidget {
  final List<ProductEntity> catalog;
  final List<BillCartEntry> cartItems;
  final Function(ProductEntity, double, [double]) onCartAdd;
  final Function(int) onCartRemove;
  final VoidCallback onClearCart;
  final Function(String, [String?, String?]) onCheckoutFinalized;
  final Function(String, double) onUnknownBarcodeFound;

  const MakeBillScreenEngine({
    super.key,
    required this.catalog,
    required this.cartItems,
    required this.onCartAdd,
    required this.onCartRemove,
    required this.onClearCart,
    required this.onCheckoutFinalized,
    required this.onUnknownBarcodeFound,
  });

  @override
  State<MakeBillScreenEngine> createState() => _MakeBillScreenEngineState();
}

class _MakeBillScreenEngineState extends State<MakeBillScreenEngine> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _torchActive = false;
  bool _detectorLocked = false;

  double get _currentBillSum =>
      widget.cartItems.fold(0.0, (acc, item) => acc + item.calculatedLineTotal);

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onLiveCaptureDetected(BarcodeCapture capture) {
    if (_detectorLocked) return;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        _detectorLocked = true;
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);

        final rawCode = barcode.rawValue!;
        final matchedProducts = widget.catalog.where((p) => p.barcode == rawCode).toList();

        if (matchedProducts.isNotEmpty) {
          widget.onCartAdd(matchedProducts.first, 1.0);
        } else {
          _promptSellingRateUnknownBarcode(rawCode);
        }

        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _detectorLocked = false);
        });
        break;
      }
    }
  }

  // Unknown Barcode Modal: Selling Price Only
  void _promptSellingRateUnknownBarcode(String barcode) {
    final rateCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(barcode, style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFF1EBDD), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.qr_code_2, color: VanikTheme.darkMustard, size: 40)),
            const SizedBox(height: 12),
            const Text('Naya Product Scan Hua', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: VanikTheme.borderGrey)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selling Price (₹)', style: TextStyle(color: VanikTheme.textGrey, fontSize: 11)),
                  TextField(controller: rateCtrl, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '00')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: VanikTheme.darkMustard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  if (rateCtrl.text.isNotEmpty) {
                    widget.onUnknownBarcodeFound(barcode, double.tryParse(rateCtrl.text) ?? 10.0);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Loose Item Picker BottomSheet in Bill
  void _openLooseItemSelectionSheet() {
    final looseItems = widget.catalog.where((i) => i.isLoose).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Khula Saman Chunein', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: VanikTheme.darkGreen)),
            const SizedBox(height: 14),
            Expanded(
              child: looseItems.isEmpty
                  ? const Center(child: Text('My Shop me pehle loose item stock jodein!'))
                  : ListView.builder(
                      itemCount: looseItems.length,
                      itemBuilder: (ctx, i) {
                        final p = looseItems[i];
                        return ListTile(
                          leading: const CircleAvatar(backgroundColor: VanikTheme.chipBackground, child: Icon(Icons.shopping_bag, color: VanikTheme.darkMustard)),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Rate: ₹${p.sellPrice.toInt()} / ${p.unit}'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _openRupeeWeightSaleModal(p);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 2-Way Quick Rupee / Grams / Pieces Calculation Modal
  void _openRupeeWeightSaleModal(ProductEntity product) {
    final rupeeInput = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${product.name} (₹${product.sellPrice.toInt()} / ${product.unit})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: VanikTheme.darkGreen)),
            const SizedBox(height: 14),
            Row(
              children: [5, 10, 20, 50].map((val) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  backgroundColor: VanikTheme.chipHighlight,
                  label: Text('₹$val', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => rupeeInput.text = val.toString(),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rupeeInput,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Seedha Rupaye Dalein (₹)', border: OutlineInputBorder(), prefixText: '₹ '),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: VanikTheme.darkMustard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  final amt = double.tryParse(rupeeInput.text) ?? 10.0;
                  final qty = amt / product.sellPrice;
                  widget.onCartAdd(product, qty, amt);
                  Navigator.pop(ctx);
                },
                child: const Text('Bill Me Add Karein', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pencil Item Quantity / Discount Modal
  void _openPencilEditCartModal(BillCartEntry cartEntry) {
    final qtyInput = TextEditingController(text: cartEntry.quantity.toStringAsFixed(0));
    final priceInput = TextEditingController(text: cartEntry.product.sellPrice.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(cartEntry.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qtyInput, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'How many pieces / units?')),
            const SizedBox(height: 8),
            TextField(controller: priceInput, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VanikTheme.darkGreen),
            onPressed: () {
              setState(() {
                cartEntry.quantity = double.tryParse(qtyInput.text) ?? cartEntry.quantity;
                cartEntry.product.sellPrice = double.tryParse(priceInput.text) ?? cartEntry.product.sellPrice;
                cartEntry.customRupeeOverride = 0.0;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Udhaar Checkout Modal (Select Person vs New Person)
  void _openUdhaarPersonModal() {
    int subTab = 0;
    final phoneInput = TextEditingController();
    final nameInput = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setUdharState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          contentPadding: const EdgeInsets.all(16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 42,
                decoration: BoxDecoration(color: VanikTheme.chipHighlight, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setUdharState(() => subTab = 0),
                        child: Container(
                          decoration: BoxDecoration(color: subTab == 0 ? VanikTheme.darkMustard : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text('Select person', style: TextStyle(color: subTab == 0 ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setUdharState(() => subTab = 1),
                        child: Container(
                          decoration: BoxDecoration(color: subTab == 1 ? VanikTheme.darkMustard : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text('New person', style: TextStyle(color: subTab == 1 ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (subTab == 0) ...[
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: VanikTheme.borderGrey)),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey, size: 20),
                      SizedBox(width: 8),
                      Text('Search name or phone number', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Pehle se koi udhar grahak nahi hai', style: TextStyle(color: Colors.black45, fontSize: 12)),
              ] else ...[
                _buildModalInputBox(controller: phoneInput, label: 'Phone number (Enter here)'),
                const SizedBox(height: 10),
                _buildModalInputBox(controller: nameInput, label: 'Person name (Write here)'),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8BB585), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    widget.onCheckoutFinalized('Udhaar', nameInput.text.trim(), phoneInput.text.trim());
                    Navigator.pop(ctx);
                    _showSeeBillPOSSlip('Udhaar');
                  },
                  child: const Text('Add Udhaar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalInputBox({required TextEditingController controller, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: VanikTheme.borderGrey)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: VanikTheme.textGrey, fontSize: 11)),
          TextField(controller: controller, keyboardType: TextInputType.phone, decoration: const InputDecoration(border: InputBorder.none, isDense: true)),
        ],
      ),
    );
  }

  // See Bill Black POS Machine Receipt Slip
  void _showSeeBillPOSSlip(String paymentType) {
    final billSnapshot = List<BillCartEntry>.from(widget.cartItems);
    final totalSnapshot = _currentBillSum;
    widget.onClearCart();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: VanikTheme.scaffoldBg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Vanik', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        ...billSnapshot.map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(c.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('${c.quantity.toStringAsFixed(0)} ${c.product.unit}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                              Text('₹${c.calculatedLineTotal.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        )),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${billSnapshot.length} items', style: const TextStyle(color: Colors.black54)),
                            Text('₹${totalSnapshot.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8DECB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.share, color: Color(0xFF25D366)),
                label: const Text('Share on whatsapp', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8BB585), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('New bill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Live Camera Scanning Frame with Torch
        Container(
          margin: const EdgeInsets.all(16),
          height: 180, width: double.infinity,
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onLiveCaptureDetected,
              ),
              Center(
                child: Container(
                  width: 240, height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: VanikTheme.scannerYellow, width: 2.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: const Text('Scan Barcode', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: () {
                    _scannerController.toggleTorch();
                    setState(() => _torchActive = !_torchActive);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: Icon(_torchActive ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bill Header & Loose Item Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: VanikTheme.darkGreen)),
              GestureDetector(
                onTap: _openLooseItemSelectionSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: VanikTheme.chipHighlight, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    children: [
                      Icon(Icons.scale, color: Color(0xFF3B5C35), size: 16),
                      SizedBox(width: 6),
                      Text('Loose Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scanned Bill Items List
        Expanded(
          child: widget.cartItems.isEmpty
              ? Center(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: VanikTheme.darkMustard)),
                    onPressed: () => _promptSellingRateUnknownBarcode('8904063254450'),
                    child: const Text('+ Test Scan Barcode', style: TextStyle(color: VanikTheme.darkMustard, fontWeight: FontWeight.bold)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: widget.cartItems.length,
                  itemBuilder: (ctx, i) {
                    final item = widget.cartItems[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEFEAE1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: VanikTheme.chipBackground, borderRadius: BorderRadius.circular(8)),
                            child: Icon(item.product.isLoose ? Icons.shopping_bag : Icons.inventory_2_outlined, color: VanikTheme.darkMustard, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  item.customRupeeOverride > 0 ? 'Seedha ₹${item.customRupeeOverride.toInt()} ka sauda' : '${item.quantity.toInt()} ${item.product.unit}',
                                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text('₹${item.calculatedLineTotal.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 6),
                          IconButton(icon: const Icon(Icons.edit, color: VanikTheme.darkGreen, size: 20), onPressed: () => _openPencilEditCartModal(item)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: VanikTheme.darkMustard, size: 20), onPressed: () => widget.onCartRemove(i)),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Bottom Total & Payment Buttons (Online, Cash, Udhaar)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('₹${_currentBillSum.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_currentBillSum > 0) {
                          widget.onCheckoutFinalized('Online');
                          _showSeeBillPOSSlip('Online');
                        }
                      },
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(color: const Color(0xFF8BB585), borderRadius: BorderRadius.circular(14)),
                        child: const Center(child: Text('Online', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_currentBillSum > 0) {
                          widget.onCheckoutFinalized('Cash');
                          _showSeeBillPOSSlip('Cash');
                        }
                      },
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(color: VanikTheme.darkMustard, borderRadius: BorderRadius.circular(14)),
                        child: const Center(child: Text('Cash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_currentBillSum > 0) _openUdhaarPersonModal();
                      },
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(color: VanikTheme.chipHighlight, borderRadius: BorderRadius.circular(14)),
                        child: const Center(child: Text('Udhaar', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15))),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 8. SCREEN 3: MY SALES & CUSTOMER UDHAAR KHATA
// ============================================================================
class MySalesScreenEngine extends StatefulWidget {
  final List<OrderTransaction> orders;
  final List<UdharCustomerEntity> udharLedger;
  final Function(String) onPayMarked;

  const MySalesScreenEngine({
    super.key,
    required this.orders,
    required this.udharLedger,
    required this.onPayMarked,
  });

  @override
  State<MySalesScreenEngine> createState() => _MySalesScreenEngineState();
}

class _MySalesScreenEngineState extends State<MySalesScreenEngine> {
  int _salesModeTab = 0; // 0: Sales, 1: Udhaar

  double get _grossDailySales =>
      widget.orders.fold(0.0, (acc, ord) => acc + ord.billedAmount);

  double get _grossPendingCredit =>
      widget.udharLedger.where((u) => !u.isPaid).fold(0.0, (acc, u) => acc + u.pendingAmount);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sales vs Udhaar Switch
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 46,
            decoration: BoxDecoration(color: VanikTheme.chipHighlight, borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _salesModeTab = 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _salesModeTab == 0 ? VanikTheme.darkMustard : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          'Sales',
                          style: TextStyle(color: _salesModeTab == 0 ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _salesModeTab = 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _salesModeTab == 1 ? VanikTheme.darkMustard : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          'Udhaar',
                          style: TextStyle(color: _salesModeTab == 1 ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: _salesModeTab == 0
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sales Card & Bar Chart
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEFEAE1)),
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
                                    const Text('Sales of day', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                    Text('₹${_grossDailySales.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: VanikTheme.chipBackground, borderRadius: BorderRadius.circular(8)),
                                  child: const Text('November 26', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildBarWidget('1 Nov', '₹0', 10, false),
                                _buildBarWidget('2 Nov', '₹0', 10, false),
                                _buildBarWidget('Today', '₹${_grossDailySales.toInt()}', _grossDailySales > 0 ? 80 : 10, true),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Bills of the day ^', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 10),
                      widget.orders.isEmpty
                          ? const Text('Aaj koi bill nahi kata hai.', style: TextStyle(color: Colors.black45, fontSize: 13))
                          : Column(
                              children: widget.orders.map((s) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${s.timestamp.hour}:${s.timestamp.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('${s.soldItems.length} items (${s.paymentMode})', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                      ],
                                    ),
                                    Text('₹${s.billedAmount.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              )).toList(),
                            ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Kul Baaki Udhar:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('₹${_grossPendingCredit.toInt()}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: widget.udharLedger.isEmpty
                          ? const Center(child: Text('Koi udhar record nahi hai', style: TextStyle(color: Colors.black45)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: widget.udharLedger.length,
                              itemBuilder: (ctx, i) {
                                final u = widget.udharLedger[i];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(u.personName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(u.phoneNumber, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text('₹${u.pendingAmount.toInt()}', style: TextStyle(fontWeight: FontWeight.bold, color: u.isPaid ? Colors.green : Colors.red, fontSize: 16)),
                                          const SizedBox(width: 8),
                                          if (!u.isPaid)
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8BB585)),
                                              onPressed: () => widget.onPayMarked(u.id),
                                              child: const Text('Paid', style: TextStyle(color: Colors.white, fontSize: 11)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildBarWidget(String dayLabel, String totalStr, double barHeight, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(totalStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          width: 22, height: barHeight,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8BB585) : const Color(0xFFE2DAC8),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 6),
        Text(dayLabel, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }
}
// ============================================================================
// SCAN BARCODE FOR STOCKING (LIVE CAMERA + ADD STOCK MODAL)
// ============================================================================
class BarcodeStockScannerScreen extends StatefulWidget {
  final List<ProductEntity> catalog;
  final Function(ProductEntity, double, int, double) onStockAdded;

  const BarcodeStockScannerScreen({
    super.key,
    required this.catalog,
    required this.onStockAdded,
  });

  @override
  State<BarcodeStockScannerScreen> createState() => _BarcodeStockScannerScreenState();
}

class _BarcodeStockScannerScreenState extends State<BarcodeStockScannerScreen> {
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _torch = false;
  String _searchFilter = '';

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  void _showAddStockSheet(ProductEntity item) {
    File? itemPhotoFile;
    final moneyCtrl = TextEditingController();
    final piecesCtrl = TextEditingController();
    final sellRateCtrl = TextEditingController(text: item.sellPrice.toInt().toString());
    final currentPiecesCtrl = TextEditingController(text: item.stock.toInt().toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 18,
          right: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barcode Item Photo Box (Click karne par camera khulega)
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 60,
                    );
                    if (picked != null) {
                      setSheetState(() {
                        itemPhotoFile = File(picked.path);
                      });
                    }
                  },
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1EBDD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: itemPhotoFile != null ? Colors.green : const Color(0xFFD48B38).withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: itemPhotoFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(itemPhotoFile!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, color: Color(0xFFD48B38), size: 28),
                              SizedBox(height: 4),
                              Text('Add Photo', style: TextStyle(fontSize: 10, color: Color(0xFFD48B38), fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.barcode ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF6EE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInputField('Money you paid for whole stock (₹)', moneyCtrl),
              _buildInputField('No. of pieces bought in that money', piecesCtrl),
              _buildInputField('Selling price of single unit (₹)', sellRateCtrl),
              _buildInputField('Current pieces in shop', currentPiecesCtrl),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD48B38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final money = double.tryParse(moneyCtrl.text) ?? 0.0;
                    final pieces = int.tryParse(piecesCtrl.text) ?? 0;
                    final sellPrice = double.tryParse(sellRateCtrl.text) ?? item.sellPrice;
                    widget.onStockAdded(item, money, pieces, sellPrice);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
             ),
           ),
         ],
       ),
     ),
           );
          },
        );
      },
    );
    }
 
  Widget _buildInputField(String label, TextEditingController ctrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2DAC8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.black87, fontSize: 13))),
          SizedBox(
            width: 70,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(border: InputBorder.none, hintText: '00'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.catalog
        .where((p) => !p.isLoose && p.name.toLowerCase().contains(_searchFilter.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F2),
      appBar: AppBar(
        backgroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Scan Barcode', style: TextStyle(color: Colors.white, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_torch ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: () {
              _scannerCtrl.toggleTorch();
              setState(() => _torch = !_torch);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerCtrl,
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      if (b.rawValue != null && b.rawValue!.isNotEmpty) {
                        HapticFeedback.mediumImpact();
                        final code = b.rawValue!;
                        final matched = widget.catalog.where((p) => p.barcode == code).toList();
                        if (matched.isNotEmpty) {
                          _showAddStockSheet(matched.first);
                        } else {
                          final newItem = ProductEntity(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: 'Item $code',
                            barcode: code,
                            buyPrice: 0.0,
                            sellPrice: 10.0,
                            stock: 0,
                            unit: 'piece',
                          );
                          widget.catalog.add(newItem);
                          _showAddStockSheet(newItem);
                        }
                        break;
                      }
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2DAC8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _searchFilter = v),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search barcode item',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final p = filtered[i];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEFEAE1)),
                  ),
                  child: ListTile(
                    leading: (p.imagePath != null && p.imagePath!.isNotEmpty && File(p.imagePath!).existsSync())
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(p.imagePath!),
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2E7D32)),
                ),
