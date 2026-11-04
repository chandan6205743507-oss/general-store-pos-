import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VanikPosApp());
}

enum ItemType { piece, loose }
enum PaymentMethod { cash, online, udhaar }

class ProductItem {
  final String id;
  String name;
  String barcode;
  double price;
  double costPrice;
  double stock;
  ItemType type;
  bool isPending;
  String imageUrl;

  ProductItem({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.costPrice = 0.0,
    this.stock = 0.0,
    required this.type,
    this.isPending = false,
    this.imageUrl = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'barcode': barcode,
    'price': price,
    'costPrice': costPrice,
    'stock': stock,
    'type': type.index,
    'isPending': isPending,
    'imageUrl': imageUrl,
  };

  factory ProductItem.fromMap(Map<String, dynamic> map) => ProductItem(
    id: map['id'],
    name: map['name'],
    barcode: map['barcode'],
    price: (map['price'] as num).toDouble(),
    costPrice: (map['costPrice'] as num).toDouble(),
    stock: (map['stock'] as num).toDouble(),
    type: ItemType.values[map['type'] ?? 0],
    isPending: map['isPending'] ?? false,
    imageUrl: map['imageUrl'] ?? '',
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

  double get total => customPrice * quantity;
  double get profit => (customPrice - product.costPrice) * quantity;

  Map<String, dynamic> toMap() => {
    'product': product.toMap(),
    'quantity': quantity,
    'customPrice': customPrice,
  };

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
    product: ProductItem.fromMap(map['product']),
    quantity: (map['quantity'] as num).toDouble(),
    customPrice: (map['customPrice'] as num).toDouble(),
  );
}

class SaleRecord {
  final String id;
  final DateTime dateTime;
  final List<CartItem> items;
  final double totalAmount;
  final double totalProfit;
  final PaymentMethod paymentMethod;
  final String customerPhone;
  final String customerName;
  bool isPaid;

  SaleRecord({
    required this.id,
    required this.dateTime,
    required this.items,
    required this.totalAmount,
    required this.totalProfit,
    required this.paymentMethod,
    this.customerPhone = '',
    this.customerName = '',
    this.isPaid = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'dateTime': dateTime.toIso8601String(),
    'items': items.map((x) => x.toMap()).toList(),
    'totalAmount': totalAmount,
    'totalProfit': totalProfit,
    'paymentMethod': paymentMethod.index,
    'customerPhone': customerPhone,
    'customerName': customerName,
    'isPaid': isPaid,
  };

  factory SaleRecord.fromMap(Map<String, dynamic> map) => SaleRecord(
    id: map['id'],
    dateTime: DateTime.parse(map['dateTime']),
    items: (map['items'] as List).map((x) => CartItem.fromMap(x)).toList(),
    totalAmount: (map['totalAmount'] as num).toDouble(),
    totalProfit: (map['totalProfit'] as num?)?.toDouble() ?? 0.0,
    paymentMethod: PaymentMethod.values[map['paymentMethod'] ?? 0],
    customerPhone: map['customerPhone'] ?? '',
    customerName: map['customerName'] ?? '',
    isPaid: map['isPaid'] ?? true,
  );
}

class VanikPosApp extends StatelessWidget {
  const VanikPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vanik POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _tabIndex = 0;
  List<ProductItem> _inventory = [];
  List<SaleRecord> _sales = [];
  bool _isLoading = true;
  String _shopCode = 'VK-7842';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final invData = prefs.getString('vanik_inventory');
    final salesData = prefs.getString('vanik_sales');
    _shopCode = prefs.getString('vanik_shop_code') ?? 'VK-7842';

    if (invData != null) {
      final List dec = jsonDecode(invData);
      _inventory = dec.map((e) => ProductItem.fromMap(e)).toList();
    } else {
      _inventory = [
        ProductItem(
          id: '1',
          name: 'Good Day Biscuit',
          barcode: '8901063012240',
          price: 10.0,
          costPrice: 8.5,
          stock: 24.0,
          type: ItemType.piece,
        ),
        ProductItem(
          id: '2',
          name: 'Sugar (Chini)',
          barcode: 'L_SUGAR',
          price: 44.0,
          costPrice: 38.0,
          stock: 50.0,
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
    await prefs.setString('vanik_inventory', jsonEncode(_inventory.map((e) => e.toMap()).toList()));
    await prefs.setString('vanik_sales', jsonEncode(_sales.map((e) => e.toMap()).toList()));
  }

  void _addOrUpdateProduct(ProductItem item) {
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

  void _completeSale(SaleRecord sale) {
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
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.teal)));
    }

    final pages = [
      BillingTabView(
        inventory: _inventory,
        onSaleCompleted: _completeSale,
        onQuickAdd: _addOrUpdateProduct,
      ),
      ShopTabView(
        inventory: _inventory,
        onSaveProduct: _addOrUpdateProduct,
      ),
      SalesLedgerTabView(
        sales: _sales,
        onTogglePaid: (id, paid) {
          setState(() {
            final s = _sales.firstWhere((x) => x.id == id);
            s.isPaid = paid;
          });
          _saveData();
        },
      ),
      ProfileTabView(shopCode: _shopCode),
    ];

    return Scaffold(
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        indicatorColor: Colors.teal.shade100,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Billing'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Shop & Stock'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Sales Ledger'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile & Sync'),
        ],
      ),
    );
  }
}

class BillingTabView extends StatefulWidget {
  final List<ProductItem> inventory;
  final Function(SaleRecord) onSaleCompleted;
  final Function(ProductItem) onQuickAdd;

  const BillingTabView({
    super.key,
    required this.inventory,
    required this.onSaleCompleted,
    required this.onQuickAdd,
  });

  @override
  State<BillingTabView> createState() => _BillingTabViewState();
}

class _BillingTabViewState extends State<BillingTabView> {
  final List<CartItem> _cart = [];
  bool _scannerActive = false;
  DateTime _lastDetect = DateTime.now();

  double get _cartTotal => _cart.fold(0, (sum, i) => sum + i.total);

  Future> _fetchOnlineInfo(String barcode) async {
    try {
      final res = await http.get(Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json')).timeout(const Duration(seconds: 3));
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
    if (now.difference(_lastDetect).inMilliseconds < 1500) return;
    _lastDetect = now;

    for (final b in capture.barcodes) {
      final code = b.rawValue;
      if (code != null && code.isNotEmpty) {
        _handleBarcode(code);
        break;
      }
    }
  }

  void _handleBarcode(String code) {
    final match = widget.inventory.where((p) => p.barcode == code).toList();
    if (match.isNotEmpty) {
      final item = match.first;
      if (item.type == ItemType.loose) {
        _promptLooseQty(item);
      } else {
        _addToCart(item, 1.0);
      }
    } else {
      _promptNewItem(code);
    }
  }

  void _addToCart(ProductItem p, double qty) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.barcode == p.barcode);
      if (idx >= 0) {
        _cart[idx].quantity += qty;
      } else {
        _cart.add(CartItem(product: p, quantity: qty, customPrice: p.price));
      }
    });
  }

  void _promptNewItem(String barcode) async {
    final online = await _fetchOnlineInfo(barcode);
    if (!mounted) return;

    final nameCtrl = TextEditingController(text: online['name']!.isNotEmpty ? online['name'] : '');
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('New Item Scanned', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Barcode: $barcode', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Item Name*', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Selling Price (₹)*', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              final price = double.tryParse(priceCtrl.text) ?? 0.0;
              final name = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Item $barcode';
              if (price > 0) {
                final newItem = ProductItem(
                  id: 'item_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  barcode: barcode,
                  price: price,
                  stock: 0,
                  type: ItemType.piece,
                  isPending: true,
                  imageUrl: online['image'] ?? '',
                );
                widget.onQuickAdd(newItem);
                _addToCart(newItem, 1.0);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add to Bill'),
          ),
        ],
      ),
    );
  }

  void _promptLooseQty(ProductItem item) {
    final qtyCtrl = TextEditingController(text: '1.0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.name, style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weight in Kg (e.g. 0.5, 1.5)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              final q = double.tryParse(qtyCtrl.text) ?? 0.0;
              if (q > 0) {
                _addToCart(item, q);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add to Bill'),
          ),
        ],
      ),
    );
  }

  void _checkout({required PaymentMethod method}) {
    if (_cart.isEmpty) return;

    if (method == PaymentMethod.udhaar) {
      final phoneCtrl = TextEditingController();
      final nameCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Customer Udhaar Khata', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Mobile Number*', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
              onPressed: () {
                if (phoneCtrl.text.trim().isEmpty) return;
                final sale = SaleRecord(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  dateTime: DateTime.now(),
                  items: List.from(_cart),
                  totalAmount: _cartTotal,
                  totalProfit: _cart.fold(0.0, (s, i) => s + i.profit),
                  paymentMethod: PaymentMethod.udhaar,
                  customerPhone: phoneCtrl.text.trim(),
                  customerName: nameCtrl.text.trim().isEmpty ? 'Customer' : nameCtrl.text.trim(),
                  isPaid: false,
                );
                widget.onSaleCompleted(sale);
                Navigator.pop(ctx);
                _showBillSuccess(sale);
              },
              child: const Text('Save Udhaar'),
            ),
          ],
        ),
      );
    } else {
      final sale = SaleRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        dateTime: DateTime.now(),
        items: List.from(_cart),
        totalAmount: _cartTotal,
        totalProfit: _cart.fold(0.0, (s, i) => s + i.profit),
        paymentMethod: PaymentMethod.cash,
        isPaid: true,
      );
      widget.onSaleCompleted(sale);
      _showBillSuccess(sale);
    }
  }

  void _showBillSuccess(SaleRecord sale) {
    setState(() => _cart.clear());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bill Generated! 🎉', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Amount: ₹${sale.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            Text('Profit Earned: ₹${sale.totalProfit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Payment: ${sale.paymentMethod == PaymentMethod.udhaar ? "Udhaar (${sale.customerPhone})" : "Cash"}'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Next Bill'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final looseItems = widget.inventory.where((p) => p.type == ItemType.loose).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vanik POS', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_scannerActive ? Icons.videocam_off : Icons.camera_alt),
            onPressed: () => setState(() => _scannerActive = !_scannerActive),
          ),
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => setState(() => _cart.clear()),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_scannerActive)
            SizedBox(
              height: 200,
              child: MobileScanner(onDetect: _onDetect),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => setState(() => _scannerActive = !_scannerActive),
                    icon: Icon(_scannerActive ? Icons.stop : Icons.qr_code_scanner),
                    label: Text(_scannerActive ? 'Stop Scanner' : 'Make Bill / Scan'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => ListView(
                        children: looseItems.map((item) => ListTile(
                          leading: const Icon(Icons.scale, color: Colors.teal),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Rate: ₹${item.price}/kg'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _promptLooseQty(item);
                          },
                        )).toList(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.scale),
                  label: const Text('Loose Items'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('No items in bill yet\nTap "Make Bill / Scan" to scan items', textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (ctx, i) {
                      final c = _cart[i];
                      return ListTile(
                        leading: c.product.imageUrl.isNotEmpty
                            ? Image.network(c.product.imageUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.fastfood))
                            : const Icon(Icons.inventory_2, color: Colors.teal),
                        title: Text(c.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('₹${c.customPrice} x ${c.quantity} ${c.product.type == ItemType.loose ? "kg" : "pcs"}'),
                        trailing: Text('₹${c.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Bill Amount', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text('₹${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () => _checkout(method: PaymentMethod.cash),
                        child: const Text('Update (Cash)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () => _checkout(method: PaymentMethod.udhaar),
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

class ShopTabView extends StatefulWidget {
  final List<ProductItem> inventory;
  final Function(ProductItem) onSaveProduct;

  const ShopTabView({super.key, required this.inventory, required this.onSaveProduct});

  @override
  State<ShopTabView> createState() => _ShopTabViewState();
}

class _ShopTabViewState extends State<ShopTabView> {
  String _query = '';

  void _openEditDialog(ProductItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final sellCtrl = TextEditingController(text: item.price.toString());
    final costCtrl = TextEditingController(text: item.costPrice > 0 ? item.costPrice.toString() : '');
    final stockCtrl = TextEditingController(text: item.stock.toString());
    final imgCtrl = TextEditingController(text: item.imageUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Product Details', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name*', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: sellCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Selling Price (₹)*', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: costCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cost / Khareed Rate (₹)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: stockCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Stock (${item.type == ItemType.loose ? "Kg" : "Pcs"})', border: const OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: 'Photo Link / Image URL', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) item.name = nameCtrl.text.trim();
              item.price = double.tryParse(sellCtrl.text) ?? item.price;
              item.costPrice = double.tryParse(costCtrl.text) ?? item.costPrice;
              item.stock = double.tryParse(stockCtrl.text) ?? item.stock;
              item.imageUrl = imgCtrl.text.trim();
              item.isPending = false;
              widget.onSaveProduct(item);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.inventory.where((p) => p.name.toLowerCase().contains(_query.toLowerCase()) || p.barcode.contains(_query)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Shop & Stock', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search items by name or barcode...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final item = filtered[i];
                return ListTile(
                  leading: item.imageUrl.isNotEmpty
                      ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(item.imageUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: Colors.teal)))
                      : CircleAvatar(backgroundColor: Colors.teal.shade50, child: Icon(item.type == ItemType.loose ? Icons.scale : Icons.inventory_2, color: Colors.teal)),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Sell: ₹${item.price} | Cost: ₹${item.costPrice} | Stock: ${item.stock} ${item.type == ItemType.loose ? "kg" : "pcs"}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.teal),
                    onPressed: () => _edit(context, item),
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

class SalesLedgerTabView extends StatelessWidget {
  final List<SaleRecord> sales;
  final Function(String, bool) onTogglePaid;

  const SalesLedgerTabView({super.key, required this.sales, required this.onTogglePaid});

  @override
  Widget build(BuildContext context) {
    final totalSales = sales.fold(0.0, (s, r) => s + r.totalAmount);
    final totalProfit = sales.fold(0.0, (s, r) => s + r.totalProfit);

    return Scaffold(
      appBar: AppBar(title: const Text('My Sales & Profit', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  const Text('Total Daily Sales', style: TextStyle(color: Colors.grey)),
                  Text('₹${totalSales.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
                ]),
                Column(children: [
                  const Text('Total Profit', style: TextStyle(color: Colors.grey)),
                  Text('₹${totalProfit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                ]),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sales.isEmpty
                ? const Center(child: Text('No sales recorded yet'))
                : ListView.builder(
                    itemCount: sales.length,
                    itemBuilder: (ctx, i) {
                      final s = sales[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: s.paymentMethod == PaymentMethod.udhaar ? Colors.orange.shade100 : Colors.teal.shade100,
                          child: Icon(s.paymentMethod == PaymentMethod.udhaar ? Icons.book : Icons.check, color: s.paymentMethod == PaymentMethod.udhaar ? Colors.orange : Colors.teal),
                        ),
                        title: Text('₹${s.totalAmount.toStringAsFixed(2)}  (Profit: +₹${s.totalProfit.toStringAsFixed(2)})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${DateFormat('hh:mm a, dd MMM').format(s.dateTime)} | ${s.paymentMethod == PaymentMethod.udhaar ? "Udhaar: ${s.customerPhone}" : "Cash"}'),
                        trailing: s.paymentMethod == PaymentMethod.udhaar
                            ? TextButton(
                                onPressed: () => onTogglePaid(s.id, !s.isPaid),
                                child: Text(s.isPaid ? 'PAID' : 'PENDING', style: TextStyle(color: s.isPaid ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                              )
                            : const Text('PAID', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ProfileTabView extends StatelessWidget {
  final String shopCode;

  const ProfileTabView({super.key, required this.shopCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Shop Sync', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.store, color: Colors.white)),
                title: const Text('Dukan Setup & Join Code', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Multi-staff connection code: $shopCode'),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Multi-User Phone Sync:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Dusre phone ya staff ke phone me "Join a Shop" select karke ye code daalne par dukan ka stock aapas me link ho jayega.',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop sync code copied!')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Shop Code'),
            ),
          ],
        ),
      ),
    );
  }
}
