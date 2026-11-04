import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    title: 'Vanik POS',
    debugShowCheckedModeBanner: false,
    home: VanikMainApp(),
  ));
}

enum ItemType { piece, loose }
enum PaymentMethod { cash, udhaar }

class ProductItem {
  String id, name, barcode, imageUrl;
  double price, costPrice, stock;
  ItemType type;
  bool isPending;

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

  factory ProductItem.fromMap(Map<String, dynamic> m) => ProductItem(
    id: m['id'],
    name: m['name'],
    barcode: m['barcode'],
    price: (m['price'] as num).toDouble(),
    costPrice: (m['costPrice'] as num).toDouble(),
    stock: (m['stock'] as num).toDouble(),
    type: ItemType.values[m['type'] ?? 0],
    isPending: m['isPending'] ?? false,
    imageUrl: m['imageUrl'] ?? '',
  );
}

class CartItem {
  final ProductItem product;
  double qty, price;
  CartItem({required this.product, required this.qty, required this.price});
  double get total => price * qty;
  double get profit => (price - product.costPrice) * qty;

  Map<String, dynamic> toMap() => {
    'product': product.toMap(),
    'qty': qty,
    'price': price,
  };
  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
    product: ProductItem.fromMap(m['product']),
    qty: (m['qty'] as num).toDouble(),
    price: (m['price'] as num).toDouble(),
  );
}

class SaleRecord {
  String id, phone, name;
  DateTime date;
  List<CartItem> items;
  double total, profit;
  PaymentMethod method;
  bool isPaid;

  SaleRecord({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
    required this.profit,
    required this.method,
    this.phone = '',
    this.name = '',
    this.isPaid = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'items': items.map((x) => x.toMap()).toList(),
    'total': total,
    'profit': profit,
    'method': method.index,
    'phone': phone,
    'name': name,
    'isPaid': isPaid,
  };

  factory SaleRecord.fromMap(Map<String, dynamic> m) => SaleRecord(
    id: m['id'],
    date: DateTime.parse(m['date']),
    items: (m['items'] as List).map((x) => CartItem.fromMap(x)).toList(),
    total: (m['total'] as num).toDouble(),
    profit: (m['profit'] as num).toDouble(),
    method: PaymentMethod.values[m['method'] ?? 0],
    phone: m['phone'] ?? '',
    name: m['name'] ?? '',
    isPaid: m['isPaid'] ?? true,
  );
}

class VanikMainApp extends StatefulWidget {
  const VanikMainApp({super.key});
  @override
  State<VanikMainApp> createState() => _VanikMainAppState();
}

class _VanikMainAppState extends State<VanikMainApp> {
  int _idx = 0;
  List<ProductItem> _items = [];
  List<SaleRecord> _sales = [];
  bool _load = true;
  final String _shopCode = 'VK-7842';

  @override
  void initState() {
    super.initState();
    _fetchStorage();
  }

  Future<void> _fetchStorage() async {
    final p = await SharedPreferences.getInstance();
    final sInv = p.getString('v_inv');
    final sSales = p.getString('v_sales');
    if (sInv != null) {
      _items = (jsonDecode(sInv) as List).map((e) => ProductItem.fromMap(e)).toList();
    } else {
      _items = [
        ProductItem(id: '1', name: 'Good Day Biscuit', barcode: '8901063012240', price: 10, costPrice: 8.5, stock: 20, type: ItemType.piece),
        ProductItem(id: '2', name: 'Sugar (Chini)', barcode: 'L_SUGAR', price: 44, costPrice: 38, stock: 50, type: ItemType.loose),
      ];
    }
    if (sSales != null) {
      _sales = (jsonDecode(sSales) as List).map((e) => SaleRecord.fromMap(e)).toList();
    }
    setState(() => _load = false);
  }

  Future<void> _sync() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('v_inv', jsonEncode(_items.map((e) => e.toMap()).toList()));
    await p.setString('v_sales', jsonEncode(_sales.map((e) => e.toMap()).toList()));
  }

  void _saveProduct(ProductItem item) {
    setState(() {
      final i = _items.indexWhere((x) => x.barcode == item.barcode);
      if (i >= 0) {
        _items[i] = item;
      } else {
        _items.insert(0, item);
      }
    });
    _sync();
  }

  void _addSale(SaleRecord s) {
    setState(() {
      _sales.insert(0, s);
      for (final it in s.items) {
        final i = _items.indexWhere((x) => x.barcode == it.product.barcode);
        if (i >= 0) {
          _items[i].stock -= it.qty;
          if (_items[i].stock < 0) _items[i].stock = 0;
        }
      }
    });
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    if (_load) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.teal)));
    }
    final tabs = [
      _BillingView(items: _items, onSale: _addSale, onQuickAdd: _saveProduct),
      _ShopView(items: _items, onSave: _saveProduct),
      _SalesView(sales: _sales, onStatus: (id, paid) {
        setState(() => _sales.firstWhere((x) => x.id == id).isPaid = paid);
        _sync();
      }),
      _SyncView(code: _shopCode),
    ];

    return Scaffold(
      body: tabs[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        indicatorColor: Colors.teal.shade100,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Billing'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Shop & Stock'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Sales Ledger'),
          NavigationDestination(icon: Icon(Icons.sync), label: 'Sync'),
        ],
      ),
    );
  }
}

class _BillingView extends StatefulWidget {
  final List<ProductItem> items;
  final Function(SaleRecord) onSale;
  final Function(ProductItem) onQuickAdd;
  const _BillingView({required this.items, required this.onSale, required this.onQuickAdd});
  @override
  State<_BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<_BillingView> {
  final List<CartItem> _cart = [];
  bool _cam = false;
  DateTime _last = DateTime.now();

  double get _total => _cart.fold(0, (s, i) => s + i.total);

  Future<void> _checkBarcode(String code) async {
    final m = widget.items.where((x) => x.barcode == code).toList();
    if (m.isNotEmpty) {
      if (m.first.type == ItemType.loose) {
        _looseDialog(m.first);
      } else {
        _addCart(m.first, 1);
      }
    } else {
      String autoName = '';
      try {
        final res = await http.get(Uri.parse('https://world.openfoodfacts.org/api/v0/product/$code.json')).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          autoName = jsonDecode(res.body)['product']?['product_name'] ?? '';
        }
      } catch (_) {}
      if (!mounted) return;
      final nameCtrl = TextEditingController(text: autoName);
      final priceCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('New Item Scanned', style: TextStyle(color: Colors.teal)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Barcode: $code'),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name*')),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price (₹)*')),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () {
                final p = double.tryParse(priceCtrl.text) ?? 0;
                final nm = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Item $code';
                if (p > 0) {
                  final newItem = ProductItem(id: 'i_${DateTime.now().millisecondsSinceEpoch}', name: nm, barcode: code, price: p, type: ItemType.piece, isPending: true);
                  widget.onQuickAdd(newItem);
                  _addCart(newItem, 1);
                  Navigator.pop(c);
                }
              },
              child: const Text('Add to Bill'),
            )
          ],
        ),
      );
    }
  }

  void _addCart(ProductItem p, double q) {
    setState(() {
      final i = _cart.indexWhere((x) => x.product.barcode == p.barcode);
      if (i >= 0) {
        _cart[i].qty += q;
      } else {
        _cart.add(CartItem(product: p, qty: q, price: p.price));
      }
    });
  }

  void _looseDialog(ProductItem item) {
    final qCtrl = TextEditingController(text: '1.0');
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(item.name, style: const TextStyle(color: Colors.teal)),
        content: TextField(controller: qCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (Kg)')),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              final w = double.tryParse(qCtrl.text) ?? 0;
              if (w > 0) {
                _addCart(item, w);
                Navigator.pop(c);
              }
            },
            child: const Text('Add to Bill'),
          )
        ],
      ),
    );
  }

  void _checkout(PaymentMethod m) {
    if (_cart.isEmpty) return;
    if (m == PaymentMethod.udhaar) {
      final pCtrl = TextEditingController();
      final nCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Udhaar Khata', style: TextStyle(color: Colors.orange)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: pCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Customer Mobile*')),
              TextField(controller: nCtrl, decoration: const InputDecoration(labelText: 'Name (Optional)')),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
              onPressed: () {
                if (pCtrl.text.isNotEmpty) {
                  final s = SaleRecord(
                    id: '${DateTime.now().millisecondsSinceEpoch}',
                    date: DateTime.now(),
                    items: List.from(_cart),
                    total: _total,
                    profit: _cart.fold(0, (a, b) => a + b.profit),
                    method: PaymentMethod.udhaar,
                    phone: pCtrl.text,
                    name: nCtrl.text,
                    isPaid: false,
                  );
                  widget.onSale(s);
                  setState(() => _cart.clear());
                  Navigator.pop(c);
                }
              },
              child: const Text('Save Udhaar'),
            )
          ],
        ),
      );
    } else {
      final s = SaleRecord(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        items: List.from(_cart),
        total: _total,
        profit: _cart.fold(0, (a, b) => a + b.profit),
        method: PaymentMethod.cash,
      );
      widget.onSale(s);
      setState(() => _cart.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vanik POS'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: Column(
        children: [
          if (_cam)
            SizedBox(
              height: 200,
              child: MobileScanner(onDetect: (c) {
                if (DateTime.now().difference(_last).inMilliseconds < 1500) return;
                _last = DateTime.now();
                for (final b in c.barcodes) {
                  if (b.rawValue != null) {
                    _checkBarcode(b.rawValue!);
                    break;
                  }
                }
              }),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    onPressed: () => setState(() => _cam = !_cam),
                    icon: Icon(_cam ? Icons.stop : Icons.qr_code_scanner),
                    label: Text(_cam ? 'Stop Scan' : 'Scan Barcode'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                  onPressed: () {
                    final loose = widget.items.where((x) => x.type == ItemType.loose).toList();
                    showModalBottomSheet(
                      context: context,
                      builder: (c) => ListView(
                        children: loose.map((i) => ListTile(
                          title: Text(i.name),
                          subtitle: Text('₹${i.price}/kg'),
                          onTap: () {
                            Navigator.pop(c);
                            _looseDialog(i);
                          },
                        )).toList(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.scale),
                  label: const Text('Loose'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Cart is empty. Scan items!'))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (c, i) => ListTile(
                      title: Text(_cart[i].product.name),
                      subtitle: Text('₹${_cart[i].price} x ${_cart[i].qty}'),
                      trailing: Text('₹${_cart[i].total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
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
                    const Text('Total:', style: TextStyle(fontSize: 18)),
                    Text('₹${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        onPressed: () => _checkout(PaymentMethod.cash),
                        child: const Text('Cash'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                        onPressed: () => _checkout(PaymentMethod.udhaar),
                        child: const Text('Udhaar'),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _ShopView extends StatelessWidget {
  final List<ProductItem> items;
  final Function(ProductItem) onSave;
  const _ShopView({required this.items, required this.onSave});

  void _edit(BuildContext ctx, ProductItem item) {
    final nC = TextEditingController(text: item.name);
    final pC = TextEditingController(text: '${item.price}');
    final cC = TextEditingController(text: '${item.costPrice}');
    final sC = TextEditingController(text: '${item.stock}');
    final iC = TextEditingController(text: item.imageUrl);
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Edit Product', style: TextStyle(color: Colors.teal)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nC, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: pC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price (₹)')),
              TextField(controller: cC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost Price (₹)')),
              TextField(controller: sC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock')),
              TextField(controller: iC, decoration: const InputDecoration(labelText: 'Image URL')),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              item.name = nC.text.trim();
              item.price = double.tryParse(pC.text) ?? item.price;
              item.costPrice = double.tryParse(cC.text) ?? item.costPrice;
              item.stock = double.tryParse(sC.text) ?? item.stock;
              item.imageUrl = iC.text.trim();
              item.isPending = false;
              onSave(item);
              Navigator.pop(c);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop & Stock'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) => ListTile(
          leading: items[i].imageUrl.isNotEmpty
              ? Image.network(items[i].imageUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.fastfood))
              : const Icon(Icons.inventory_2, color: Colors.teal),
          title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Sell: ₹${items[i].price} | Cost: ₹${items[i].costPrice} | Stock: ${items[i].stock}'),
          trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.teal), onPressed: () => _edit(context, items[i])),
        ),
      ),
    );
  }
}

class _SalesView extends StatelessWidget {
  final List<SaleRecord> sales;
  final Function(String, bool) onStatus;
  const _SalesView({required this.sales, required this.onStatus});

  @override
  Widget build(BuildContext context) {
    final tSale = sales.fold(0.0, (a, b) => a + b.total);
    final tProf = sales.fold(0.0, (a, b) => a + b.profit);
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Ledger'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  const Text('Total Sale', style: TextStyle(color: Colors.grey)),
                  Text('₹${tSale.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                ]),
                Column(children: [
                  const Text('Total Profit', style: TextStyle(color: Colors.grey)),
                  Text('₹${tProf.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                ]),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: sales.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text('₹${sales[i].total.toStringAsFixed(2)} (Profit: +₹${sales[i].profit.toStringAsFixed(2)})'),
                subtitle: Text('${DateFormat('hh:mm a, dd MMM').format(sales[i].date)} | ${sales[i].method == PaymentMethod.udhaar ? "Udhaar: ${sales[i].phone}" : "Cash"}'),
                trailing: sales[i].method == PaymentMethod.udhaar
                    ? TextButton(
                        onPressed: () => onStatus(sales[i].id, !sales[i].isPaid),
                        child: Text(sales[i].isPaid ? 'PAID' : 'PENDING', style: TextStyle(color: sales[i].isPaid ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                      )
                    : const Text('PAID', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _SyncView extends StatelessWidget {
  final String code;
  const _SyncView({required this.code});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dukan Sync Code'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code, size: 80, color: Colors.teal),
            const SizedBox(height: 12),
            Text('Shop Code: $code', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Dusre phone me sync karne ke liye yeh code use karein.', textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
