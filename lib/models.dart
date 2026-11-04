enum ItemType { piece, loose }

enum PaymentMethod { cash, online, udhaar }

class ProductItem {
  final String id;
  String name;
  String barcode;
  double price;
  double costPrice;
  double stock;
  ItemType type;

  ProductItem({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.costPrice = 0.0,
    required this.stock,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'costPrice': costPrice,
      'stock': stock,
      'type': type.name,
    };
  }

  factory ProductItem.fromMap(Map<String, dynamic> map) {
    return ProductItem(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      price: (map['price'] as num).toDouble(),
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num).toDouble(),
      type: map['type'] == 'loose' ? ItemType.loose : ItemType.piece,
    );
  }
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

  double get total => quantity * customPrice;
}

class CustomerDetails {
  final String name;
  final String phone;
  final double oldDue;

  CustomerDetails({
    required this.name,
    required this.phone,
    this.oldDue = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'oldDue': oldDue,
    };
  }

  factory CustomerDetails.fromMap(Map<String, dynamic> map) {
    return CustomerDetails(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      oldDue: (map['oldDue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SaleRecord {
  final String id;
  final DateTime dateTime;
  final List<CartItem> items;
  final double totalAmount;
  final PaymentMethod paymentMethod;
  final CustomerDetails? customer;
  final double cashReceived;
  final double changeReturned;

  SaleRecord({
    required this.id,
    required this.dateTime,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    this.customer,
    this.cashReceived = 0.0,
    this.changeReturned = 0.0,
  });
}
