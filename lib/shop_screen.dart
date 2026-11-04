import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'models.dart';

class ShopScreen extends StatefulWidget {
  final List<ProductItem> inventory;
  final Function(ProductItem) onAddProduct;
  final Function(String, double) onUpdateStock;

  const ShopScreen({
    super.key,
    required this.inventory,
    required this.onAddProduct,
    required this.onUpdateStock,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _searchQuery = '';
  bool _isScannerOpen = false;

  List<ProductItem> get _pendingItems =>
      widget.inventory.where((p) => p.isPending).toList();

  List<ProductItem> get _filteredProducts {
    final list = widget.inventory.where((p) => !p.isPending).toList();
    if (_searchQuery.trim().isEmpty) return list;
    return list
        .where((p) =>
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.barcode.contains(_searchQuery))
        .toList();
  }

  void _showAddBarcodeItemDialog({String scannedCode = ''}) {
    final nameCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController(text: scannedCode);
    final totalCostCtrl = TextEditingController();
    final totalQtyCtrl = TextEditingController();
    final sellPriceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Stock Barcode Item',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name (e.g. Good Day)*', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: barcodeCtrl,
                decoration: const InputDecoration(labelText: 'Barcode Number*', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: totalCostCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Total Bill Amount to Distributor (₹)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: totalQtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Pieces Bought', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sellPriceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Selling Price per Piece (₹)*', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final barcode = barcodeCtrl.text.trim();
              final sellPrice = double.tryParse(sellPriceCtrl.text) ?? 0.0;
              final totalCost = double.tryParse(totalCostCtrl.text) ?? 0.0;
              final qty = double.tryParse(totalQtyCtrl.text) ?? 0.0;

              if (name.isNotEmpty && barcode.isNotEmpty && sellPrice > 0) {
                final costPerPiece = (qty > 0 && totalCost > 0) ? (totalCost / qty) : 0.0;
                widget.onAddProduct(ProductItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  barcode: barcode,
                  price: sellPrice,
                  costPrice: costPerPiece,
                  stock: qty,
                  type: ItemType.piece,
                  isPending: false,
                ));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add to Stock'),
          ),
        ],
      ),
    );
  }

  void _showAddLooseItemDialog() {
    final nameCtrl = TextEditingController();
    final totalCostCtrl = TextEditingController();
    final totalKgCtrl = TextEditingController();
    final sellPricePerKgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Stock Loose Item (Kg)',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Product Name (e.g. Chini/Dal)*', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: totalCostCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Total Cost Paid (₹)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: totalKgCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Total Weight Bought (Kg)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sellPricePerKgCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Selling Price per Kg (₹)*', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final sellPrice = double.tryParse(sellPricePerKgCtrl.text) ?? 0.0;
              final totalCost = double.tryParse(totalCostCtrl.text) ?? 0.0;
              final kg = double.tryParse(totalKgCtrl.text) ?? 0.0;

              if (name.isNotEmpty && sellPrice > 0) {
                final costPerKg = (kg > 0 && totalCost > 0) ? (totalCost / kg) : 0.0;
                widget.onAddProduct(ProductItem(
                  id: 'loose_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  barcode: 'L_${DateTime.now().millisecondsSinceEpoch}',
                  price: sellPrice,
                  costPrice: costPerKg,
                  stock: kg,
                  type: ItemType.loose,
                  isPending: false,
                ));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add to Stock'),
          ),
        ],
      ),
    );
  }

  void _showResolvePendingDialog(ProductItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final costCtrl = TextEditingController(text: item.costPrice > 0 ? item.costPrice.toString() : '');
    final stockCtrl = TextEditingController(text: item.stock > 0 ? item.stock.toString() : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Complete Product Details', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
              controller: costCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Purchase / Cost Price (₹)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: stockCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Total Stock Available (Pcs/Kg)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                item.name = nameCtrl.text.trim().isEmpty ? item.name : nameCtrl.text.trim();
                item.costPrice = double.tryParse(costCtrl.text) ?? 0.0;
                item.stock = double.tryParse(stockCtrl.text) ?? 0.0;
                item.isPending = false;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save to Stock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop & Stock', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          if (_isScannerOpen)
            SizedBox(
              height: 200,
              child: MobileScanner(
                onDetect: (capture) {
                  for (final b in capture.barcodes) {
                    if (b.rawValue != null && b.rawValue!.isNotEmpty) {
                      setState(() => _isScannerOpen = false);
                      _showAddBarcodeItemDialog(scannedCode: b.rawValue!);
                      break;
                    }
                  }
                },
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.teal.shade50,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => setState(() => _isScannerOpen = !_isScannerOpen),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Stock Barcode Items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showAddLooseItemDialog,
                    icon: const Icon(Icons.scale),
                    label: const Text('Stock Loose Items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          if (_pendingItems.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red),
                      const SizedBox(width: 6),
                      Text('Pending Items (${_pendingItems.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Complete cost & stock for items added during quick bill:', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  ..._pendingItems.map((item) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Sell Price: ₹${item.price} | Barcode: ${item.barcode}'),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                          onPressed: () => _showResolvePendingDialog(item),
                          child: const Text('Complete'),
                        ),
                      )),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search items by name or barcode...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(child: Text('No items in shop list.'))
                : ListView.separated(
                    itemCount: _filteredProducts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = _filteredProducts[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.type == ItemType.loose ? Colors.teal.shade100 : Colors.blue.shade100,
                          child: Icon(item.type == ItemType.loose ? Icons.scale : Icons.inventory_2, color: Colors.teal),
                        ),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Sell: ₹${item.price} | Cost: ₹${item.costPrice.toStringAsFixed(1)} | Stock: ${item.stock} ${item.type == ItemType.loose ? 'kg' : 'pcs'}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.teal),
                          onPressed: () {
                            final editPriceCtrl = TextEditingController(text: item.price.toString());
                            final editStockCtrl = TextEditingController(text: item.stock.toString());
                            showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Text('Edit ${item.name}'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(controller: editPriceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Selling Price (₹)', border: OutlineInputBorder())),
                                    const SizedBox(height: 10),
                                    TextField(controller: editStockCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Stock (Qty/Kg)', border: OutlineInputBorder())),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        item.price = double.tryParse(editPriceCtrl.text) ?? item.price;
                                        item.stock = double.tryParse(editStockCtrl.text) ?? item.stock;
                                      });
                                      Navigator.pop(c);
                                    },
                                    child: const Text('Update'),
                                  ),
                                ],
                              ),
                            );
                          },
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
