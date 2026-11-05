class ShopProfile {
  String shopName;
  String ownerMobile;
  String syncCode;

  ShopProfile({
    required this.shopName,
    required this.ownerMobile,
    required this.syncCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'shopName': shopName,
      'ownerMobile': ownerMobile,
      'syncCode': syncCode,
    };
  }

  factory ShopProfile.fromMap(Map<String, dynamic> map) {
    return ShopProfile(
      shopName: map['shopName'] ?? 'Meri Dukan',
      ownerMobile: map['ownerMobile'] ?? '',
      syncCode: map['syncCode'] ?? 'SHOP101',
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
  String? unit; // kg, gm, packet, piece
  String? imagePath;
  bool isPending;

  ProductItem({
    required this.id,
    required this.name,
    this.barcode,
    required this.buyPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    this.isLoose = false,
    this.unit = 'piece',
    this.imagePath,
    this.isPending = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'buyPrice': buyPrice,
      'sellingPrice': sellingPrice,
      'stockQuantity': stockQuantity,
      'isLoose': isLoose,
      'unit': unit,
      'imagePath': imagePath,
      'isPending': isPending,
    };
  }

  factory ProductItem.fromMap(Map<String, dynamic> map) {
    return ProductItem(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      buyPrice: (map['buyPrice'] as num).toDouble(),
      sellingPrice: (map['sellingPrice'] as num).toDouble(),
      stockQuantity: (map['stockQuantity'] as num).toDouble(),
      isLoose: map['isLoose'] ?? false,
      unit: map['unit'] ?? 'piece',
      imagePath: map['imagePath'],
      isPending: map['isPending'] ?? false,
    );
  }
}

class CartItem {
  final ProductItem product;
  double quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });

  double get totalAmount => product.sellingPrice * quantity;
  double get totalProfit => (product.sellingPrice - product.buyPrice) * quantity;
}

class UdharRecord {
  final String id;
  final String customerName;
  final String customerMobile;
  final double amount;
  final DateTime date;
  final List<String> itemSummary;
  bool isPaid;

  UdharRecord({
    required this.id,
    required this.customerName,
    required this.customerMobile,
    required this.amount,
    required this.date,
    required this.itemSummary,
    this.isPaid = false,
  });
}
