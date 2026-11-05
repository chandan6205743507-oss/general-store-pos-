import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'models.dart';

// --- MAKE BILL SCREEN ---
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
      builder: (ctx) => AlertDialog(
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qtyCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: item.type == ItemType.loose ? 'Weight (Kg)' : 'Pieces')),
            TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Selling Price (₹)')),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7FA06B), foregroundColor: Colors.white),
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNewItemPrompt(String code) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New Barcode: $code', style: const TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name')),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price (₹)')),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9822B), foregroundColor: Colors.white),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vanik POS', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0),
      body: Column(
        children: [
          SizedBox(height: 200, child: MobileScanner(onDetect: _onDetect)),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Scan items to prepare bill'))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (ctx, i) => ListTile(
                      title: Text(_cart[i].product.name),
                      subtitle: Text('₹${_cart[i].customPrice} x ${_cart[i].quantity}'),
                      trailing: Text('₹${_cart[i].total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:', style: TextStyle(fontSize: 18)),
                    Text('₹${_totalBill.toStringAsFixed(0)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
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
    );
  }
}

// --- MY SHOP SCREEN ---
class MyShopScreen extends StatefulWidget {
  final List<ProductItem> inventory;
  final Function(ProductItem) onProductUpdated;
  const MyShopScreen({super.key, required this.inventory, required this.onProductUpdated});
  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final pending = widget.inventory.where((p) => p.isPending).toList();
    final list = _tab == 0 ? widget.inventory : pending;
    return Scaffold(
      appBar: AppBar(title: const Text('Shop & Stock', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(child: TextButton(onPressed: () => setState(() => _tab = 0), child: Text('Shop items: ${widget.inventory.length}'))),
              Expanded(child: TextButton(onPressed: () => setState(() => _tab = 1), child: Text('Pending: ${pending.length}'))),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(list[i].name),
                subtitle: Text('Sell: ₹${list[i].sellingPrice} | Stock: ${list[i].stock}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- MY SALES SCREEN ---
class MySalesScreen extends StatelessWidget {
  final List<SaleRecord> sales;
  final int pendingCount;
  final VoidCallback onPendingTabClicked;

  const MySalesScreen({super.key, required this.sales, required this.pendingCount, required this.onPendingTabClicked});

  @override
  Widget build(BuildContext context) {
    final total = sales.fold(0.0, (s, r) => s + r.total);
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Ledger', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Today Sale: ₹${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: sales.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text('₹${sales[i].total.toStringAsFixed(0)} - ${sales[i].method == PaymentMethod.udhaar ? "Udhaar" : "Cash"}'),
                subtitle: Text(DateFormat('hh:mm a').format(sales[i].date)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
