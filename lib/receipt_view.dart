import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class ReceiptViewDialog extends StatelessWidget {
  final SaleRecord sale;
  final VoidCallback onNewBill;

  const ReceiptViewDialog({
    super.key,
    required this.sale,
    required this.onNewBill,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.teal, size: 50),
                    const SizedBox(height: 8),
                    const Text(
                      'GENERAL STORE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const Text('Cash / Digital Receipt', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(sale.dateTime),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 1.5, height: 24),
              if (sale.customer != null) ...[
                Text('Customer: ${sale.customer!.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (sale.customer!.phone.isNotEmpty)
                  Text('Phone: ${sale.customer!.phone}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
              ],
              const Text('Items Purchased:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...sale.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.product.name} (x${item.product.type == ItemType.loose ? item.quantity.toStringAsFixed(2) : item.quantity.toInt()})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text('₹${item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '₹${sale.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Mode:'),
                  Text(
                    sale.paymentMethod.name.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: sale.paymentMethod == PaymentMethod.udhaar ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
              if (sale.paymentMethod == PaymentMethod.cash) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cash Received:'),
                    Text('₹${sale.cashReceived.toStringAsFixed(2)}'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Change Returned:'),
                    Text('₹${sale.changeReturned.toStringAsFixed(2)}'),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onNewBill();
                },
                icon: const Icon(Icons.add),
                label: const Text('Start New Bill'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
