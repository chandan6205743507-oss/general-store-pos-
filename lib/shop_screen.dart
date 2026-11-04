import 'package:flutter/material.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final barcodeController = TextEditingController();
    final priceController = TextEditingController();
    final costController = TextEditingController();
    final stockController = TextEditingController();
    ItemType selectedType = ItemType.piece;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add New Product', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Item Name*', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: barcodeController,
                  decoration: const InputDecoration(labelText: 'Barcode (Optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Sell Price (₹)*', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: costController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cost Price (₹)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Initial Stock*', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Unit: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ChoiceChip(
                      label: const Text('Piece'),
                      selected: selectedType == ItemType.piece,
                      selectedColor: Colors.teal.shade100,
                      onSelected: (val) => setDialogState(() => selectedType = ItemType.piece),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Loose (Kg)'),
                      selected: selectedType == ItemType.loose,
                      selectedColor: Colors.teal.shade100,
                      onSelected: (val) => setDialogState(() => selectedType = ItemType.loose),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () {
                if (nameController.text.trim().isEmpty || priceController.text.trim().isEmpty) {
                  return;
                }
                final newProduct = ProductItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  barcode: barcodeController.text.trim(),
                  price: double.tryParse(priceController.text) ?? 0.0,
                  costPrice: double.tryParse(costController.text) ?? 0.0,
                  stock: double.tryParse(stockController.text) ?? 0.0,
                  type: selectedType,
                );
                widget.onAddProduct(newProduct);
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.inventory.where((item) {
      final q = _searchQuery.toLowerCase();
      return item.name.toLowerCase().contains(q) || item.barcode.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop & Inventory', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddProductDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search product or scan code...',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text('No products found', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final item = filteredList[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: Icon(
                            item.type == ItemType.loose ? Icons.scale : Icons.inventory_2,
                            color: Colors.teal,
                          ),
                        ),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Price: ₹${item.price} | Stock: ${item.type == ItemType.loose ? item.stock.toStringAsFixed(2) : item.stock.toInt()} ${item.type == ItemType.loose ? 'kg' : 'pcs'}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.teal),
                          onPressed: () {
                            final editStockCtrl = TextEditingController(text: item.stock.toString());
                            showDialog(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                title: Text('Update Stock: ${item.name}'),
                                content: TextField(
                                  controller: editStockCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'New Stock Quantity'),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                    onPressed: () {
                                      final val = double.tryParse(editStockCtrl.text) ?? item.stock;
                                      widget.onUpdateStock(item.id, val);
                                      Navigator.pop(dCtx);
                                      setState(() {});
                                    },
                                    child: const Text('Update', style: TextStyle(color: Colors.white)),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
