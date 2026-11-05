import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';

// ==========================================
// 1. MAKE BILL SCREEN (Vanik Camera + Cart)
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
  DateTime _lastDetect = DateTime.now();

  double get _totalBill => _cart.fold(0.0, (s, i) => s + i.total);

  void _onDetect(BarcodeCapture capture) {
    final now = DateTime.now();
    if (now.difference(_lastDetect).inMilliseconds < 1500) return;
    _lastDetect = now;

    for (final b in capture.barcodes) {
      if (b.rawValue != null && b.rawValue!.isNotEmpty) {
        _handleBarcode(b.rawValue!);
        break;
      }
    }
  }

  void _handleBarcode(String code) {
    final match = widget.inventory.where((p) => p.barcode == code).toList();
    if (match.isNotEmpty) {
      _showAddToCartSheet(match.first);
    } else {
      _showNewProductPrompt(code);
    }
  }

  void _showAddToCartSheet(ProductItem item) {
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
                child: Image.network(item.imageUrl, height: 70, width: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory, size: 50)),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: item.type == ItemType.loose ? 'Weight (in Kg)' : 'How many Pieces?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Price of 1 Unit (₹)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7FA06B),
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
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNewProductPrompt(String code) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Barcode: $code', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
            child: const Text('Add to Bill'),
          ),
        ],
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
          content: TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, autofocus: true, decoration: const InputDecoration(labelText: 'Customer Mobile Number', border: OutlineInputBorder())),
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
                  setState(() => _cart.clear());
                  Navigator.pop(ctx);
                  _showThermalReceipt(sale);
                }
              },
              child: const Text('Save Udhaar'),
            )
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
      );
      widget.onSaleSuccess(sale);
      setState(() => _cart.clear());
      _showThermalReceipt(sale);
    }
  }

  void _showThermalReceipt(SaleRecord sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long, color: Color(0xFF7FA06B)), SizedBox(width: 8), Text('Vanik Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
            const Divider(),
            ...sale.items.map((i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text('${i.product.name} x ${i.quantity}')),
                Text('₹${i.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            )),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${sale.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF7FA06B))),
            ]),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 40)),
              onPressed: () {
                final text = "Vanik Bill: Total ₹${sale.total.toStringAsFixed(0)} for ${sale.items.length} items.";
                launchUrl(Uri.parse("https://wa.me/?text=${Uri.encodeComponent(text)}"));
              },
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share on WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }

  void _openLooseItemPicker() {
    final looseList = widget.inventory.where((p) => p.type == ItemType.loose).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Select Loose Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: looseList.length,
                itemBuilder: (ctx, i) => ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFE8DFC8), child: Icon(Icons.scale, color: Color(0xFF7FA06B))),
                  title: Text(looseList[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Rate: ₹${looseList[i].sellingPrice}/kg | Stock: ${looseList[i].stock} kg'),
                  onTap: () {
                    Navigator.pop(c);
                    _showAddToCartSheet(looseList[i]);
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
                SizedBox(height: 180, child: MobileScanner(onDetect: _onDetect)),
                Container(width: 220, height: 100, decoration: BoxDecoration(border: Border.all(color: Colors.greenAccent, width: 2), borderRadius: BorderRadius.circular(12))),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bill', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF7FA06B))),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8DFC8), foregroundColor: Colors.black87),
                    onPressed: _openLooseItemPicker,
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
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total:', style: TextStyle(fontSize: 18)), Text('₹${_totalBill.toStringAsFixed(0)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7FA06B), foregroundColor: Colors.white), onPressed: () => _finishBill(PaymentMethod.online), child: const Text('Online'))),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9822B), foregroundColor: Colors.white), onPressed: () => _finishBill(PaymentMethod.cash), child: const Text('Cash'))),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8DFC8), foregroundColor: Colors.black87), onPressed: () => _finishBill(PaymentMethod.udhaar), child: const Text('Udhaar'))),
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
// 2. MY SHOP SCREEN (Stock, Edit, Loose Item)
// ==========================================
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
    final nameCtrl = TextEditingController(text: item.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Product Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: buyCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Buying price of 1 Unit (₹)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: sellCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Selling price of 1 Unit (₹)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: stockCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Current stock in shop', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7FA06B), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
            onPressed: () {
              item.name = nameCtrl.text.trim();
              item.buyingPrice = double.tryParse(buyCtrl.text) ?? item.buyingPrice;
              item.sellingPrice = double.tryParse(sellCtrl.text) ?? item.sellingPrice;
              item.stock = double.tryParse(stockCtrl.text) ?? item.stock;
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

  void _addNewLooseProduct() {
    final nameCtrl = TextEditingController();
    final buyCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final stockCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Loose Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name (e.g. Sugar, Chana Dal)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: buyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Buying price per kg (₹)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total stock (in kg)', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9822B), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
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
            child: const Text('Add Loose Item'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingItems = widget.inventory.where((p) => p.isPending).toList();
    final currentList = _activeSubTab == 0 ? widget.inventory : pendingItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shop & Stock', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFFD9822B), size: 28),
            tooltip: 'Add Loose Item',
            onPressed: _addNewLooseProduct,
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
                      backgroundColor: _activeSubTab == 0 ? const Color(0xFF7FA06B) : Colors.white,
                      foregroundColor: _activeSubTab == 0 ? Colors.white : Colors.black,
                    ),
                    onPressed: () => setState(() => _activeSubTab = 0),
                    child: Text('Shop items: ${widget.inventory.length}'),
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
                    child: Text('Pending: ${pendingItems.length}'),
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
                      ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(it.imageUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory, color: Color(0xFF7FA06B))))
                      : CircleAvatar(backgroundColor: const Color(0xFFE8DFC8), child: Icon(it.type == ItemType.loose ? Icons.scale : Icons.inventory_2, color: const Color(0xFF7FA06B))),
                  title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Sell: ₹${it.sellingPrice} | Stock: ${it.stock} ${it.type == ItemType.loose ? "kg" : "pc"}'),
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

// ==========================================
// 3. MY SALES SCREEN (Daily Profit & Udhaar)
// ==========================================
class MySalesScreen extends StatelessWidget {
  final List<SaleRecord> sales;
  final int pendingCount;
  final VoidCallback onPendingTabClicked;

  const MySalesScreen({
    super.key,
    required this.sales,
    required this.pendingCount,
    required this.onPendingTabClicked,
  });

  @override
  Widget build(BuildContext context) {
    final total = sales.fold(0.0, (s, r) => s + r.total);
    final profit = sales.fold(0.0, (s, r) => s + r.profit);

    return Scaffold(
      appBar: AppBar(title: const Text('My Sales & Udhaar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [const Text('Total Sale', style: TextStyle(color: Colors.grey)), Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF7FA06B)))]),
                Column(children: [const Text('Total Profit', style: TextStyle(color: Colors.grey)), Text('₹${profit.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD9822B)))]),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: sales.length,
              itemBuilder: (ctx, i) {
                final s = sales[i];
                return ListTile(
                  leading: Icon(s.method == PaymentMethod.online ? Icons.qr_code : (s.method == PaymentMethod.cash ? Icons.money : Icons.account_balance_wallet), color: const Color(0xFF7FA06B)),
                  title: Text('₹${s.total.toStringAsFixed(0)} (${s.method.name.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${DateFormat('hh:mm a').format(s.date)} ${s.customerPhone.isNotEmpty ? "| Phone: ${s.customerPhone}" : ""}'),
                  trailing: s.method == PaymentMethod.udhaar ? Chip(label: Text(s.isPaid ? 'PAID' : 'PENDING'), backgroundColor: s.isPaid ? Colors.green.shade100 : Colors.red.shade100) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
     
