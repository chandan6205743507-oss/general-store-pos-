import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';

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
        primaryColor: const Color(0xFF7FA06B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7FA06B),
          primary: const Color(0xFF7FA06B),
          secondary: const Color(0xFFD9822B),
        ),
        fontFamily: 'sans-serif',
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTab = 1; // 0: My Shop, 1: Make Bill, 2: My Sales
  List<ProductItem> _inventory = [];
  List<SaleRecord> _sales = [];
  bool _isLoading = true;
  String _shopCode = 'VK-9482';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final invData = prefs.getString('vanik_inv_db');
    final salesData = prefs.getString('vanik_sales_db');

    if (invData != null) {
      final List decoded = jsonDecode(invData);
      _inventory = decoded.map((e) => ProductItem.fromMap(e)).toList();
    } else {
      _inventory = [
        ProductItem(
          id: '1',
          name: "Haldiram's Punjabi Tadka",
          barcode: '8904063254450',
          sellingPrice: 5.0,
          buyingPrice: 4.0,
          stock: 40.0,
          type: ItemType.piece,
          imageUrl: 'https://images.openfoodfacts.org/images/products/890/406/325/4450/front_en.3.200.jpg',
        ),
        ProductItem(
          id: '2',
          name: 'Sugar (Chini)',
          barcode: 'L_CHINI',
          sellingPrice: 44.0,
          buyingPrice: 39.0,
          stock: 50.0,
          type: ItemType.loose,
        ),
        ProductItem(
          id: '3',
          name: 'Chana Dal',
          barcode: 'L_DAL',
          sellingPrice: 85.0,
          buyingPrice: 75.0,
          stock: 25.0,
          type: ItemType.loose,
        ),
      ];
    }

    if (salesData != null) {
      final List decSales = jsonDecode(salesData);
      _sales = decSales.map((e) => SaleRecord.fromMap(e)).toList();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vanik_inv_db', jsonEncode(_inventory.map((e) => e.toMap()).toList()));
    await prefs.setString('vanik_sales_db', jsonEncode(_sales.map((e) => e.toMap()).toList()));
  }

  void _saveProduct(ProductItem item) {
    setState(() {
      final idx = _inventory.indexWhere((p) => p.barcode == item.barcode);
      if (idx >= 0) {
        _inventory[idx] = item;
      } else {
        _inventory.insert(0, item);
      }
    });
    _saveData();
  }

  void _recordSale(SaleRecord sale) {
    setState(() {
      _sales.insert(0, sale);
      for (final cartItem in sale.items) {
        final idx = _inventory.indexWhere((p) => p.barcode == cartItem.product.barcode);
        if (idx >= 0) {
          _inventory[idx].stock -= cartItem.quantity;
          if (_inventory[idx].stock < 0) _inventory[idx].stock = 0;
        }
      }
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF7FA06B))));
    }

    final pages = [
      MyShopScreen(
        inventory: _inventory,
        onProductUpdated: _saveProduct,
      ),
      MakeBillScreen(
        inventory: _inventory,
        onSaleSuccess: _recordSale,
        onProductAddOrUpdate: _saveProduct,
      ),
      MySalesScreen(
        sales: _sales,
        pendingCount: _inventory.where((p) => p.isPending).length,
        onPendingTabClicked: () => setState(() => _currentTab = 0),
        onToggleUdhaarPaid: (id, paid) {
          setState(() {
            final sale = _sales.firstWhere((s) => s.id == id);
            sale.isPaid = paid;
          });
          _saveData();
        },
      ),
    ];

    return Scaffold(
      body: pages[_currentTab],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -1))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) => setState(() => _currentTab = index),
          selectedItemColor: const Color(0xFF4A6B35),
          unselectedItemColor: Colors.black54,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined, size: 28),
              label: 'My Shop',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7FA06B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.point_of_sale, color: Colors.white, size: 28),
              ),
              label: 'Make Bill',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined, size: 28),
              label: 'My Sales',
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- MAKE BILL VIEW -----------------
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
  bool _isScanning = true;
  DateTime _lastDetect = DateTime.now();

  double get _totalBill => _cart.fold(0.0, (s, i) => s + i.total);

  Future> _lookupBarcode(String code) async {
    try {
      final res = await http.get(Uri.parse('https://world.openfoodfacts.org/api/v0/product/$code.json')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['status'] == 1 && d['product'] != null) {
          return {
            'name': d['product']['product_name'] ?? '',
            'image': d['product']['image_front_small_url'] ?? '',
          };
        }
      }
    } catch (_) {}
    return {'name': '', 'image': ''};
  }

  void _onDetect(BarcodeCapture capture) {
    final now = DateTime.now();
    if (now.difference(_lastDetect).inMilliseconds < 1600) return;
    _lastDetect = now;

    for (final b in capture.barcodes) {
      if (b.rawValue != null && b.rawValue!.isNotEmpty) {
        _handleDetectedBarcode(b.rawValue!);
        break;
      }
    }
  }

  void _handleDetectedBarcode(String code) {
    final match = widget.inventory.where((p) => p.barcode == code).toList();
    if (match.isNotEmpty) {
      _showAddToCartDialog(match.first);
    } else {
      _showNewItemPrompt(code);
    }
  }

  void _showAddToCartDialog(ProductItem item) {
    final qtyCtrl = TextEditingController(text: item.type == ItemType.loose ? '1.0' : '1');
    final priceCtrl = TextEditingController(text: item.sellingPrice.toStringAsFixed(0));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.imageUrl.isNotEmpty)
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(item.imageUrl, width: 90, height: 90, fit: BoxFit.cover)),
            const SizedBox(height: 10),
            Text(item.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 15),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: item.type == ItemType.loose ? 'Weight (in Kilo)' : 'How many Pieces?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Price of 1 Unit (₹)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7FA06B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                final qty = double.tryParse(qtyCtrl.text) ?? 1.0;
                final price = double.tryParse(priceCtrl.text) ?? item.sellingPrice;
                setState(() {
                  final idx = _cart.indexWhere((c) => c.product.barcode == item.barcode);
                  if (idx >= 0) {
                    _cart[idx].quantity += qty;
                    _cart[idx].customPrice = price;
                  } else {
                    _cart.add(CartItem(product: item, quantity: qty, customPrice: price));
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('OK', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewItemPrompt(String code) async {
    final meta = await _lookupBarcode(code);
    if (!mounted) return;

    final nameCtrl = TextEditingController(text: meta['name']!.isNotEmpty ? meta['name'] : '');
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(code, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: 'Product Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(labelText: 'Selling Price (₹)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9822B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                final p = double.tryParse(priceCtrl.text) ?? 0.0;
                if (p > 0) {
                  final newItem = ProductItem(
                    id: 'itm_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Product $code',
                    barcode: code,
                    sellingPrice: p,
                    stock: 0.0,
                    type: ItemType.piece,
                    isPending: true,
                    imageUrl: meta['image'] ?? '',
                  );
                  widget.onProductAddOrUpdate(newItem);
                  setState(() {
                    _cart.add(CartItem(product: newItem, quantity: 1.0, customPrice: p));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('OK', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openLooseItemSelector() {
    final looseList = widget.inventory.where((p) => p.type == ItemType.loose).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Select Loose Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: looseList.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  final it = looseList[i];
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFF1EADB), child: Icon(Icons.scale, color: Color(0xFF7FA06B))),
                    title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Rate: ₹${it.sellingPrice}/kilo'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAddToCartDialog(it);
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

  void _finishBill(PaymentMethod method) {
    if (_cart.isEmpty) return;

    if (method == PaymentMethod.udhaar) {
      final phoneCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Customer Udhaar', style: TextStyle(color: Color(0xFFD9822B), fontWeight: FontWeight.bold)),
          content: TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Customer Mobile Number*', border: OutlineInputBorder()),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9822B), foregroundColor: Colors.white),
              onPressed: () {
                if (phoneCtrl.text.isNotEmpty) {
                  final sale = SaleRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    date: DateTime.now(),
                    items: List.from(_cart),
                    total: _totalBill,
                    profit: _cart.fold(0.0, (s, i) => s + i.profit),
                    method: PaymentMethod.udhaar,
                    customerPhone: phoneCtrl.text.trim(),
                    isPaid: false,
                  );
                  widget.onSaleSuccess(sale);
                  Navigator.pop(ctx);
                  _showBillReceipt(sale);
                }
              },
              child: const Text('Save Udhaar'),
            ),
          ],
        ),
      );
    } else {
      final sale = SaleRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        items: List.from(_cart),
        total: _totalBill,
        profit: _cart.fold(0.0, (s, i) => s + i.profit),
        method: method,
        isPaid: true,
      );
      widget.onSaleSuccess(sale);
      _showBillReceipt(sale);
    }
  }

  void _showBillReceipt(SaleRecord sale) {
    setState(() => _cart.clear());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 320,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
                    SizedBox(width: 8),
                    Text('Vanik POS', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(DateFormat('d/M hh:mm a').format(sale.date), style: const TextStyle(color: Colors.grey)),
                    const Divider(thickness: 1),
                    ...sale.items.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${i.product.name} x ${i.quantity} ${i.product.type == ItemType.loose ? "kg" : "pc"}')),
                          Text('₹${i.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                    const Divider(thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${sale.items.length} items', style: const TextStyle(color: Colors.grey)),
                        Text('₹${sale.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEFE8D8),
                        foregroundColor: const Color(0xFF4A6B35),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      onPressed: () {
                        final text = "Vanik Bill: Total ₹${sale.total.toStringAsFixed(0)} for ${sale.items.length} items. Thank you!";
                        launchUrl(Uri.parse("https://wa.me/?text=${Uri.encodeComponent(text)}"), mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.share, color: Colors.green),
                      label: const Text('Share on WhatsApp'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7FA06B),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('New Bill'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.flash_on : Icons.flash_off, color: Colors.black),
            onPressed: () => setState(() => _isScanning = !_isScanning),
          )
        ],
      ),
      body: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 220,
                child: MobileScanner(onDetect: _onDetect),
              ),
              Container(
                width: 250,
                height: 120,
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
                const Text('Bill', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF7FA06B))),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEFE8D8),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _openLooseItemSelector,
                  icon: const Icon(Icons.scale, size: 18),
                  label: const Text('Loose Item'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Scan items to prepare bill', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (ctx, i) {
                      final c = _cart[i];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            if (c.product.imageUrl.isNotEmpty)
                              ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(c.product.imageUrl, width: 36, height: 36, fit: BoxFit.cover))
                            else
                              const Icon(Icons.shopping_bag_outlined, color: Color(0xFF7FA06B)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${c.quantity} ${c.product.type == ItemType.loose ? "kg" : "pc"}', style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                            Text('₹${c.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.orange, size: 20),
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
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text('₹${_totalBill.toStringAsFixed(0)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7FA06B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _finishBill(PaymentMethod.online),
                        child: const Text('Online', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD9822B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _finishBill(PaymentMethod.cash),
                        child: const Text('Cash', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8DFC8),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _finishBill(PaymentMethod.udhaar),
                        child: const Text('Udhaar', style: TextStyle(fontWeight: FontWeight.bold)),
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

// ----------------- MY SHOP VIEW -----------------
class MyShopScreen extends StatefulWidget {
  final List<ProductItem> inventory;
  final Function(ProductItem) onProductUpdated;

  const MyShopScreen({super.key, required this.inventory, required this.onProductUpdated});

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen> {
  int _activeSubTab = 0; // 0: Shop items, 1: Pending

  void _openStockModal(ProductItem item) {
    final buyCtrl = TextEditingController(text: item.buyingPrice > 0 ? item.buyingPrice.toStringAsFixed(0) : '');
    final sellCtrl = TextEditingController(text: item.sellingPrice.toStringAsFixed(0));
    final stockCtrl = TextEditingController(text: item.stock.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: buyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Buying price of 1 Piece', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: sellCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Your selling price of 1 Piece (₹)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: stockCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Current pieces in shop', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7FA06B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
              ),
              onPressed: () {
                item.buyingPrice = double.tryParse(buyCtrl.text) ?? item.buyingPrice;
                item.sellingPrice = double.tryParse(sellCtrl.text) ?? item.sellingPrice;
                item.stock = double.tryParse(stockCtrl.text) ?? item.stock;
                item.isPending = false;
                widget.onProductUpdated(item);
                Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingItems = widget.inventory.where((p) => p.isPending).toList();
    final currentList = _activeSubTab == 0 ? widget.inventory : pendingItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Damodar mah...', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeSubTab == 0 ? const Color(0xFFE8DFC8) : Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                    ),
                    onPressed: () => setState(() => _activeSubTab = 0),
                    child: Text('Shop items: ${widget.inventory.length}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeSubTab == 1 ? const Color(0xFFD9822B) : Colors.white,
                      foregroundColor: _activeSubTab == 1 ? Colors.white : Colors.black,
                      elevation: 0,
                    ),
                    onPressed: () => setState(() => _activeSubTab = 1),
                    child: Text('Pending ${pendingItems.length}'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: currentList.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final it = currentList[i];
                return ListTile(
                  leading: it.imageUrl.isNotEmpty
                      ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(it.imageUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.fastfood)))
                      : const Icon(Icons.inventory_2, color: Color(0xFF7FA06B)),
                  title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('₹${it.sellingPrice} | Stock: ${it.stock} ${it.type == ItemType.loose ? "kg" : "pc"}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF7FA06B)),
                    onPressed: () => _openStockModal(it),
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

// ----------------- MY SALES VIEW -----------------
class MySalesScreen extends StatelessWidget {
  final List<SaleRecord> sales;
  final int pendingCount;
  final VoidCallback onPendingTabClicked;
  final Function(String, bool) onToggleUdhaarPaid;

  const MySalesScreen({
    super.key,
    required this.sales,
    required this.pendingCount,
    required this.onPendingTabClicked,
    required this.onToggleUdhaarPaid,
  });

  @override
  Widget build(BuildContext context) {
    final todaySales = sales.fold(0.0, (s, r) => s + r.total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Damodar mah...', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sales of day', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('₹${todaySales.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    if (pendingCount > 0) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onPendingTabClicked,
                        child: const Text('Clear Pending items to see profit. ➤', style: TextStyle(color: Color(0xFFD9822B), fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        height: 90,
                        width: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7FA06B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const Center(child: Text('Today', style: TextStyle(color: Colors.grey, fontSize: 12))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Bills of the day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sales.length,
                itemBuilder: (ctx, i) {
                  final s = sales[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('HH:mm').format(s.date), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: s.method == PaymentMethod.online ? Colors.green.shade50 : (s.method == PaymentMethod.cash ? Colors.orange.shade50 : Colors.red.shade50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.method == PaymentMethod.online ? 'Online' : (s.method == PaymentMethod.cash ? 'Cash' : 'Udhaar'),
                            style: TextStyle(color: s.method == PaymentMethod.online ? Colors.green : (s.method == PaymentMethod.cash ? Colors.orange : Colors.red)),
                          ),
                        ),
                        Text('${s.items.length} Items'),
                        Text('₹${s.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

  
