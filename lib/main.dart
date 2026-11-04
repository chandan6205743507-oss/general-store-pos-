import 'package:flutter/material.dart';
import 'models.dart';
import 'bill_screen.dart';
import 'shop_screen.dart';
import 'sales_screen.dart';

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
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Initial Sample Inventory
  final List<ProductItem> _inventory = [
    ProductItem(
      id: '1',
      name: 'Sugar (Chini)',
      barcode: '8901',
      price: 44.0,
      costPrice: 40.0,
      stock: 50.0,
      type: ItemType.loose,
    ),
    ProductItem(
      id: '2',
      name: 'Mustard Oil (Sarson Tel)',
      barcode: '8902',
      price: 150.0,
      costPrice: 135.0,
      stock: 30.0,
      type: ItemType.piece,
    ),
    ProductItem(
      id: '3',
      name: 'Atta (Flour)',
      barcode: '8903',
      price: 35.0,
      costPrice: 30.0,
      stock: 100.0,
      type: ItemType.loose,
    ),
    ProductItem(
      id: '4',
      name: 'Bathing Soap',
      barcode: '8904',
      price: 25.0,
      costPrice: 20.0,
      stock: 45.0,
      type: ItemType.piece,
    ),
  ];

  final List<SaleRecord> _sales = [];

  void _onSaleCompleted(SaleRecord sale) {
    setState(() {
      _sales.add(sale);
      // Reduce stock automatically
      for (var cartItem in sale.items) {
        final index = _inventory.indexWhere((p) => p.id == cartItem.product.id);
        if (index >= 0) {
          _inventory[index].stock -= cartItem.quantity;
          if (_inventory[index].stock < 0) {
            _inventory[index].stock = 0;
          }
        }
      }
    });
  }

  void _onAddProduct(ProductItem product) {
    setState(() {
      _inventory.add(product);
    });
  }

  void _onUpdateStock(String id, double newStock) {
    setState(() {
      final index = _inventory.indexWhere((p) => p.id == id);
      if (index >= 0) {
        _inventory[index].stock = newStock;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      BillScreen(
        inventory: _inventory,
        onSaleCompleted: _onSaleCompleted,
      ),
      ShopScreen(
        inventory: _inventory,
        onAddProduct: _onAddProduct,
        onUpdateStock: _onUpdateStock,
      ),
      SalesScreen(
        sales: _sales,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        indicatorColor: Colors.teal.shade100,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale, color: Colors.teal),
            label: 'Billing',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: Colors.teal),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Colors.teal),
            label: 'Sales Ledger',
          ),
        ],
      ),
    );
  }
}
