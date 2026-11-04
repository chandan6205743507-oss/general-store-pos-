import 'dart:convert';

enum ItemType { piece, loose }
enum PaymentMethod { cash, online, udhaar }

class ProductItem {
  final String id;
  String name;
  String barcode;
  double price;        // Grahak ko bechne ka rate (Selling Price)
  double costPrice;    // Khareed rate (Cost Price for Profit calculation)
  double stock;        // Dukan me bacha maal (Pcs ya Kg)
  ItemType type;
  bool isPending;      // Agar billing ke dauran quick add hua ho

  ProductItem({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.costPrice = 0.0,
    this.stock = 0.0,
    required this.type,
    this.isPending = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'barcode': barcode,
    'price': price,
    'costPrice': costPrice,
    'stock': stock,
    'type': type.index,
    'isPending': isPending,
  };

  factory ProductItem.fromMap(Map<String, dynamic> map) => ProductItem(
    id: map['id'],
    name: map['name'],
    barcode: map['barcode'],
    price: (map['price'] as num).toDouble(),
    costPrice: (map['costPrice'] as num).toDouble(),
    stock: (map['stock'] as num).toDouble(),
    type: ItemType.values[map['type'] ?? 0],
    isPending: map['isPending'] ?? false,
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
  double get profit => (customPrice - product.costPrice) * quantity;

  Map<String, dynamic> toMap() => {
    'product': product.toMap(),
    'quantity': quantity,
    'customPrice': customPrice,
  };

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
    product: ProductItem.fromMap(map['product']),
    quantity: (map['quantity'] as num).toDouble(),
    customPrice: (map['customPrice'] as num).toDouble(),
  );
}

class CustomerDetails {
  final String name;
  final String phone;

  CustomerDetails({required this.name, required this.phone});

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};
  factory CustomerDetails.fromMap(Map<String, dynamic> map) =>
      CustomerDetails(name: map['name'] ?? '', phone: map['phone'] ?? '');
}

class SaleRecord {
  final String id;
  final DateTime dateTime;
  final List<CartItem> items;
  final double totalAmount;
  final double totalProfit;
  final PaymentMethod paymentMethod;
  final double cashReceived;
  final double changeReturned;
  final CustomerDetails? customer;
  bool isPaid;

  SaleRecord({
    required this.id,
    required this.dateTime,
    required this.items,
    required this.totalAmount,
    required this.totalProfit,
    required this.paymentMethod,
    required this.cashReceived,
    required this.changeReturned,
    this.customer,
    this.isPaid = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'dateTime': dateTime.toIso8601String(),
    'items': items.map((x) => x.toMap()).toList(),
    'totalAmount': totalAmount,
    'totalProfit': totalProfit,
    'paymentMethod': paymentMethod.index,
    'cashReceived': cashReceived,
    'changeReturned': changeReturned,
    'customer': customer?.toMap(),
    'isPaid': isPaid,
  };

  factory SaleRecord.fromMap(Map<String, dynamic> map) => SaleRecord(
    id: map['id'],
    dateTime: DateTime.parse(map['dateTime']),
    items: (map['items'] as List).map((x) => CartItem.fromMap(x)).toList(),
    totalAmount: (map['totalAmount'] as num).toDouble(),
    totalProfit: (map['totalProfit'] as num?)?.toDouble() ?? 0.0,
    paymentMethod: PaymentMethod.values[map['paymentMethod'] ?? 0],
    cashReceived: (map['cashReceived'] as num).toDouble(),
    changeReturned: (map['changeReturned'] as num).toDouble(),
    customer: map['customer'] != null ? CustomerDetails.fromMap(map['customer']) : null,
    isPaid: map['isPaid'] ?? true,
  );
}
