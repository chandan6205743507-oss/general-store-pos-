import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'models.dart';
import 'receipt_view.dart';

class BillScreen extends StatefulWidget {
  final List<ProductItem> inventory;
  final Function(SaleRecord) onSaleCompleted;
  final Function(ProductItem) onQuickItemAdded;

  const BillScreen({
    super.key,
    required this.inventory,
    required this.onSaleCompleted,
    required this.onQuickItemAdded,
  });

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final List<CartItem> _cart = [];
  bool _isScannerActive = false;
  DateTime _lastScanTime = DateTime.now();

  double get _cartTotal => _cart.fold(0, (sum, item) => sum + item.total);

  void _onBarcodeDetected(BarcodeCapture capture) {
    final now = DateTime.now();
    if (now.difference(_lastScanTime).inMilliseconds < 1500) return;
    _lastScanTime = now;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        _handleBarcode(code);
        break;
      }
    }
  }

  void _handleBarcode(String code) {
    final matched = widget.inventory.where((p) => p.barcode == code).toList();
    if (matched.isNotEmpty) {
      final product = matched.first;
      if (product.type == ItemType.loose) {
        _showLooseWeightDialog(product);
      } else {
        _addToCart(product, qty: 1.0);
      }
    } else {
      _showNewItemPriceDialog(code);
    }
  }

  void _addToCart(ProductItem product, {double qty = 1.0}) {
    final existingIndex = _cart.indexWhere((item) => item.product.barcode == product.barcode);
    setState(() {
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity += qty;
      } else {
        _cart.add(CartItem(
          product: product,
          quantity: qty,
          customPrice: product.price,
        ));
      }
    });
  }

  void _showNewItemPriceDialog(String barcode) {
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Item Scanned', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: $barcode', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Enter Selling Price (₹)*',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              final p = double.tryParse(priceCtrl.text) ?? 0.0;
              if (p > 0) {
                final tempProduct = ProductItem(
                  id: 'item_${DateTime.now().millisecondsSinceEpoch}',
                  name: 'Product ($barcode)',
                  barcode: barcode,
                  price: p,
                  costPrice: 0.0,
                  stock: 0.0,
                  type: ItemType.piece,
                  isPending: true,
                );
                widget.onQuickItemAdded(tempProduct);
                _addToCart(tempProduct, qty: 1.0);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add to Bill'),
          ),
        ],
      ),
    );
  }

  void _showLooseWeightDialog(ProductItem product) {
    final qtyCtrl = TextEditingController(text: '1.0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(product.name, style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Weight (in Kg)',
            hintText: 'e.g. 0.5 for 500g, 1.5 for 1.5kg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              final w = double.tryParse(qtyCtrl.text) ?? 0.0;
              if (w > 0) {
                _addToCart(product, qty: w);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add to Bill'),
          ),
        ],
      ),
    );
  }

  void _showLooseItemsPicker() {
    final looseItems = widget.inventory.where((p) => p.type == ItemType.loose).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Loose Item (Kg)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
            const Divider(),
            Expanded(
              child: looseItems.isEmpty
                  ? const Center(child: Text('No loose items in shop. Add them from Shop tab.'))
                  : ListView.builder(
                      itemCount: looseItems.length,
                      itemBuilder: (c, i) => ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2F1), child: Icon(Icons.scale, color: Colors.teal)),
                        title: Text(looseItems[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Rate: ₹${looseItems[i].price}/kg'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showLooseWeightDialog(looseItems[i]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _completeBill({required PaymentMethod method}) {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty! Scan items first.')));
      return;
    }

    if (method == PaymentMethod.udhaar) {
      final nameCtrl = TextEditingController();
      final phoneCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Customer Udhaar Khata', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
              onPressed: () {
                if (phoneCtrl.text.trim().isEmpty) return;
                final sale = SaleRecord(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  dateTime: DateTime.now(),
                  items: List.from(_cart),
                  totalAmount: _cartTotal,
                  totalProfit: _cart.fold(0.0, (s, i) => s + i.profit),
                  paymentMethod: PaymentMethod.udhaar,
                  cashReceived: 0.0,
                  changeReturned: 0.0,
                  customer: CustomerDetails(
                    name: nameCtrl.text.trim().isEmpty ? 'Customer' : nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                  ),
                  isPaid: false,
                );
                widget.onSaleCompleted(sale);
                Navigator.pop(ctx);
                _openReceipt(sale);
              },
              child: const Text('Save to Udhaar'),
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
        cashReceived: _cartTotal,
        changeReturned: 0.0,
        isPaid: true,
      );
      widget.onSaleCompleted(sale);
      _openReceipt(sale);
    }
  }

  void _openReceipt(SaleRecord sale) {
    showDialog(
      context: context,
      builder: (ctx) => ReceiptViewDialog(
        sale: sale,
        onNewBill: () => setState(() => _cart.clear()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vanik POS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(_isScannerActive ? Icons.videocam_off : Icons.camera_alt, color: Colors.white),
            onPressed: () => setState(() => _isScannerActive = !_isScannerActive),
          ),
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: () => setState(() => _cart.clear()),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isScannerActive)
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(onDetect: _onBarcodeDetected),
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
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => setState(() => _isScannerActive = !_isScannerActive),
                    icon: Icon(_isScannerActive ? Icons.stop : Icons.qr_code_scanner),
                    label: Text(_isScannerActive ? 'Stop Scanner' : 'Make Bill / Scan'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showLooseItemsPicker,
                  icon: const Icon(Icons.scale),
                  label: const Text('Loose Items'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 70, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text('No items in bill yet\nTap "Make Bill / Scan" to scan items',
                            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = _cart[i];
                      return ListTile(
                        title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '₹${item.customPrice} x ${item.product.type == ItemType.loose ? item.quantity.toStringAsFixed(2) : item.quantity.toInt()} ${item.product.type == ItemType.loose ? 'kg' : 'pcs'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹${item.total.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  if (item.quantity > 1 && item.product.type == ItemType.piece) {
                                    item.quantity--;
                                  } else {
                                    _cart.removeAt(i);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Bill Amount', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text('₹${_cartTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _completeBill(method: PaymentMethod.cash),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Update (Cash)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _completeBill(method: PaymentMethod.udhaar),
                        icon: const Icon(Icons.book_outlined),
                        label: const Text('Udhaar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
