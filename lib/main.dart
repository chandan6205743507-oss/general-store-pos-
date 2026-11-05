import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VanikApp());
}

class VanikApp extends StatelessWidget {
  const VanikApp({Key? key}) : super(key: key);

      @override
    Widget build(BuildContext context) {
      return MaterialApp(
        title: 'General Store POS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFBF8F2),
          primaryColor: const Color(0xFF2D5A27),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2D5A27),
            primary: const Color(0xFF2D5A27),
            secondary: const Color(0xFFD9822B),
            surface: Colors.white,
          ),
          cardTheme: CardTheme(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFEBE5D8), width: 1.2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        home: const MainNavigationScreen(),
      );
    }
  
// ----------------- DATA MODELS -----------------

class ProductItem {
  String barcode;
  String name;
  double sellingPrice;
  double purchasePrice;
  double stock;
  String? imagePath;
  bool isLoose;
  bool isPending;

  ProductItem({
    required this.barcode,
    required this.name,
    required this.sellingPrice,
    this.purchasePrice = 0.0,
    required this.stock,
    this.imagePath,
    this.isLoose = false,
    this.isPending = false,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'name': name,
        'sellingPrice': sellingPrice,
        'purchasePrice': purchasePrice,
        'stock': stock,
        'imagePath': imagePath,
        'isLoose': isLoose,
        'isPending': isPending,
      };

  factory ProductItem.fromJson(Map<String, dynamic> json) => ProductItem(
        barcode: json['barcode'] ?? '',
        name: json['name'] ?? '',
        sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
        purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? 0.0,
        stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
        imagePath: json['imagePath'],
        isLoose: json['isLoose'] ?? false,
        isPending: json['isPending'] ?? false,
      );
}

class CartItem {
  ProductItem product;
  double quantity;
  double unitPrice;

  CartItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;
}

class SaleRecord {
  String id;
  String date;
  String time;
  double totalAmount;
  String paymentMode;
  String? customerName;
  String? customerPhone;
  bool isPaid;
  List<dynamic> itemsSummary;

  SaleRecord({
    required this.id,
    required this.date,
    required this.time,
    required this.totalAmount,
    required this.paymentMode,
    this.customerName,
    this.customerPhone,
    this.isPaid = true,
    required this.itemsSummary,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'time': time,
        'totalAmount': totalAmount,
        'paymentMode': paymentMode,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'isPaid': isPaid,
        'itemsSummary': itemsSummary,
      };

  factory SaleRecord.fromJson(Map<String, dynamic> json) => SaleRecord(
        id: json['id'] ?? '',
        date: json['date'] ?? '',
        time: json['time'] ?? '',
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        paymentMode: json['paymentMode'] ?? 'Cash',
        customerName: json['customerName'],
        customerPhone: json['customerPhone'],
        isPaid: json['isPaid'] ?? true,
        itemsSummary: json['itemsSummary'] != null
            ? List<dynamic>.from(json['itemsSummary'])
            : <dynamic>[],
      );
}

// ----------------- ROOT NAVIGATION -----------------

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1;
  String _shopName = '';
  String _syncCode = '';
  List<ProductItem> _inventory = [];
  List<SaleRecord> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllAppData();
  }

  Future<void> _loadAllAppData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopName = prefs.getString('vanik_shop_name') ?? '';
      _syncCode = prefs.getString('vanik_sync_code') ?? '';
      if (_syncCode.isEmpty) {
        _syncCode = (100000 + Random().nextInt(900000)).toString();
        prefs.setString('vanik_sync_code', _syncCode);
      }

      final invStr = prefs.getString('vanik_inventory');
      if (invStr != null && invStr.isNotEmpty) {
        final List decoded = jsonDecode(invStr);
        _inventory = decoded.map((e) => ProductItem.fromJson(e)).toList();
      } else {
        _inventory = [];
      }

      final salesStr = prefs.getString('vanik_sales');
      if (salesStr != null && salesStr.isNotEmpty) {
        final List decoded = jsonDecode(salesStr);
        _sales = decoded.map((e) => SaleRecord.fromJson(e)).toList();
      } else {
        _sales = [];
      }
      _isLoading = false;
    });

    if (_shopName.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOnboardingModal());
    }
  }

  Future<void> _saveInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final str = jsonEncode(_inventory.map((e) => e.toJson()).toList());
    await prefs.setString('vanik_inventory', str);
  }

  Future<void> _saveSales() async {
    final prefs = await SharedPreferences.getInstance();
    final str = jsonEncode(_sales.map((e) => e.toJson()).toList());
    await prefs.setString('vanik_sales', str);
  }

  void _showOnboardingModal() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFBF8F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Dukaan Ka Naam', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D5A27))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Apni General Store dukaan ka naam daaliye:', style: TextStyle(fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'e.g. Apna General Store',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9822B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final name = controller.text.trim();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('vanik_shop_name', name);
                setState(() => _shopName = name);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Shuru Karein', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showShopCodeModal() {
    final joinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFBF8F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.sync, color: Color(0xFF2D5A27)),
            const SizedBox(width: 8),
            Text(_shopName.isEmpty ? 'Multi-Staff Sync' : _shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aapki dukaan ka Unique Sync Code hai:', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2D5A27), width: 1.5),
              ),
              child: Center(
                child: Text(
                  _syncCode,
                  style: const TextStyle(fontSize: 26, letterSpacing: 6, fontWeight: FontWeight.bold, color: Color(0xFF2D5A27)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Doosre phone se judne ke liye code daalein:', style: TextStyle(fontSize: 12, color: Colors.black87)),
            const SizedBox(height: 8),
            TextField(
              controller: joinController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '6-digit shop code',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D5A27)),
            onPressed: () async {
              if (joinController.text.trim().length == 6) {
                final newCode = joinController.text.trim();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('vanik_sync_code', newCode);
                setState(() => _syncCode = newCode);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Shop sync code updated to $newCode!')),
                  );
                }
              }
            },
            child: const Text('Join Shop', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF2D5A27))));
    }

    final pages = [
      MyShopScreen(
        shopName: _shopName,
        inventory: _inventory,
        onInventoryUpdated: _saveInventory,
      ),
      MakeBillScreen(
        shopName: _shopName,
        inventory: _inventory,
        onInventoryUpdated: _saveInventory,
        onBillCompleted: (SaleRecord newSale) async {
          setState(() {
            _sales.insert(0, newSale);
          });
          await _saveSales();
          await _saveInventory();
        },
        onProfileTap: _showShopCodeModal,
      ),
      MySalesScreen(
        shopName: _shopName,
        sales: _sales,
        onSalesUpdated: _saveSales,
      ),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.storefront_outlined, 'My Shop'),
                _buildCenterBillingItem(1, Icons.receipt_long, 'Make Bill'),
                _buildNavItem(2, Icons.account_balance_wallet_outlined, 'My Sales'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: isSelected ? const Color(0xFF2D5A27) : Colors.black54),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF2D5A27) : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterBillingItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF86A873) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: isSelected ? Colors.white : Colors.black54),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- SCREEN 2: MAKE BILL -----------------

class MakeBillScreen extends StatefulWidget {
  final String shopName;
  final List<ProductItem> inventory;
  final VoidCallback onInventoryUpdated;
  final Function(SaleRecord) onBillCompleted;
  final VoidCallback onProfileTap;

  const MakeBillScreen({
    Key? key,
    required this.shopName,
    required this.inventory,
    required this.onInventoryUpdated,
    required this.onBillCompleted,
    required this.onProfileTap,
  }) : super(key: key);

  @override
  State<MakeBillScreen> createState() => _MakeBillScreenState();
}

class _MakeBillScreenState extends State<MakeBillScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _isTorchOn = false;
  final List<CartItem> _cart = [];
  String? _lastScannedCode;
  DateTime _lastScanTime = DateTime.now();

  double get _totalBill => _cart.fold(0.0, (sum, item) => sum + item.total);

  void _handleBarcodeDetected(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    final now = DateTime.now();
    if (_lastScannedCode == code && now.difference(_lastScanTime).inMilliseconds < 1200) {
      return;
    }
    _lastScannedCode = code;
    _lastScanTime = now;

    // Beep + Vibration
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();

    final index = widget.inventory.indexWhere((p) => p.barcode == code);
    if (index != -1) {
      final product = widget.inventory[index];
      _addToCart(product, 1.0, product.sellingPrice);
    } else {
      _showQuickAddPendingModal(code);
    }
  }

  void _addToCart(ProductItem product, double qty, double price) {
    setState(() {
      final existingIndex = _cart.indexWhere((item) => item.product.barcode == product.barcode && !item.product.isLoose);
      if (existingIndex != -1) {
        _cart[existingIndex].quantity += qty;
      } else {
        _cart.add(CartItem(product: product, quantity: qty, unitPrice: price));
      }
    });
  }

  void _showQuickAddPendingModal(String barcode) {
    final nameCtrl = TextEditingController(text: 'Item $barcode');
    final priceCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFBF8F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Naya Item Detect Hua', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D5A27))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name')),
            const SizedBox(height: 8),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D5A27)),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 10.0;
              final newProd = ProductItem(
                barcode: barcode,
                name: name,
                sellingPrice: price,
                purchasePrice: 0.0,
                stock: 0.0,
                isPending: true,
              );
              widget.inventory.add(newProd);
              widget.onInventoryUpdated();
              _addToCart(newProd, 1.0, price);
              Navigator.pop(ctx);
            },
            child: const Text('Add to Bill', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openPencilEditModal(CartItem item) {
    final qtyCtrl = TextEditingController(text: item.quantity.toString().replaceAll(RegExp(r'\.0$'), ''));
    final priceCtrl = TextEditingController(text: item.unitPrice.toString().replaceAll(RegExp(r'\.0$'), ''));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 50,
                    height: 50,
                    color: const Color(0xFFF3ECE1),
                    child: item.product.imagePath != null
                        ? Image.file(File(item.product.imagePath!), fit: BoxFit.cover)
                        : const Icon(Icons.inventory_2, color: Color(0xFF2D5A27)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFFBF8F2), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Product name', style: TextStyle(fontSize: 10, color: Colors.black54)),
                        Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('How many Pieces?', style: TextStyle(fontSize: 13, color: Colors.black87)),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(border: InputBorder.none),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discounted price of 1 Piece\n(₹)', style: TextStyle(fontSize: 12, color: Colors.black87)),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(border: InputBorder.none),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF86A873),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final newQty = double.tryParse(qtyCtrl.text.trim()) ?? item.quantity;
                  final newPrice = double.tryParse(priceCtrl.text.trim()) ?? item.unitPrice;
                  setState(() {
                    item.quantity = newQty;
                    item.unitPrice = newPrice;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('OK', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLooseItemSelectionModal() {
    final looseProducts = widget.inventory.where((p) => p.isLoose).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFBF8F2),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Khula Samaan (Loose Item)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D5A27))),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalCtx)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (looseProducts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('My Shop me jaakar Loose Item add karein.')),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: looseProducts.length,
                        itemBuilder: (c, i) {
                          final item = looseProducts[i];
                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.black12),
                            ),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  color: const Color(0xFFE8DFC8),
                                  child: item.imagePath != null
                                      ? Image.file(File(item.imagePath!), fit: BoxFit.cover)
                                      : const Icon(Icons.scale, color: Color(0xFF2D5A27)),
                                ),
                              ),
                              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Rate: ₹${item.sellingPrice}/kg | Stock: ${item.stock} kg'),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9822B)),
                                onPressed: () {
                                  Navigator.pop(modalCtx);
                                  _showSmartWeightCalculationDialog(item);
                                },
                                child: const Text('Select', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSmartWeightCalculationDialog(ProductItem item) {
    final weightCtrl = TextEditingController(text: '1.0');
    final amountCtrl = TextEditingController(text: item.sellingPrice.toStringAsFixed(0));
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${item.name} (₹${item.sellingPrice}/kg)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Wajan (Kg me, jaise 0.250 for 250g)',
                suffixText: 'kg',
              ),
              onChanged: (val) {
                if (isUpdating) return;
                isUpdating = true;
                final w = double.tryParse(val) ?? 0.0;
                final amt = w * item.sellingPrice;
                amountCtrl.text = amt.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
                isUpdating = false;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Rupaye (₹ se hisab, jaise ₹10)',
                prefixText: '₹ ',
              ),
              onChanged: (val) {
                if (isUpdating) return;
                isUpdating = true;
                final a = double.tryParse(val) ?? 0.0;
                if (item.sellingPrice > 0) {
                  final w = a / item.sellingPrice;
                  weightCtrl.text = w.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
                }
                isUpdating = false;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D5A27)),
            onPressed: () {
              final w = double.tryParse(weightCtrl.text.trim()) ?? 0.0;
              if (w > 0) {
                setState(() {
                  _cart.add(CartItem(product: item, quantity: w, unitPrice: item.sellingPrice));
                  item.stock = max(0.0, item.stock - w);
                });
                widget.onInventoryUpdated();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add to Bill', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openUdhaarModal() {
    if (_cart.isEmpty) return;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFBF8F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Customer Udhaar Khata', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD9822B))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Customer Name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Customer Mobile Number',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9822B)),
            onPressed: () {
              final phone = phoneCtrl.text.trim();
              final name = nameCtrl.text.trim().isEmpty ? 'Grahak' : nameCtrl.text.trim();
              Navigator.pop(ctx);
              _finalizeBilling('Udhaar', custName: name, custPhone: phone, isPaid: false);
            },
            child: const Text('Save Udhaar Record', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _finalizeBilling(String mode, {String? custName, String? custPhone, bool isPaid = true}) {
    if (_cart.isEmpty) return;

    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final summary = _cart
        .map((e) => {
              'name': e.product.name,
              'qty': e.quantity,
              'rate': e.unitPrice,
              'total': e.total,
            })
        .toList();

    for (var c in _cart) {
      if (!c.product.isLoose) {
        c.product.stock = max(0.0, c.product.stock - c.quantity);
      }
    }
    widget.onInventoryUpdated();

    final sale = SaleRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: dateStr,
      time: timeStr,
      totalAmount: _totalBill,
      paymentMode: mode,
      customerName: custName,
      customerPhone: custPhone,
      isPaid: isPaid,
      itemsSummary: summary,
    );

    widget.onBillCompleted(sale);
    _showInvoiceThermalSuccessSheet(sale);

    setState(() {
      _cart.clear();
    });
  }

  void _showInvoiceThermalSuccessSheet(SaleRecord sale) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 50, color: Color(0xFF2D5A27)),
            const SizedBox(height: 8),
            Text('Bill Paid: ₹${sale.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Mode: ${sale.paymentMode}', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text('Share WhatsApp Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _shareWhatsAppBill(sale);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareWhatsAppBill(SaleRecord sale) async {
    final buffer = StringBuffer();
    buffer.writeln("*${widget.shopName}*");
    buffer.writeln("Date: ${sale.date} ${sale.time}");
    buffer.writeln("--------------------------");
    for (var item in sale.itemsSummary) {
      buffer.writeln("${item['name']} x ${item['qty']} = ₹${item['total']}");
    }
    buffer.writeln("--------------------------");
    buffer.writeln("*Total Bill: ₹${sale.totalAmount}*");
    buffer.writeln("Status: ${sale.paymentMode} ${sale.isPaid ? '(Paid)' : '(Udhaar Baaki)'}");
    buffer.writeln("\nDhanyawad! Dobara Padhaarein.");

    final text = Uri.encodeComponent(buffer.toString());
    final phone = sale.customerPhone ?? '';
    final url = phone.isNotEmpty ? "https://wa.me/91$phone?text=$text" : "https://wa.me/?text=$text";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onProfileTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(radius: 10, backgroundColor: Color(0xFFE8DFC8), child: Icon(Icons.person, size: 14, color: Color(0xFF2D5A27))),
                        const SizedBox(width: 6),
                        Text(widget.shopName.isEmpty ? 'My Shop' : widget.shopName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 12, color: Colors.black45),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFFD9822B)),
                      const SizedBox(width: 4),
                      Text('Orders: ${_cart.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const CircleAvatar(radius: 14, backgroundColor: Color(0xFF2D5A27), child: Icon(Icons.check, size: 14, color: Colors.white)),
              ],
            ),
          ),
          Container(
            height: 180,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _handleBarcodeDetected,
                  ),
                  Container(
                    width: 200,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF86A873), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Scan Barcode', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        GestureDetector(
                          onTap: () async {
                            await _scannerController.toggleTorch();
                            setState(() => _isTorchOn = !_isTorchOn);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _isTorchOn ? const Color(0xFFD9822B) : Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isTorchOn ? Icons.flash_on : Icons.flash_off,
                              color: Colors.white,
                              size: 18,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Active Bill', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5A27))),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8DFC8),
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _openLooseItemSelectionModal,
                  icon: const Icon(Icons.scale, size: 16, color: Color(0xFF2D5A27)),
                  label: const Text('Loose Item', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Barcode scan karein ya Loose Item jodein', style: TextStyle(color: Colors.black45)))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (ctx, i) {
                      final item = _cart[i];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 36,
                                height: 36,
                                color: const Color(0xFFF3ECE1),
                                child: item.product.imagePath != null
                                    ? Image.file(File(item.product.imagePath!), fit: BoxFit.cover)
                                    : Icon(item.product.isLoose ? Icons.scale : Icons.fastfood, size: 20, color: const Color(0xFF2D5A27)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(
                                    '₹${item.unitPrice} x ${item.quantity.toStringAsFixed(item.product.isLoose ? 3 : 0)} ${item.product.isLoose ? 'kg' : 'pc'}',
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text('₹${item.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: Color(0xFF86A873)),
                              onPressed: () => _openPencilEditModal(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFD9822B)),
                              onPressed: () {
                                setState(() => _cart.removeAt(i));
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Bill:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text('₹${_totalBill.toStringAsFixed(0)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D5A27),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _finalizeBilling('Online'),
                        child: const Text('Online', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD9822B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _finalizeBilling('Cash'),
                        child: const Text('Cash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8DFC8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _openUdhaarModal,
                        child: const Text('Udhaar', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- SCREEN 3: MY SALES -----------------

class MySalesScreen extends StatefulWidget {
  final String shopName;
  final List<SaleRecord> sales;
  final VoidCallback onSalesUpdated;

  const MySalesScreen({
    Key? key,
    required this.shopName,
    required this.sales,
    required this.onSalesUpdated,
  }) : super(key: key);

  @override
  State<MySalesScreen> createState() => _MySalesScreenState();
}

class _MySalesScreenState extends State<MySalesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _udhaarSearchCtrl = TextEditingController();
  String _udhaarFilterQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  double get _todaySalesTotal {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    return widget.sales
        .where((s) => s.date == todayStr && s.isPaid)
        .fold(0.0, (sum, s) => sum + s.totalAmount);
  }

  void _markUdhaarAsPaid(SaleRecord sale) {
    setState(() {
      sale.isPaid = true;
    });
    widget.onSalesUpdated();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Udhaar of ₹${sale.totalAmount} cleared for ${sale.customerName}!')),
    );
  }

  void _sendWhatsAppReminder(SaleRecord sale) async {
    final phone = sale.customerPhone ?? '';
    final buffer = StringBuffer();
    buffer.writeln("*Namaste ${sale.customerName} Ji!*");
    buffer.writeln("Aapka *${widget.shopName}* me baaki udhaar hai: *₹${sale.totalAmount}*");
    buffer.writeln("Tareekh: ${sale.date}");
    buffer.writeln("Kripya karke dukan aane par bhugtan kar dein.");
    buffer.writeln("Dhanyawad!");

    final text = Uri.encodeComponent(buffer.toString());
    final url = phone.isNotEmpty ? "https://wa.me/91$phone?text=$text" : "https://wa.me/?text=$text";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final udhaarList = widget.sales.where((s) {
      final isPendingDebt = s.paymentMode == 'Udhaar' && !s.isPaid;
      if (!isPendingDebt) return false;
      if (_udhaarFilterQuery.isEmpty) return true;
      final q = _udhaarFilterQuery.toLowerCase();
      final nameMatches = (s.customerName ?? '').toLowerCase().contains(q);
      final phoneMatches = (s.customerPhone ?? '').toLowerCase().contains(q);
      return nameMatches || phoneMatches;
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const Text('Sales & Khata', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D5A27))),
                const Spacer(),
                Text('Today: ₹${_todaySalesTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: const Color(0xFFE8DFC8), borderRadius: BorderRadius.circular(16)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: const Color(0xFF2D5A27), borderRadius: BorderRadius.circular(16)),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black87,
              tabs: const [
                Tab(text: 'My Sales (Graph)'),
                Tab(text: 'Udhaar Khata'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSalesGraphView(),
                _buildUdhaarKhataView(udhaarList),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesGraphView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('5-Day Sales Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (index) {
                    final dayDate = DateTime.now().subtract(Duration(days: 4 - index));
                    final dStr = "${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}";
                    final dayTotal = widget.sales.where((s) => s.date == dStr && s.isPaid).fold(0.0, (sum, s) => sum + s.totalAmount);

                    final barHeight = min(120.0, max(12.0, (dayTotal / 500) * 20));
                    return Column(
                      children: [
                        Text('₹${dayTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          width: 24,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: index == 4 ? const Color(0xFFD9822B) : const Color(0xFF2D5A27),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text("${dayDate.day}/${dayDate.month}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Completed Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D5A27))),
          const SizedBox(height: 8),
          ...widget.sales.where((s) => s.isPaid).map((sale) => Card(
                color: Colors.white,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
                child: ListTile(
                  title: Text('₹${sale.totalAmount.toStringAsFixed(0)} - ${sale.paymentMode}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${sale.date} at ${sale.time} (${sale.itemsSummary.length} items)'),
                  trailing: const Icon(Icons.check_circle, color: Color(0xFF2D5A27), size: 20),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildUdhaarKhataView(List<SaleRecord> udhaarList) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _udhaarSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search name or phone number...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2D5A27)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black12)),
            ),
            onChanged: (val) {
              setState(() => _udhaarFilterQuery = val.trim());
            },
          ),
        ),
        Expanded(
          child: udhaarList.isEmpty
              ? const Center(child: Text('Koi Udhaar pending nahi hai! Sab hisab barabar.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: udhaarList.length,
                  itemBuilder: (ctx, i) {
                    final sale = udhaarList[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                sale.customerName ?? 'Grahak',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              Text(
                                '₹${sale.totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mobile: ${sale.customerPhone ?? 'N/A'} | Date: ${sale.date} (${sale.time})',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                icon: const Icon(Icons.send, size: 14, color: Colors.white),
                                label: const Text('Reminder', style: TextStyle(color: Colors.white, fontSize: 12)),
                                onPressed: () => _sendWhatsAppReminder(sale),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D5A27),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                ),
                                onPressed: () => _markUdhaarAsPaid(sale),
                                child: const Text('Mark Paid', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
    );
  }
}
// ----------------- SCREEN 1: MY SHOP -----------------

class MyShopScreen extends StatefulWidget {
  final String shopName;
  final List<ProductItem> inventory;
  final VoidCallback onInventoryUpdated;

  const MyShopScreen({
    Key? key,
    required this.shopName,
    required this.inventory,
    required this.onInventoryUpdated,
  }) : super(key: key);

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen> {
  int _selectedTab = 0; // 0: Shop items, 1: Pending
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final ImagePicker _picker = ImagePicker();

  void _openAddLooseItemModal() {
    final nameCtrl = TextEditingController();
    final purchaseCtrl = TextEditingController();
    final sellingCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    String? pickedImagePath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFBF8F2),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Khula Samaan Jodein (Loose Item)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D5A27))),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final XFile? img = await _picker.pickImage(source: ImageSource.camera);
                          if (img != null) {
                            setModalState(() => pickedImagePath = img.path);
                          }
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF2D5A27)),
                          ),
                          child: pickedImagePath != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(pickedImagePath!), fit: BoxFit.cover))
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt, color: Color(0xFF2D5A27)),
                                    Text('Photo lein', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name (e.g. Desi Chana, Loose Biscuit)')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: purchaseCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Khareed Rate /kg'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: sellingCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bikri Rate /kg'))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kul Wajan (Stock in Kg)')),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D5A27)),
                        onPressed: () {
                          if (nameCtrl.text.trim().isNotEmpty) {
                            final newItem = ProductItem(
                              barcode: 'LOOSE_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameCtrl.text.trim(),
                              purchasePrice: double.tryParse(purchaseCtrl.text.trim()) ?? 0.0,
                              sellingPrice: double.tryParse(sellingCtrl.text.trim()) ?? 0.0,
                              stock: double.tryParse(stockCtrl.text.trim()) ?? 0.0,
                              imagePath: pickedImagePath,
                              isLoose: true,
                            );
                            widget.inventory.add(newItem);
                            widget.onInventoryUpdated();
                            Navigator.pop(modalCtx);
                            setState(() {});
                          }
                        },
                        child: const Text('Save Loose Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _openStockBarcodeScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: 380,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF2D5A27),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Maal Barcode Scan Karein (Stock Update)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final code = barcodes.first.rawValue;
                    if (code != null && code.trim().isNotEmpty) {
                      Navigator.pop(ctx);
                      _openStockUpdateDetailModal(code);
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openStockUpdateDetailModal(String barcode) {
    final existingIndex = widget.inventory.indexWhere((p) => p.barcode == barcode);
    final nameCtrl = TextEditingController(text: existingIndex != -1 ? widget.inventory[existingIndex].name : '');
    final sellCtrl = TextEditingController(text: existingIndex != -1 ? widget.inventory[existingIndex].sellingPrice.toString() : '');
    final buyCtrl = TextEditingController(text: existingIndex != -1 ? widget.inventory[existingIndex].purchasePrice.toString() : '');
    final addStockCtrl = TextEditingController(text: '10');
    String? currentImagePath = existingIndex != -1 ? widget.inventory[existingIndex].imagePath : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFBF8F2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(existingIndex != -1 ? 'Stock Badhayein' : 'Naya Packet Item', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D5A27))),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final XFile? img = await _picker.pickImage(source: ImageSource.camera);
                        if (img != null) {
                          setDialogState(() => currentImagePath = img.path);
                        }
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2D5A27)),
                        ),
                        child: currentImagePath != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(currentImagePath!), fit: BoxFit.cover))
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, color: Color(0xFF2D5A27), size: 22),
                                  Text('Packet Photo', style: TextStyle(fontSize: 9, color: Colors.black54)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name')),
                  TextField(controller: buyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Khareed Rate (₹)')),
                  TextField(controller: sellCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bikri Rate (₹)')),
                  TextField(controller: addStockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kitna Piece Add Karna Hai?')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9822B)),
                onPressed: () {
                  final added = double.tryParse(addStockCtrl.text.trim()) ?? 0.0;
                  final sell = double.tryParse(sellCtrl.text.trim()) ?? 0.0;
                  final buy = double.tryParse(buyCtrl.text.trim()) ?? 0.0;

                  if (existingIndex != -1) {
                    widget.inventory[existingIndex].stock += added;
                    widget.inventory[existingIndex].sellingPrice = sell;
                    widget.inventory[existingIndex].purchasePrice = buy;
                    widget.inventory[existingIndex].imagePath = currentImagePath;
                    widget.inventory[existingIndex].isPending = false;
                  } else {
                    widget.inventory.add(ProductItem(
                      barcode: barcode,
                      name: nameCtrl.text.trim().isEmpty ? 'Item $barcode' : nameCtrl.text.trim(),
                      sellingPrice: sell,
                      purchasePrice: buy,
                      stock: added,
                      imagePath: currentImagePath,
                      isLoose: false,
                      isPending: false,
                    ));
                  }
                  widget.onInventoryUpdated();
                  setState(() {});
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Save Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confirmedInventory = widget.inventory.where((p) => !p.isPending).toList();
    final pendingCatalog = widget.inventory.where((p) => p.isPending).toList();

    final currentList = (_selectedTab == 0 ? confirmedInventory : pendingCatalog).where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.barcode.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          // 1. Top Header Row (Damodar Mahto General Store | Orders | Check)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 10, backgroundColor: Color(0xFFE8DFC8), child: Icon(Icons.person, size: 14, color: Color(0xFF2D5A27))),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.shopName.isEmpty ? 'My Shop' : widget.shopName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.edit, size: 12, color: Colors.black45),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFFD9822B)),
                      SizedBox(width: 4),
                      Text('Orders: 0', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const CircleAvatar(radius: 14, backgroundColor: Color(0xFF2D5A27), child: Icon(Icons.check, size: 14, color: Colors.white)),
              ],
            ),
          ),

          // 2. Tabs Row: Shop items vs Pending
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? const Color(0xFFE8DFC8) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Shop items: ${confirmedInventory.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 0 ? Colors.black87 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? const Color(0xFFE8DFC8) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Pending: ${pendingCatalog.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 1 ? Colors.black87 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Search Bar + QR Scan + Loose Item Button (Tarazu)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Search barcode item',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.black38),
                        prefixIcon: Icon(Icons.search, size: 20, color: Colors.black45),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openStockBarcodeScanner,
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8DFC8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_scanner, color: Color(0xFF2D5A27), size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openAddLooseItemModal,
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8DFC8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.scale, color: Color(0xFF2D5A27), size: 22),
                  ),
                ),
              ],
            ),
          ),

          // 4. Big Orange Button (Stock barcode items)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD9822B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _openStockBarcodeScanner,
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                label: const Text('Stock barcode items', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ),

          // 5. Product List
          Expanded(
            child: currentList.isEmpty
                ? Center(
                    child: Text(
                      _selectedTab == 0 ? 'Dukaan me koi item nahi hai. Stock jodein!' : 'Koi pending item nahi hai.',
                      style: const TextStyle(color: Colors.black45),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: currentList.length,
                    itemBuilder: (ctx, i) {
                      final item = currentList[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 44,
                                height: 44,
                                color: const Color(0xFFF3ECE1),
                                child: item.imagePath != null
                                    ? Image.file(File(item.imagePath!), fit: BoxFit.cover)
                                    : Icon(item.isLoose ? Icons.scale : Icons.inventory_2, color: const Color(0xFF2D5A27)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.stock.toStringAsFixed(item.isLoose ? 2 : 0)} ${item.isLoose ? 'kg' : 'piece'}',
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text('₹${item.sellingPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Color(0xFF2D5A27), size: 18),
                              onPressed: () => _openStockUpdateDetailModal(item.barcode),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
