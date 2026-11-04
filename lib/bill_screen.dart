import 'package:flutter/material.dart';
import 'models.dart';
import 'receipt_view.dart';

class BillScreen extends StatefulWidget {
  final List<ProductItem> inventory;
  final Function(SaleRecord) onSaleCompleted;

  const BillScreen({
    super.key,
    required this.inventory,
    required this.onSaleCompleted,
  });

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final List<CartItem> _cart = [];
  final TextEditingController _codeController = TextEditingController();

  double get _cartTotal => _cart.fold(0, (sum, item) => sum + item.total);

  void _addToCart(ProductItem product, {double qty = 1.0}) {
    final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);
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

  void _handleBarcodeSubmit(String code) {
    if (code.trim().isEmpty) return;
    
    final matched = widget.inventory.where((p) => p.barcode == code.trim()).toList();
    if (matched.isNotEmpty) {
      final product = matched.first;
      if (product.type == ItemType.loose) {
        _showWeightDialog(product);
      } else {
        _addToCart(product, qty: 1.0);
      }
    } else {
      _showQuickItemDialog(code.trim());
    }
    _codeController.clear();
  }

  void _showWeightDialog(ProductItem product) {
    final weightController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Enter Weight for ${product.name}', style: const TextStyle(color: Colors.teal)),
        content: TextField(
          controller: weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Weight (in Kg)',
            hintText: 'e.g. 0.5 for 500g, 1.25 for 1.25kg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              final w = double.tryParse(weightController.text) ?? 0.0;
              if (w > 0) {
                _addToCart(product, qty: w);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  void _showQuickItemDialog(String unknownCode) {
    final nameCtrl = TextEditingController(text: 'Quick Item');
    final priceCtrl = TextEditingController();
    ItemType type = ItemType.piece;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Unknown Barcode / Quick Sell', style: TextStyle(color: Colors.teal)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Barcode: $unknownCode', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Price (₹)*', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Piece'),
                    selected: type == ItemType.piece,
                    selectedColor: Colors.teal.shade100,
                    onSelected: (val) => setDlgState(() => type = ItemType.piece),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Kg'),
                    selected: type == ItemType.loose,
                    selectedColor: Colors.teal.shade100,
                    onSelected: (val) => setDlgState(() => type = ItemType.loose),
                  ),
                ],
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
                  final tempProd = ProductItem(
                    id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim().isEmpty ? 'Quick Item' : nameCtrl.text.trim(),
                    barcode: unknownCode,
                    price: p,
                    stock: 999,
                    type: type,
                  );
                  _addToCart(tempProd, qty: 1.0);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add to Bill'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckoutDialog() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty! Add items first.')),
      );
      return;
    }

    final total = _cartTotal;
    PaymentMethod method = PaymentMethod.cash;
    final cashCtrl = TextEditingController(text: total.toStringAsFixed(0));
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final cashVal = double.tryParse(cashCtrl.text) ?? 0.0;
          final change = cashVal > total ? cashVal - total : 0.0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Checkout - ₹${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<PaymentMethod>(
                    segments: const [
                      ButtonSegment(value: PaymentMethod.cash, label: Text('Cash')),
                      ButtonSegment(value: PaymentMethod.online, label: Text('UPI')),
                      ButtonSegment(value: PaymentMethod.udhaar, label: Text('Udhaar')),
                    ],
                    selected: {method},
                    onSelectionChanged: (newVal) => setDlgState(() => method = newVal.first),
                  ),
                  const SizedBox(height: 16),
                  if (method == PaymentMethod.cash) ...[
                    TextField(
                      controller: cashCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cash Received (₹)', border: OutlineInputBorder()),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Change to return: ₹${change.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: change > 0 ? Colors.green : Colors.black)),
                    ),
                  ],
                  if (method == PaymentMethod.udhaar) ...[
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Customer Name*', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                    ),
                  ],
                  if (method == PaymentMethod.online) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Scan QR / Collect UPI Payment', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () {
                  if (method == PaymentMethod.udhaar && nameCtrl.text.trim().isEmpty) {
                    return;
                  }
                  final sale = SaleRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    dateTime: DateTime.now(),
                    items: List.from(_cart),
                    totalAmount: total,
                    paymentMethod: method,
                    cashReceived: method == PaymentMethod.cash ? cashVal : total,
                    changeReturned: method == PaymentMethod.cash ? change : 0.0,
                    customer: method == PaymentMethod.udhaar
                        ? CustomerDetails(name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim())
                        : null,
                  );

                  widget.onSaleCompleted(sale);
                  Navigator.pop(ctx);

                  showDialog(
                    context: context,
                    builder: (rCtx) => ReceiptViewDialog(
                      sale: sale,
                      onNewBill: () => setState(() => _cart.clear()),
                    ),
                  );
                },
                child: const Text('Confirm & Print'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('General Store POS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () => setState(() => _cart.clear()),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: 'Enter barcode or item code...',
                      prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.teal),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: _handleBarcodeSubmit,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onPressed: () => _handleBarcodeSubmit(_codeController.text),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Cart is empty\nEnter code or scan to begin', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final item = _cart[idx];
                      return ListTile(
                        title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '₹${item.customPrice} x ${item.product.type == ItemType.loose ? item.quantity.toStringAsFixed(2) : item.quantity.toInt()} ${item.product.type == ItemType.loose ? 'kg' : 'pcs'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹${item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  if (item.quantity > 1 && item.product.type == ItemType.piece) {
                                    item.quantity--;
                                  } else {
                                    _cart.removeAt(idx);
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Payable', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      '₹${_cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showCheckoutDialog,
                  icon: const Icon(Icons.payment),
                  label: const Text('Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
