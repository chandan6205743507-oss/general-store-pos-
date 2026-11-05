import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

// ==========================================
// 1. DATA MODELS & ENUMS
// ==========================================
enum ItemType { piece, loose }
enum PaymentMethod { cash, online, udhaar }

class ProductItem {
  String id;
  String name;
  String barcode;
  double sellingPrice;
  double buyingPrice;
  double stock;
  ItemType type;
  String imagePath;
  bool isPending;

  ProductItem({
    required this.id,
    required this.name,
    required this.barcode,
    required this.sellingPrice,
    this.buyingPrice = 0.0,
    required this.stock,
    required this.type,
    this.imagePath = '',
    this.isPending = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'barcode': barcode,
    'sellingPrice': sellingPrice,
    'buyingPrice': buyingPrice,
    'stock': stock,
    'type': type.index,
    'imagePath': imagePath,
    'isPending': isPending,
  };

  factory ProductItem.fromMap(Map<String, dynamic> map) => ProductItem(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    barcode: map['barcode'] ?? '',
    sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0.0,
    buyingPrice: (map['buyingPrice'] as num?)?.toDouble() ?? 0.0,
    stock: (map['stock'] as num?)?.toDouble() ?? 0.0,
    type: ItemType.values[map['type'] ?? 0],
    imagePath: map['imagePath'] ?? '',
    isPending: map['isPending'] ?? false,
  );
}

class CartItem {
  final ProductItem product;
  double quantity;
  double customPrice;

  CartItem({
    required this.product,
    required this.quantity,
    required this.customPrice,
  });

  double get total => quantity * customPrice;
  double get profit => (customPrice - product.buyingPrice) * quantity;

  Map<String, dynamic> toMap() => {
    'product': product.toMap(),
    'quantity': quantity,
    'customPrice': customPrice,
  };

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
    product: ProductItem.fromMap(map['product']),
    quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
    customPrice: (map['customPrice'] as num?)?.toDouble() ?? 0.0,
  );
}

class SaleRecord {
  final String id;
  final DateTime date;
  final List<CartItem> items;
  final double total;
  final double profit;
  final PaymentMethod method;
  final String customerPhone;
  bool isPaid;

  SaleRecord({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
    required this.profit,
    required this.method,
    this.customerPhone = '',
    this.isPaid = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'items': items.map((i) => i.toMap()).toList(),
    'total': total,
    'profit': profit,
    'method': method.index,
    'customerPhone': customerPhone,
    'isPaid': isPaid,
  };

  factory SaleRecord.fromMap(Map<String, dynamic> map) => SaleRecord(
    id: map['id'] ?? '',
    date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
    items: (map['items'] as List<dynamic>?)?.map((i) => CartItem.fromMap(i)).toList() ?? [],
    total: (map['total'] as num?)?.toDouble() ?? 0.0,
    profit: (map['profit'] as num?)?.toDouble() ?? 0.0,
    method: PaymentMethod.values[map['method'] ?? 0],
    customerPhone: map['customerPhone'] ?? '',
    isPaid: map['isPaid'] ?? true,
  );
}

// ==========================================
// 2. MAIN APP ENTRY POINT
// ==========================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VanikApp());
}

class VanikApp extends StatelessWidget {
  const VanikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vanik Kirana Store',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFBF8F2),
        primaryColor: const Color(0xFF2D5A27),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D5A27),
          primary: const Color(0xFF2D5A27),
          secondary: const Color(0xFFD9822B),
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}
// ==========================================
// 3. PERSISTENT NAVIGATION & TOP PROFILE
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String _shopName = '';
  String _shopSyncCode = '';
  List<ProductItem> _inventory = [];
  List<SaleRecord> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStateFromDisk();
  }

  Future<void> _loadStateFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final invString = prefs.getString('vanik_kirana_inventory_db_v4');
    final salesString = prefs.getString('vanik_kirana_sales_db_v4');
    final savedShop = prefs.getString('vanik_kirana_shop_name');
    final savedCode = prefs.getString('vanik_kirana_shop_code');

    if (savedShop != null && savedShop.trim().isNotEmpty) {
      _shopName = savedShop;
    }

    if (savedCode != null && savedCode.trim().isNotEmpty) {
      _shopSyncCode = savedCode;
    } else {
      _shopSyncCode = (100000 + Random().nextInt(900000)).toString();
      await prefs.setString('vanik_kirana_shop_code', _shopSyncCode);
    }

    if (invString != null) {
      final List dec = jsonDecode(invString);
      _inventory = dec.map((e) => ProductItem.fromMap(e)).toList();
    } else {
      _inventory = []; // Clean start for any shop owner
    }

    if (salesString != null) {
      final List dec = jsonDecode(salesString);
      _sales = dec.map((e) => SaleRecord.fromMap(e)).toList();
    }

    setState(() => _isLoading = false);

    if (_shopName.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptShopNameSetup(isFirstTime: true));
    }
  }

  Future<void> _commitStateToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vanik_kirana_inventory_db_v4', jsonEncode(_inventory.map((e) => e.toMap()).toList()));
    await prefs.setString('vanik_kirana_sales_db_v4', jsonEncode(_sales.map((e) => e.toMap()).toList()));
    await prefs.setString('vanik_kirana_shop_name', _shopName);
    await prefs.setString('vanik_kirana_shop_code', _shopSyncCode);
  }

  void _promptShopNameSetup({bool isFirstTime = false}) {
    final nameCtrl = TextEditingController(text: _shopName);
    showDialog(
      context: context,
      barrierDismissible: !isFirstTime,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isFirstTime ? 'Dukaan Setup Karein' : 'Dukaan Ka Naam Badlein', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apni dukaan ka naam daalein jo customer bill aur WhatsApp receipt par print hoga:'),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Maa Durga Kirana Store',
                labelText: 'Store / Owner Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5A27),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() => _shopName = nameCtrl.text.trim());
                _commitStateToDisk();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save & Continue', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openSyncAndStaffDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Shop Staff & Multi-User Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFBF8F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8DFC8))),
              child: Column(
                children: [
                  const Text('Aapki Dukaan Ka Joining Code:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(_shopSyncCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3, color: Color(0xFF2D5A27))),
                  const SizedBox(height: 4),
                  const Text('Staff ke phone me ye code daalkar sync karein', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Doosri dukaan se judna chahte hain?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter 6-digit Code',
                labelText: 'Join Shop Code',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9822B), foregroundColor: Colors.white),
                  onPressed: () {
                    if (codeCtrl.text.trim().isNotEmpty) {
                      setState(() => _shopSyncCode = codeCtrl.text.trim());
                      _commitStateToDisk();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop Joining Code updated successfully!')));
                    }
                  },
                  child: const Text('Join Shop'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _recordNewSale(SaleRecord sale) {
    setState(() {
      _sales.insert(0, sale);
      for (final cartItem in sale.items) {
        final idx = _inventory.indexWhere((p) => p.barcode == cartItem.product.barcode);
        if (idx >= 0) {
          _inventory[idx].stock = (_inventory[idx].stock - cartItem.quantity).clamp(0.0, 999999.0);
        }
      }
    });
    _commitStateToDisk();
  }

  void _saveOrUpdateProduct(ProductItem item) {
    setState(() {
      final idx = _inventory.indexWhere((p) => p.barcode == item.barcode);
      if (idx >= 0) {
        _inventory[idx] = item;
      } else {
        _inventory.add(item);
      }
    });
    _commitStateToDisk();
  }

  void _deleteProduct(String barcode) {
    setState(() {
      _inventory.removeWhere((p) => p.barcode == barcode);
    });
    _commitStateToDisk();
  }

  void _settleUdhaarRecord(String saleId) {
    setState(() {
      final s = _sales.firstWhere((x) => x.id == saleId);
      s.isPaid = true;
    });
    _commitStateToDisk();
  }

  Widget _buildTopProfileHeader() {
    final title = _shopName.isEmpty ? 'Setup Shop' : _shopName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => _promptShopNameSetup(isFirstTime: false),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8DFC8)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(radius: 12, backgroundColor: Color(0xFFE8DFC8), child: Icon(Icons.person, size: 16, color: Color(0xFF7FA06B))),
                  const SizedBox(width: 8),
                  Text(
                    title.length > 15 ? '${title.substring(0, 14)}...' : title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 13, color: Colors.grey),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8DFC8)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 16, color: Color(0xFFD9822B)),
                    const SizedBox(width: 4),
                    Text('Orders: ${_sales.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2D5A27))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openSyncAndStaffDialog,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8DFC8)),
                  ),
                  child: const Icon(Icons.verified, size: 18, color: Color(0xFF7FA06B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final views = [
      MyShopScreen(
        inventory: _inventory,
        onProductUpdated: _saveOrUpdateProduct,
        onProductDeleted: _deleteProduct,
      ),
      MakeBillScreen(
        inventory: _inventory,
        shopName: _shopName.isEmpty ? 'Kirana General Store' : _shopName,
        onSaleSuccess: _recordNewSale,
        onProductAddOrUpdate: _saveOrUpdateProduct,
      ),
      MySalesScreen(
        sales: _sales,
        shopName: _shopName.isEmpty ? 'Kirana Store' : _shopName,
        onUdhaarCleared: _settleUdhaarRecord,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopProfileHeader(),
            Expanded(child: views[_currentIndex]),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            InkWell(
              onTap: () => setState(() => _currentIndex = 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront, color: _currentIndex == 0 ? const Color(0xFF2D5A27) : Colors.grey),
                  Text('My Shop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _currentIndex == 0 ? const Color(0xFF2D5A27) : Colors.grey)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 1),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF7FA06B),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt, color: Colors.white, size: 24),
                    Text('Make Bill', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _currentIndex = 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: _currentIndex == 2 ? const Color(0xFF2D5A27) : Colors.grey),
                  Text('My Sales', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _currentIndex == 2 ? const Color(0xFF2D5A27) : Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ==========================================
// 4. SCREEN: MAKE BILL (SCANNER & CART)
// ==========================================
class MakeBillScreen extends StatefulWidget {
  final List<ProductItem> inventory;
  final String shopName;
  final Function(SaleRecord) onSaleSuccess;
  final Function(ProductItem) onProductAddOrUpdate;

  const MakeBillScreen({
    super.key,
    required this.inventory,
    required this.shopName,
    required this.onSaleSuccess,
    required this.onProductAddOrUpdate,
  });

  @override
  State<MakeBillScreen> createState() => _MakeBillScreenState();
}

class _MakeBillScreenState extends State<MakeBillScreen> {
  final List<CartItem> _cart = [];
  DateTime _lastScanTime = DateTime.now();

  double get _currentBillTotal => _cart.fold(0.0, (sum, item) => sum + item.total);

  void _onBarcodeDetected(BarcodeCapture capture) {
    final now = DateTime.now();
    if (now.difference(_lastScanTime).inMilliseconds < 1600) return;
    _lastScanTime = now;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        _processDetectedBarcode(code.trim());
        break;
      }
    }
  }

  void _processDetectedBarcode(String code) {
    final matches = widget.inventory.where((p) => p.barcode == code).toList();
    if (matches.isNotEmpty) {
      _displayAddToCartSheet(matches.first);
    } else {
      _displayNewBarcodePrompt(code);
    }
  }

  void _displayAddToCartSheet(ProductItem item) {
    final qtyCtrl = TextEditingController(text: item.type == ItemType.loose ? '1.0' : '1');
    final priceCtrl = TextEditingController(text: item.sellingPrice.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.imagePath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(item.imagePath), height: 75, width: 75, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory, size: 50)),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: item.type == ItemType.loose ? 'Weight (in Kg)' : 'Quantity (Pieces)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Unit Rate (₹)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5A27),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: () {
              final q = double.tryParse(qtyCtrl.text) ?? 1.0;
              final p = double.tryParse(priceCtrl.text) ?? item.sellingPrice;
              setState(() {
                final idx = _cart.indexWhere((c) => c.product.barcode == item.barcode);
                if (idx >= 0) {
                  _cart[idx].quantity += q;
                  _cart[idx].customPrice = p;
                } else {
                  _cart.add(CartItem(product: item, quantity: q, customPrice: p));
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add to Current Bill', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _displayNewBarcodePrompt(String code) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Barcode: $code', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price (₹)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9822B), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
            onPressed: () {
              final p = double.tryParse(priceCtrl.text) ?? 0.0;
              if (p > 0) {
                final newItem = ProductItem(
                  id: 'itm_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Item $code',
                  barcode: code,
                  sellingPrice: p,
                  stock: 0.0,
                  type: ItemType.piece,
                  isPending: true,
                );
                widget.onProductAddOrUpdate(newItem);
                setState(() => _cart.add(CartItem(product: newItem, quantity: 1.0, customPrice: p)));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save & Add to Bill'),
          ),
        ],
      ),
    );
  }

  void _finalizeTransaction(PaymentMethod method) {
    if (_cart.isEmpty) return;

    if (method == PaymentMethod.udhaar) {
      final phoneCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Customer Udhaar Khata', style: TextStyle(color: Color(0xFFD9822B), fontWeight: FontWeight.bold)),
          content: TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Customer Mobile Number', border: OutlineInputBorder()),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9822B), foregroundColor: Colors.white),
              onPressed: () {
                if (phoneCtrl.text.trim().isNotEmpty) {
                  final sale = SaleRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    date: DateTime.now(),
                    items: List.from(_cart),
                    total: _currentBillTotal,
                    profit: _cart.fold(0.0, (s, i) => s + i.profit),
                    method: PaymentMethod.udhaar,
                    customerPhone: phoneCtrl.text.trim(),
                    isPaid: false,
                  );
                  widget.onSaleSuccess(sale);
                  setState(() => _cart.clear());
                  Navigator.pop(ctx);
                  _openThermalReceiptModal(sale);
                }
              },
              child: const Text('Save Udhaar Record'),
            ),
          ],
        ),
      );
    } else {
      final sale = SaleRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        items: List.from(_cart),
        total: _currentBillTotal,
        profit: _cart.fold(0.0, (s, i) => s + i.profit),
        method: method,
      );
      widget.onSaleSuccess(sale);
      setState(() => _cart.clear());
      _openThermalReceiptModal(sale);
    }
  }

  void _openThermalReceiptModal(SaleRecord sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long, color: Color(0xFF2D5A27)),
                const SizedBox(width: 8),
                Text('${widget.shopName} Bill', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(),
            ...sale.items.map((i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('${i.product.name} x ${i.quantity}')),
                  Text('₹${i.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Bill:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '₹${sale.total.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D5A27)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 42)),
              onPressed: () {
                final text = "${widget.shopName} Bill\nTotal: ₹${sale.total.toStringAsFixed(0)}\nItems: ${sale.items.length}\nThank you for shopping with us!";
                launchUrl(Uri.parse("https://wa.me/?text=${Uri.encodeComponent(text)}"));
              },
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share Receipt on WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }

  void _openLooseItemSelection() {
    final looseList = widget.inventory.where((p) => p.type == ItemType.loose).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Select Loose Item (Weight)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: looseList.isEmpty
                  ? const Center(child: Text('No loose items in shop yet.'))
                  : ListView.builder(
                      itemCount: looseList.length,
                      itemBuilder: (ctx, i) {
                        final item = looseList[i];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item.imagePath.isNotEmpty
                                ? Image.file(File(item.imagePath), width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.scale, size: 36))
                                : const CircleAvatar(backgroundColor: Color(0xFFE8DFC8), child: Icon(Icons.scale, color: Color(0xFF2D5A27))),
                          ),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Rate: ₹${item.sellingPrice.toStringAsFixed(0)}/kg | Stock: ${item.stock.toStringAsFixed(0)} kg'),
                          onTap: () {
                            Navigator.pop(c);
                            _displayAddToCartSheet(item);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(height: 180, child: MobileScanner(onDetect: _onBarcodeDetected)),
            Container(
              width: 220,
              height: 100,
              decoration: BoxDecoration(border: Border.all(color: Colors.greenAccent, width: 2), borderRadius: BorderRadius.circular(12)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Bill', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5A27))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8DFC8), foregroundColor: Colors.black87),
                onPressed: _openLooseItemSelection,
                icon: const Icon(Icons.scale, size: 18),
                label: const Text('Loose Item'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _cart.isEmpty
              ? const Center(child: Text('Scan items or select loose goods to make bill', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _cart.length,
                  itemBuilder: (ctx, i) {
                    final c = _cart[i];
                    return ListTile(
                      title: Text(c.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('₹${c.customPrice} x ${c.quantity} ${c.product.type == ItemType.loose ? "kg" : "pc"}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${c.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.orange), onPressed: () => setState(() => _cart.removeAt(i))),
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Bill:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('₹${_currentBillTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D5A27), foregroundColor: Colors.white),
                      onPressed: () => _finalizeTransaction(PaymentMethod.online),
                      child: const Text('Online'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9822B), foregroundColor: Colors.white),
                      onPressed: () => _finalizeTransaction(PaymentMethod.cash),
                      child: const Text('Cash'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8DFC8), foregroundColor: Colors.black87),
                      onPressed: () => _finalizeTransaction(PaymentMethod.udhaar),
                      child: const Text('Udhaar'),
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
// ==========================================
// 5. SCREEN: MY SHOP (BARCODE & LOOSE VIEWS)
// ==========================================
class MyShopScreen extends StatefulWidget {
  final List<ProductItem> inventory;
  final Function(ProductItem) onProductUpdated;
  final Function(String) onProductDeleted;

  const MyShopScreen({
    super.key,
    required this.inventory,
    required this.onProductUpdated,
    required this.onProductDeleted,
  });

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen> {
  int _activeSubTab = 0; // 0: Shop items, 1: Pending
  bool _isLooseMode = false; // False: Barcode, True: Loose Commodity
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageForProduct(ProductItem item, StateSetter setModalState) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo with Camera'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.camera, maxWidth: 600);
                if (picked != null) {
                  setModalState(() => item.imagePath = picked.path);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
                if (picked != null) {
                  setModalState(() => item.imagePath = picked.path);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Exact Vanik Stock & Edit Modal (Screenshot 43)
  void _openExactVanikModal(ProductItem item, {bool isNew = false}) {
    final nameCtrl = TextEditingController(text: item.name);
    final buyCtrl = TextEditingController(text: item.buyingPrice > 0 ? item.buyingPrice.toStringAsFixed(0) : '');
    final sellCtrl = TextEditingController(text: item.sellingPrice > 0 ? item.sellingPrice.toStringAsFixed(0) : '');
    final stockCtrl = TextEditingController(text: item.stock > 0 ? item.stock.toStringAsFixed(0) : '');

    final isLoose = item.type == ItemType.loose;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(20),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F1EA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFECE7DC)),
                            image: item.imagePath.isNotEmpty
                                ? DecorationImage(image: FileImage(File(item.imagePath)), fit: BoxFit.cover)
                                : null,
                          ),
                          child: item.imagePath.isEmpty
                              ? const Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF2D5A27))
                              : null,
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: InkWell(
                            onTap: () => _pickImageForProduct(item, setModalState),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.barcode.length > 12 ? item.barcode.substring(0, 11) : item.barcode,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F1EA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('Product name', style: TextStyle(color: Color(0xFF9E8A68), fontSize: 12, fontWeight: FontWeight.bold)),
                                TextField(
                                  controller: nameCtrl,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4)),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildInputRow(
                  label: isLoose ? 'Buying price of 1 Kg' : 'Buying price of 1 Piece',
                  controller: buyCtrl,
                ),
                const SizedBox(height: 10),
                _buildInputRow(
                  label: isLoose ? 'Your selling price of 1 Kg' : 'Your selling price of 1 Piece',
                  controller: sellCtrl,
                ),
                const SizedBox(height: 10),
                _buildInputRow(
                  label: isLoose ? 'Current kilos in shop' : 'Current pieces in shop',
                  controller: stockCtrl,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (!isNew)
                      InkWell(
                        onTap: () {
                          widget.onProductDeleted(item.barcode);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.grey, size: 24),
                        ),
                      ),
                    if (!isNew) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD9822B),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          item.name = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : (isLoose ? 'Loose Commodity' : 'Item ${item.barcode}');
                          item.buyingPrice = double.tryParse(buyCtrl.text) ?? 0.0;
                          item.sellingPrice = double.tryParse(sellCtrl.text) ?? 0.0;
                          item.stock = double.tryParse(stockCtrl.text) ?? 0.0;
                          item.isPending = false;
                          widget.onProductUpdated(item);
                          Navigator.pop(ctx);
                        },
                        child: Text(isNew ? 'Save' : 'Update', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildInputRow({required String label, required TextEditingController controller}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECE7DC)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14))),
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
        ],
      ),
    );
  }

  void _openBarcodeStockFlow() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(8), child: Text('Scan Barcode to Stock', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      if (b.rawValue != null && b.rawValue!.isNotEmpty) {
                        Navigator.pop(ctx);
                        final existing = widget.inventory.where((p) => p.barcode == b.rawValue!).toList();
                        if (existing.isNotEmpty) {
                          _openExactVanikModal(existing.first);
                        } else {
                          final newItem = ProductItem(
                            id: 'item_${DateTime.now().millisecondsSinceEpoch}',
                            name: '',
                            barcode: b.rawValue!,
                            sellingPrice: 0.0,
                            buyingPrice: 0.0,
                            stock: 0.0,
                            type: ItemType.piece,
                          );
                          _openExactVanikModal(newItem, isNew: true);
                        }
                        break;
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLooseStockFlow() {
    final newItem = ProductItem(
      id: 'loose_${DateTime.now().millisecondsSinceEpoch}',
      name: '',
      barcode: 'L_${DateTime.now().millisecondsSinceEpoch}',
      sellingPrice: 0.0,
      buyingPrice: 0.0,
      stock: 0.0,
      type: ItemType.loose,
    );
    _openExactVanikModal(newItem, isNew: true);
  }

  @override
  Widget build(BuildContext context) {
    final filteredByType = widget.inventory.where((p) => _isLooseMode ? p.type == ItemType.loose : p.type == ItemType.piece).toList();
    final pendingList = filteredByType.where((p) => p.isPending).toList();
    final activeList = _activeSubTab == 0 ? filteredByType : pendingList;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _activeSubTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _activeSubTab == 0 ? const Color(0xFFD8CBB5) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD8CBB5)),
                    ),
                    child: Center(
                      child: Text('Shop items: ${filteredByType.length}', style: TextStyle(fontWeight: FontWeight.bold, color: _activeSubTab == 0 ? const Color(0xFF4A3E2C) : Colors.black87)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _activeSubTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _activeSubTab == 1 ? const Color(0xFFD8CBB5) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD8CBB5)),
                    ),
                    child: Center(
                      child: Text('Pending: ${pendingList.length}', style: TextStyle(fontWeight: FontWeight.bold, color: _activeSubTab == 1 ? const Color(0xFF4A3E2C) : Colors.black87)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8DFC8))),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(_isLooseMode ? 'Search loose item' : 'Search barcode item', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _isLooseMode = false),
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: !_isLooseMode ? const Color(0xFFE8DFC8) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8DFC8)),
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: Color(0xFF2D5A27)),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _isLooseMode = true),
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _isLooseMode ? const Color(0xFFE8DFC8) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8DFC8)),
                  ),
                  child: const Icon(Icons.scale, color: Color(0xFF2D5A27)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9822B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLooseMode ? _openLooseStockFlow : _openBarcodeStockFlow,
              icon: Icon(_isLooseMode ? Icons.scale : Icons.qr_code, size: 20),
              label: Text(_isLooseMode ? 'Stock loose item' : 'Stock barcode items', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: activeList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_isLooseMode ? Icons.scale_outlined : Icons.storefront_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(_isLooseMode ? 'Dukaan me koi loose item nahi hai' : 'Dukaan me abhi koi barcode samaan nahi hai', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text('Upar diye button se ${_isLooseMode ? "loose item" : "barcode maal"} jodein', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: activeList.length,
                  itemBuilder: (ctx, i) {
                    final it = activeList[i];
                    return InkWell(
                      onTap: () => _openExactVanikModal(it),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFECE7DC)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F1EA),
                                borderRadius: BorderRadius.circular(10),
                                image: it.imagePath.isNotEmpty ? DecorationImage(image: FileImage(File(it.imagePath)), fit: BoxFit.cover) : null,
                              ),
                              child: it.imagePath.isEmpty
                                  ? Icon(it.type == ItemType.loose ? Icons.scale : Icons.inventory_2, color: const Color(0xFF2D5A27))
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${it.stock.toStringAsFixed(0)} ${it.type == ItemType.loose ? "kilo" : "piece"}',
                                    style: TextStyle(color: it.stock < 5 ? Colors.red : Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              it.type == ItemType.loose ? '₹${it.sellingPrice.toStringAsFixed(0)}/kg' : '₹${it.sellingPrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF2D5A27)),
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
// ==========================================
// 6. SCREEN: MY SALES (VANIK DAILY BAR CHART)
// ==========================================
class MySalesScreen extends StatelessWidget {
  final List<SaleRecord> sales;
  final String shopName;
  final Function(String) onUdhaarCleared;

  const MySalesScreen({
    super.key,
    required this.sales,
    required this.shopName,
    required this.onUdhaarCleared,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todaySales = sales.where((s) => s.date.day == now.day && s.date.month == now.month && s.date.year == now.year).toList();
    final todayTotal = todaySales.fold(0.0, (sum, r) => sum + r.total);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFECE7DC)),
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
                      const Text('Sales of day', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('₹${todayTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFF4F1EA), borderRadius: BorderRadius.circular(10)),
                    child: Text(DateFormat('MMMM yyyy').format(now), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (idx) {
                    final targetDate = now.subtract(Duration(days: 4 - idx));
                    final dayTotal = sales
                        .where((s) => s.date.day == targetDate.day && s.date.month == targetDate.month && s.date.year == targetDate.year)
                        .fold(0.0, (sum, r) => sum + r.total);
                    final double barHeight = ((dayTotal > 0 ? (dayTotal / 500.0) * 60 : 6).clamp(6.0, 70.0)).toDouble();

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('₹${dayTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Container(
                          width: 22,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: idx == 4 ? const Color(0xFF7FA06B) : const Color(0xFFD8CBB5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          idx == 4 ? 'Today' : '${targetDate.day} ${DateFormat('MMM').format(targetDate)}',
                          style: TextStyle(fontSize: 10, fontWeight: idx == 4 ? FontWeight.bold : FontWeight.normal),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Bills of the day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D5A27))),
          ),
        ),
       Expanded(
          child: todaySales.isEmpty
              ? const Center(child: Text('No bills created today yet', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: todaySales.length,
                  itemBuilder: (ctx, i) {
                    final s = todaySales[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFECE7DC)),
                      ),
                      child: ListTile(
                        leading: Icon(
                          s.method == PaymentMethod.online ? Icons.qr_code : (s.method == PaymentMethod.cash ? Icons.money : Icons.account_balance_wallet),
                          color: const Color(0xFF2D5A27),
                        ),
                        title: Text('₹${s.total.toStringAsFixed(0)} (${s.method.name.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${DateFormat('hh:mm a').format(s.date)} ${s.customerPhone.isNotEmpty ? "| Mobile: ${s.customerPhone}" : ""}'),
                        trailing: s.method == PaymentMethod.udhaar
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (s.customerPhone.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.share, color: Colors.green, size: 20),
                                      onPressed: () {
                                        final reminder = "Namaste! $shopName se aapka ₹${s.total.toStringAsFixed(0)} ka udhaar baaki hai. Kripya samay par chukta karein.";
                                        launchUrl(Uri.parse("https://wa.me/91${s.customerPhone}?text=${Uri.encodeComponent(reminder)}"));
                                      },
                                    ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: s.isPaid ? Colors.green : Colors.red, foregroundColor: Colors.white),
                                    onPressed: s.isPaid ? null : () => onUdhaarCleared(s.id),
                                    child: Text(s.isPaid ? 'PAID' : 'COLLECT'),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
} 
