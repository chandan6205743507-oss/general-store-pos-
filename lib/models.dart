enum ItemType { piece, loose }
enum PaymentMethod { cash, online, udhaar }

class ProductItem {
  String id;
  String name;
  String barcode;
  double sellingPrice;
  double buyingPrice;
  double stock;
  ItemType type;
  bool isPending;
  String imageUrl;

  ProductItem({
    required this.id,
    required this.name,
    required this.barcode,
    required this.sellingPrice,
    this.buyingPrice = 0.0,
    this.stock = 0.0,
    required this.type,
    this.isPending = false,
    this.imageUrl = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'barcode': barcode,
    'sellingPrice': sellingPrice,
    'buyingPrice': buyingPrice,
    'stock': stock,
    'type': type.index,
    'isPending': isPending,
    'imageUrl': imageUrl,
  };

  factory ProductItem.fromMap(Map<String, dynamic> m) => ProductItem(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    barcode: m['barcode'] ?? '',
    sellingPrice: (m['sellingPrice'] as num?)?.toDouble() ?? 0.0,
    buyingPrice: (m['buyingPrice'] as num?)?.toDouble() ?? 0.0,
    stock: (m['stock'] as num?)?.toDouble() ?? 0.0,
    type: ItemType.values[m['type'] ?? 0],
    isPending: m['isPending'] ?? false,
    imageUrl: m['imageUrl'] ?? '',
  );
}

class CartItem {
  final ProductItem product;
  double quantity;
  double customPrice;

  CartItem({
    required this.product,
    required this.quantity,
    required this.customPrice,
  });

  double get total => customPrice * quantity;
  double get profit => (customPrice - product.buyingPrice) * quantity;

  Map<String, dynamic> toMap() => {
    'product': product.toMap(),
    'quantity': quantity,
    'customPrice': customPrice,
  };

  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
    product: ProductItem.fromMap(m['product']),
    quantity: (m['quantity'] as num?)?.toDouble() ?? 1.0,
    customPrice: (m['customPrice'] as num?)?.toDouble() ?? 0.0,
  );
}

class SaleRecord {
  String id;
  DateTime date;
  List<CartItem> items;
  double total;
  double profit;
  PaymentMethod method;
  String customerPhone;
  bool isPaid;

  SaleRecord({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
    required this.profit,
    required this.method,
    this.customerPhone = '',
    this.isPaid = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'items': items.map((x) => x.toMap()).toList(),
    'total': total,
    'profit': profit,
    'method': method.index,
    'customerPhone': customerPhone,
    'isPaid': isPaid,
  };

  factory SaleRecord.fromMap(Map<String, dynamic> m) => SaleRecord(
    id: m['id'] ?? '',
    date: DateTime.parse(m['date']),
    items: (m['items'] as List).map((x) => CartItem.fromMap(x)).toList(),
    total: (m['total'] as num?)?.toDouble() ?? 0.0,
    profit: (m['profit'] as num?)?.toDouble() ?? 0.0,
    method: PaymentMethod.values[m['method'] ?? 0],
    customerPhone: m['customerPhone'] ?? '',
    isPaid: m['isPaid'] ?? true,
  );
}
