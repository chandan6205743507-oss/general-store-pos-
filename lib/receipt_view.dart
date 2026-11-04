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
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final isUdhaar = sale.paymentMethod == PaymentMethod.udhaar;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFE0F2F1),
              child: Icon(Icons.check, size: 36, color: Colors.teal),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bill Saved Successfully',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(sale.dateTime),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Mode:'),
                      Text(
                        isUdhaar ? 'Udhaar Khata' : 'Cash',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isUdhaar ? Colors.orange.shade900 : Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  if (sale.customer != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Customer:'),
                        Text(
                          '${sale.customer!.name} (${sale.customer!.phone})',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Items:'),
                      Text('${sale.items.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bill Amount:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(
                        currencyFormat.format(sale.totalAmount),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bill text ready to share.')),
                      );
                    },
                    icon: const Icon(Icons.share, color: Colors.green),
                    label: const Text('Share Bill', style: TextStyle(color: Colors.green)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onNewBill();
                    },
                    child: const Text('New Bill'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
