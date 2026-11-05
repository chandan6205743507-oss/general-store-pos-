import 'package:flutter/material.dart';
import 'models/app_models.dart';
import 'theme/app_theme.dart';
import 'screens/loose_items_screen.dart';
import 'screens/udhar_screen.dart';
import 'screens/billing_view.dart';

void main() {
  runApp(const GeneralStoreApp());
}

class GeneralStoreApp extends StatelessWidget {
  const GeneralStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'General Store POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primaryOrange,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryOrange),
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
  int _currentTabIndex = 0;

  final ShopProfile _shopProfile = ShopProfile(
    shopName: 'Mahato General Store',
    ownerMobile: '9876543210',
    syncCode: 'VNK-8842',
  );

  final List<ProductItem> _inventory = [
    ProductItem(id: '1', name: 'Parle-G 50g', barcode: '890171910101', buyPrice: 4.2, sellingPrice: 5.0, stockQuantity: 48, isLoose: false, unit: 'pkt'),
    ProductItem(id: '2', name: 'Good Day Butter', barcode: '890106301201', buyPrice: 8.5, sellingPrice: 10.0, stockQuantity: 24, isLoose: false, unit: 'pkt'),
    ProductItem(id: '3', name: 'Arhar Daal', buyPrice: 130.0, sellingPrice: 155.0, stockQuantity: 50.0, isLoose: true, unit: 'kg'),
    ProductItem(id: '4', name: 'Cheeni (Sugar)', buyPrice: 40.0, sellingPrice: 46.0, stockQuantity: 100.0, isLoose: true, unit: 'kg'),
  ];

  final List<CartItem> _cart = [];
  final List<UdharRecord> _udharList = [
    UdharRecord(
      id: 'u1',
      customerName: 'Ramesh Kumar',
      customerMobile: '9876543210',
      amount: 350.0,
      date: DateTime.now().subtract(const Duration(days: 1)),
      itemSummary: ['Daal 2kg', 'Parle-G 2pkt'],
      isPaid: false,
    ),
    UdharRecord(
      id: 'u2',
      customerName: 'Suresh Verma',
      customerMobile: '9123456780',
      amount: 120.0,
      date: DateTime.now(),
      itemSummary: ['Cheeni 2kg'],
      isPaid: true,
    ),
  ];

  String _searchQuery = '';

  void _showShopSettings() {
    final nameCtrl = TextEditingController(text: _shopProfile.shopName);
    final mobileCtrl = TextEditingController(text: _shopProfile.ownerMobile);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dukan & Staff Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Dukan Ka Naam')),
            const SizedBox(height: 8),
            TextField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Owner Mobile Number')),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.softOrange, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Staff Joining / Sync Code:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_shopProfile.syncCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _shopProfile.syncCode = 'VNK-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                          });
                          Navigator.pop(ctx);
                          _showShopSettings();
                        },
                        child: const Text('New Code'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            onPressed: () {
              setState(() {
                _shopProfile.shopName = nameCtrl.text;
                _shopProfile.ownerMobile = mobileCtrl.text;
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
        _cart[index].quantity += qty;
      } else {
        _cart.add(CartItem(product: item, quantity: qty));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name} bill me joda gaya!'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showShopSettings,
                    child: const CircleAvatar(
                      backgroundColor: AppColors.primaryOrange,
                      child: Icon(Icons.storefront, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_shopProfile.shopName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Sync Code: ${_shopProfile.syncCode}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: _showShopSettings,
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: Colors.white,
              child: Row(
                children: [
                  _navTabItem(0, 'Stock', Icons.inventory_2_outlined),
                  _navTabItem(1, 'Billing (${_cart.length})', Icons.receipt_long),
                  _navTabItem(2, 'Udhar Khata', Icons.menu_book),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Tab Pages
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  _buildInventoryTab(),
                  _buildBillingTab(),
                  UdharScreen(
                    udharRecords: _udharList,
                    onMarkAsPaid: (id) {
                      setState(() {
                        final record = _udharList.firstWhere((u) => u.id == id);
                        record.isPaid = true;
                      });
                    },
                    onAddUdhar: (newRecord) {
                      setState(() {
                        _udharList.add(newRecord);
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primaryOrange,
              icon: const Icon(Icons.scale, color: Colors.white),
              label: const Text('Khula Saman Screen', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => LooseItemsScreen(
                      looseItems: _inventory.where((i) => i.isLoose).toList(),
                      onAddItem: (newItem) {
                        setState(() => _inventory.add(newItem));
                      },
                      onAddToCart: (item, qty) {
                        _addToCart(item, qty);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                );
              },
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
                color: isSelected ? AppColors.primaryOrange : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.primaryOrange : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primaryOrange : Colors.grey,
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
                      backgroundColor: AppColors.softOrange,
                      child: Icon(item.isLoose ? Icons.scale : Icons.qr_code, color: AppColors.primaryOrange),
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
                        Text('₹${item.sellingPrice}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryOrange)),
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
                        Text('₹${c.product.sellingPrice} x ${c.quantity} ${c.product.unit}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
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
                  Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => BillingViewScreen(
                          shopProfile: _shopProfile,
                          cartItems: _cart,
                          onClearCart: () => setState(() => _cart.clear()),
                          onSaveAsUdhar: (newUdhar) {
                            setState(() {
                              _udharList.add(newUdhar);
                              _cart.clear();
                            });
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Digital Bill Slip / Payment', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
