import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

class LooseItemsScreen extends StatefulWidget {
  final List<ProductItem> looseItems;
  final Function(ProductItem) onAddItem;
  final Function(ProductItem, double) onAddToCart;

  const LooseItemsScreen({
    super.key,
    required this.looseItems,
    required this.onAddItem,
    required this.onAddToCart,
  });

  @override
  State<LooseItemsScreen> createState() => _LooseItemsScreenState();
}

class _LooseItemsScreenState extends State<LooseItemsScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  void _openAddLooseDialog() {
    final nameCtrl = TextEditingController();
    final buyCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    String unit = 'kg';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 18,
          right: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Khula Saman (Loose Item) Jodein',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softOrange,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_a_photo_outlined, color: AppColors.primaryOrange),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Saman ki photo chunne ka vikalp (Camera / Gallery)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Photo selector khul gaya hai')),
                      );
                    },
                    child: const Text('Chunein'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Item Ka Naam (e.g. Arhar Daal, Cheeni, Sarso Tel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: buyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Khareed Rate (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: sellCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Bikri Rate (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kul Quantity (Stock)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: unit,
                  items: const [
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                    DropdownMenuItem(value: 'gm', child: Text('gm')),
                    DropdownMenuItem(value: 'litre', child: Text('litre')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => unit = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty) {
                    final newItem = ProductItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text.trim(),
                      buyPrice: double.tryParse(buyCtrl.text) ?? 0.0,
                      sellingPrice: double.tryParse(sellCtrl.text) ?? 0.0,
                      stockQuantity: double.tryParse(stockCtrl.text) ?? 0.0,
                      isLoose: true,
                      unit: unit,
                    );
                    widget.onAddItem(newItem);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text(
                  'Loose Stock Save Karein',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
    final filtered = widget.looseItems
        .where((i) => i.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loose Saman (Khula Stock)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Daal, Cheeni, Tel khojein...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Koi loose item nahi mila. Naya item jodein!'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.softOrange,
                              child: const Icon(Icons.scale, color: AppColors.primaryOrange),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    'Stock: ${item.stockQuantity} ${item.unit} | Buy: ₹${item.buyPrice}',
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${item.sellingPrice}/${item.unit}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.primaryOrange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryOrange,
                                    minimumSize: const Size(60, 28),
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: () => widget.onAddToCart(item, 1.0),
                                  child: const Text(
                                    'Sell',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Loose Item', style: TextStyle(color: Colors.white)),
        onPressed: _openAddLooseDialog,
      ),
    );
  }
}
