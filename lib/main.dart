import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String imageUrl;
  bool isPending;

  ProductItem({
    required this.id,
    required this.name,
    required this.barcode,
    required this.sellingPrice,
    this.buyingPrice = 0.0,
    required this.stock,
    required this.type,
    this.imageUrl = '',
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
    'imageUrl': imageUrl,
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
    imageUrl: map['imageUrl'] ?? '',
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
      title: 'Vanik POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF9F9F6),
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
// 3. PERSISTENT NAVIGATION SHELL
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1; // Default: Make Bill
  List<ProductItem> _inventory = [];
  List<SaleRecord> _sales = [];

  @override
  void initState() {
    super.initState();
    _loadStateFromDisk();
  }

  Future<void> _loadStateFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final invString = prefs.getString('vanik_inventory_db');
    final salesString = prefs.getString('vanik_sales_db');

    if (invString != null) {
      final List dec = jsonDecode(invString);
      _inventory = dec.map((e) => ProductItem.fromMap(e)).toList();
    } else {
      // Pre-seed sample items
      _inventory = [
        ProductItem(
          id: 'item_1',
          name: "Haldiram's Punjabi Tadka",
          barcode: '8901414000102',
          sellingPrice: 10.0,
          buyingPrice: 8.0,
          stock: 50.0,
          type: ItemType.piece,
          imageUrl: 'https://images.openfoodfacts.org/images/products/890/141/400/0102/front_en.11.400.jpg',
        ),
        ProductItem(
          id: 'item_2',
          name: 'Sugar (Loose Chini)',
          barcode: 'LOOSE_SUGAR_01',
          sellingPrice: 44.0,
          buyingPrice: 38.0,
          stock: 100.0,
          type: ItemType.loose,
        ),
      ];
    }

    if (salesString != null) {
      final List dec = jsonDecode(salesString);
      _sales = dec.map((e) => SaleRecord.fromMap(e)).toList();
    }
    setState(() {});
  }

  Future<void> _commitStateToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vanik_inventory_db', jsonEncode(_inventory.map((e) => e.toMap()).toList()));
    await prefs.setString('vanik_sales_db', jsonEncode(_sales.map((e) => e.toMap()).toList()));
  }

  void _recordNewSale(SaleRecord sale) {
    setState(() {
      _sales.insert(0, sale);
      // Auto-deduct stock
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

  void _settleUdhaarRecord(String saleId) {
    setState(() {
      final s = _sales.firstWhere((x) => x.id == saleId);
      s.isPaid = true;
    });
    _commitStateToDisk();
  }

  @override
  Widget build(BuildContext context) {
    final views = [
      MyShopScreen(
        inventory: _inventory,
        onProductUpdated: _saveOrUpdateProduct,
      ),
      MakeBillScreen(
        inventory: _inventory,
        onSaleSuccess: _recordNewSale,
        onProductAddOrUpdate: _saveOrUpdateProduct,
      ),
      MySalesScreen(
        sales: _sales,
        onUdhaarCleared: _settleUdhaarRecord,
      ),
    ];

    return Scaffold(
      body: views[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: const Color(0xFFE8DFC8),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: Color(0xFF2D5A27)),
            label: 'My Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale, color: Color(0xFF2D5A27)),
            label: 'Make Bill',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF2D5A27)),
            label: 'My Sales',
          ),
        ],
      ),
    );
  }
}
// ==========================================
// 4. SCREEN: MAKE BILL (SCANNER & CART)
// ==========================================
class MakeBillScreen extends StatefulWidget {
  final List<ProductItem> inventory;
  final Function(SaleRecord) onSaleSuccess;
  final Function(ProductItem) onProductAddOrUpdate;

  const MakeBillScreen({
    super.key,
    required this.inventory,
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
            if (item.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.imageUrl,
                  height: 75,
                  width: 75,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.inventory, size: 50, color: Color(0xFF2D5A27)),
                ),
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
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Selling Price (₹)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9822B),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
            ),
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, color: Color(0xFF2D5A27)),
                SizedBox(width: 8),
                Text('Vanik Bill Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 42),
              ),
              onPressed: () {
                final text = "Vanik Bill: Total ₹${sale.total.toStringAsFixed(0)} for ${sale.items.length} items.";
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
              child: ListView.builder(
                itemCount: looseList.length,
                itemBuilder: (ctx, i) => ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8DFC8),
                    child: Icon(Icons.scale, color: Color(0xFF2D5A27)),
                  ),
                  title: Text(looseList[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Rate: ₹${looseList[i].sellingPrice}/kg | Stock: ${looseList[i].stock} kg'),
                  onTap: () {
                    Navigator.pop(c);
                    _displayAddToCartSheet(looseList[i]);
                  },
                ),
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
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(height: 180, child: MobileScanner(onDetect: _onBarcodeDetected)),
                Container(
                  width: 220,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.greenAccent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.orange),
                                onPressed: () => setState(() => _cart.removeAt(i)),
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
        ),
      ),
    );
  }
}

// ==========================================
// 5. SCREEN: MY SHOP (STOCK, PENCIL EDIT, PHOTO)
// ==========================================
class MyShopScreen extends StatefulWidget {
  final List<ProductItem> inventory;
  final Function(ProductItem) onProductUpdated;

  const MyShopScreen({
    super.key,
    required this.inventory,
    required this.onProductUpdated,
  });

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen> {
  int _activeSubTab = 0; // 0: All Shop items, 1: Pending items

  void _openStockEditModal(ProductItem item) {
    final buyCtrl = TextEditingController(text: item.buyingPrice > 0 ? item.buyingPrice.toStringAsFixed(0) : '');
    final sellCtrl = TextEditingController(text: item.sellingPrice.toStringAsFixed(0));
    final stockCtrl = TextEditingController(text: item.stock.toStringAsFixed(0));
    final nameCtrl = TextEditingController(text: item.name);
    final photoCtrl = TextEditingController(text: item.imageUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Product Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: buyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Buying Price (Cost ₹)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sellCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Selling Price (Rate ₹)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Total Current Stock', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: photoCtrl,
                decoration: const InputDecoration(labelText: 'Product Photo Link (URL)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5A27),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: () {
              item.name = nameCtrl.text.trim();
              item.buyingPrice = double.tryParse(buyCtrl.text) ?? item.buyingPrice;
              item.sellingPrice = double.tryParse(sellCtrl.text) ?? item.sellingPrice;
              item.stock = double.tryParse(stockCtrl.text) ?? item.stock;
              item.imageUrl = photoCtrl.text.trim();
              item.isPending = false;
              widget.onProductUpdated(item);
              Navigator.pop(ctx);
            },
            child: const Text('Save Details'),
          ),
        ],
      ),
    );
  }

  void _addNewLooseItemDialog() {
    final nameCtrl = TextEditingController();
    final buyCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final stockCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Loose Commodity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name (e.g. Chana Dal)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: buyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Buying Cost per Kg (₹)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sellCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Selling Price per Kg (₹)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Weight Stock (Kg)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9822B),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                final newItem = ProductItem(
                  id: 'loose_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  barcode: 'L_${DateTime.now().millisecondsSinceEpoch}',
                  sellingPrice: double.tryParse(sellCtrl.text) ?? 0.0,
                  buyingPrice: double.tryParse(buyCtrl.text) ?? 0.0,
                  stock: double.tryParse(stockCtrl.text) ?? 0.0,
                  type: ItemType.loose,
                );
                widget.onProductUpdated(newItem);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save Loose Item'),
          ),
        ],
      ),
    );
  }

 @override
  Widget build(BuildContext context) {
    final pendingList = widget.inventory.where((p) => p.isPending).toList();
    final activeList = _activeSubTab == 0 ? widget.inventory : pendingList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shop Inventory', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFFD9822B), size: 28),
            tooltip: 'Add Loose Item',
            onPressed: _addNewLooseItemDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeSubTab == 0 ? const Color(0xFF2D5A27) : Colors.white,
                      foregroundColor: _activeSubTab == 0 ? Colors.white : Colors.black,
                    ),
                    onPressed: () => setState(() => _activeSubTab = 0),
                    child: Text('All Items: ${widget.inventory.length}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeSubTab == 1 ? const Color(0xFFD9822B) : Colors.white,
                      foregroundColor: _activeSubTab == 1 ? Colors.white : Colors.black,
                    ),
                    onPressed: () => setState(() => _activeSubTab = 1),
                    child: Text('Pending: ${pendingList.length}'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: activeList.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final it = activeList[i];
                return ListTile(
                  leading: it.imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            it.imageUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.inventory, color: Color(0xFF2D5A27)),
                          ),
                        )
                      : CircleAvatar(
                          backgroundColor: const Color(0xFFE8DFC8),
                          child: Icon(it.type == ItemType.loose ? Icons.scale : Icons.inventory_2, color: const Color(0xFF2D5A27)),
                        ),
                  title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Sell: ₹${it.sellingPrice} | Cost: ₹${it.buyingPrice} | Stock: ${it.stock} ${it.type == ItemType.loose ? "kg" : "pc"}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF2D5A27)),
                    onPressed: () => _openStockEditModal(it),
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

// ==========================================
// 6. SCREEN: MY SALES (PROFIT & UDHAAR LEDGER)
// ==========================================
class MySalesScreen extends StatelessWidget {
  final List<SaleRecord> sales;
  final Function(String) onUdhaarCleared;

  const MySalesScreen({
    super.key,
    required this.sales,
    required this.onUdhaarCleared,
  });

  @override
  Widget build(BuildContext context) {
    final totalTurnover = sales.fold(0.0, (sum, r) => sum + r.total);
    final totalProfit = sales.fold(0.0, (sum, r) => sum + r.profit);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Sales & Udhaar Khata', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Total Sale', style: TextStyle(color: Colors.grey)),
                    Text(
                      '₹${totalTurnover.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D5A27)),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Total Profit', style: TextStyle(color: Colors.grey)),
                    Text(
                      '₹${totalProfit.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD9822B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: sales.length,
              itemBuilder: (ctx, i) {
                final s = sales[i];
                return ListTile(
                  leading: Icon(
                    s.method == PaymentMethod.online
                        ? Icons.qr_code
                        : (s.method == PaymentMethod.cash ? Icons.money : Icons.account_balance_wallet),
                    color: const Color(0xFF2D5A27),
                  ),
                  title: Text(
                    '₹${s.total.toStringAsFixed(0)} (${s.method.name.toUpperCase()})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${DateFormat('hh:mm a').format(s.date)} ${s.customerPhone.isNotEmpty ? "| Mobile: ${s.customerPhone}" : ""}',
                  ),
                  trailing: s.method == PaymentMethod.udhaar
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: s.isPaid ? Colors.green : Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: s.isPaid ? null : () => onUdhaarCleared(s.id),
                          child: Text(s.isPaid ? 'PAID' : 'COLLECT'),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 
