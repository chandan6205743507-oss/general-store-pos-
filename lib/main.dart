import 'package:flutter/material.dart';

void main() {
  runApp(const SimplePosApp());
}

class SimplePosApp extends StatelessWidget {
  const SimplePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'General Store POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF4F5F7),
        primaryColor: const Color(0xFFFF6B00),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class ProductItem {
  final String id;
  String name;
  String? barcode;
  double buyPrice;
  double sellingPrice;
  double stockQuantity;
  bool isLoose;
  String unit;

  ProductItem({
    required this.id,
    required this.name,
    this.barcode,
    required this.buyPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    this.isLoose = false,
    this.unit = 'piece',
  });
}

class CartItem {
  final ProductItem product;
  double qty;

  CartItem({required this.product, required this.qty});

  double get totalAmount => product.sellingPrice * qty;
}

class UdharEntry {
  final String id;
  final String customerName;
  final String customerMobile;
  final double amount;
  final DateTime date;
  bool isPaid;

  UdharEntry({
    required this.id,
    required this.customerName,
    required this.customerMobile,
    required this.amount,
    required this.date,
    this.isPaid = false,
  });
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentTabIndex = 0;
  String shopName = 'Mahato General Store';
  String shopMobile = '9876543210';
  String shopSyncCode = 'VNK-8842';

  final List<ProductItem> _inventory = [
    ProductItem(id: '1', name: 'Parle-G 50g', barcode: '890171910101', buyPrice: 4.2, sellingPrice: 5.0, stockQuantity: 48, isLoose: false, unit: 'pkt'),
    ProductItem(id: '2', name: 'Good Day Butter', barcode: '890106301201', buyPrice: 8.5, sellingPrice: 10.0, stockQuantity: 24, isLoose: false, unit: 'pkt'),
    ProductItem(id: '3', name: 'Arhar Daal', buyPrice: 130.0, sellingPrice: 155.0, stockQuantity: 50.0, isLoose: true, unit: 'kg'),
    ProductItem(id: '4', name: 'Cheeni (Sugar)', buyPrice: 40.0, sellingPrice: 46.0, stockQuantity: 100.0, isLoose: true, unit: 'kg'),
  ];

  final List<CartItem> _cart = [];
  final List<UdharEntry> _udharList = [
    UdharEntry(id: 'u1', customerName: 'Ramesh Kumar', customerMobile: '9876543210', amount: 350.0, date: DateTime.now().subtract(const Duration(days: 1))),
    UdharEntry(id: 'u2', customerName: 'Suresh Verma', customerMobile: '9123456780', amount: 120.0, date: DateTime.now()),
  ];

  double totalDailySales = 2450.0;
  String _searchQuery = '';

  void _showAddLooseItemDialog() {
    final nameCtrl = TextEditingController();
    final buyCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    String selectedUnit = 'kg';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        color: Colors.white,
        padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Naya Loose Item Jodein', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name (Daal, Cheeni etc.)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: buyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Khareed Rate (₹)', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: sellCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bikri Rate (₹)', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kul Stock', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedUnit,
                  items: const [
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                    DropdownMenuItem(value: 'gm', child: Text('gm')),
                    DropdownMenuItem(value: 'litre', child: Text('litre')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedUnit = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty) {
                    setState(() {
                      _inventory.add(ProductItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        buyPrice: double.tryParse(buyCtrl.text) ?? 0.0,
                        sellingPrice: double.tryParse(sellCtrl.text) ?? 0.0,
                        stockQuantity: double.tryParse(stockCtrl.text) ?? 0.0,
                        isLoose: true,
                        unit: selectedUnit,
                      ));
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save Stock', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShopSettings() {
    final nameCtrl = TextEditingController(text: shopName);
    final mobileCtrl = TextEditingController(text: shopMobile);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dukan Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Dukan Ka Naam')),
            const SizedBox(height: 8),
            TextField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile Number')),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Staff Sync Code', style: TextStyle(fontSize: 13, color: Colors.black54)),
              subtitle: Text(shopSyncCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF6B00))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
            onPressed: () {
              setState(() {
                shopName = nameCtrl.text;
                shopMobile = mobileCtrl.text;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _addToCart(ProductItem item, double qty) {
    setState(() {
      final index = _cart.indexWhere((c) => c.product.id == item.id);
      if (index >= 0) {
        _cart[index].qty += qty;
      } else {
        _cart.add(CartItem(product: item, qty: qty));
      }
    });
  }

  void _openCheckoutDialog() {
    double total = _cart.fold(0.0, (sum, i) => sum + i.totalAmount);
    final custNameCtrl = TextEditingController();
    final custPhoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kul Bill: ₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF6B00))),
            const SizedBox(height: 12),
            TextField(controller: custNameCtrl, decoration: const InputDecoration(labelText: 'Grahak Ka Naam', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: custPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () {
                      setState(() {
                        totalDailySales += total;
                        _cart.clear();
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Cash Paid', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () {
                      if (custNameCtrl.text.isNotEmpty) {
                        setState(() {
                          _udharList.add(UdharEntry(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            customerName: custNameCtrl.text,
                            customerMobile: custPhoneCtrl.text,
                            amount: total,
                            date: DateTime.now(),
                          ));
                          _cart.clear();
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Udhar Khata', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showShopSettings,
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFFFF6B00),
                      child: Icon(Icons.storefront, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shopName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Sync Code: $shopSyncCode', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: _showShopSettings,
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              child: Row(
                children: [
                  _navTabItem(0, 'Stock', Icons.inventory_2),
                  _navTabItem(1, 'Billing (${_cart.length})', Icons.receipt_long),
                  _navTabItem(2, 'Udhar Khata', Icons.menu_book),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  _buildInventoryTab(),
                  _buildBillingTab(),
                  _buildUdharTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFF6B00),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Loose Item', style: TextStyle(color: Colors.white)),
              onPressed: _showAddLooseItemDialog,
            )
          : null,
    );
  }

  Widget _navTabItem(int index, String title, IconData icon) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFFFF6B00) : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFFFF6B00) : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFFFF6B00) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryTab() {
    final list = _inventory.where((item) => item.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Saman khojein...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFFFF3EB),
                      child: Icon(item.isLoose ? Icons.scale : Icons.qr_code, color: const Color(0xFFFF6B00)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Stock: ${item.stockQuantity} ${item.unit} | Buy: ₹${item.buyPrice}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${item.sellingPrice}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFFF6B00))),
                        const SizedBox(height: 4),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(54, 26), padding: EdgeInsets.zero),
                          onPressed: () => _addToCart(item, 1.0),
                          child: const Text('Add', style: TextStyle(fontSize: 11)),
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
    );
  }

  Widget _buildBillingTab() {
    if (_cart.isEmpty) {
      return const Center(child: Text('Bill khali hai. Stock se saman jodein!'));
    }
    double total = _cart.fold(0.0, (sum, i) => sum + i.totalAmount);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: _cart.length,
            itemBuilder: (ctx, i) {
              final c = _cart[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('₹${c.product.sellingPrice} x ${c.qty} ${c.product.unit}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                    Row(
                      children: [
                        Text('₹${c.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => setState(() => _cart.removeAt(i)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Bill:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF6B00))),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
                  onPressed: _openCheckoutDialog,
                  child: const Text('Payment / Udhar Save', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

 Widget _buildUdharTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _udharList.length,
      itemBuilder: (ctx, i) {
        final u = _udharList[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              Icon(u.isPaid ? Icons.check_circle : Icons.error, color: u.isPaid ? Colors.green : Colors.red),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(u.customerMobile, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${u.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: u.isPaid ? Colors.green : Colors.red)),
                  const SizedBox(height: 4),
                  if (!u.isPaid)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(50, 24), padding: EdgeInsets.zero),
                      onPressed: () => setState(() => u.isPaid = true),
                      child: const Text('Paid', style: TextStyle(fontSize: 10, color: Colors.green)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
} 
