import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'receipt_view.dart';

class SalesScreen extends StatelessWidget {
  final List<SaleRecord> sales;

  const SalesScreen({super.key, required this.sales});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    
    double totalRevenue = 0;
    double cashTotal = 0;
    double onlineTotal = 0;
    double udhaarTotal = 0;

    for (var sale in sales) {
      totalRevenue += sale.totalAmount;
      if (sale.paymentMethod == PaymentMethod.cash) {
        cashTotal += sale.totalAmount;
      } else if (sale.paymentMethod == PaymentMethod.online) {
        onlineTotal += sale.totalAmount;
      } else if (sale.paymentMethod == PaymentMethod.udhaar) {
        udhaarTotal += sale.totalAmount;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales & Ledger', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Daily Sales:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      '₹${totalRevenue.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryCard('Cash', '₹${cashTotal.toStringAsFixed(0)}', Colors.green),
                    _buildSummaryCard('Online', '₹${onlineTotal.toStringAsFixed(0)}', Colors.blue),
                    _buildSummaryCard('Udhaar', '₹${udhaarTotal.toStringAsFixed(0)}', Colors.red),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ),
          Expanded(
            child: sales.isEmpty
                ? const Center(child: Text('No sales recorded yet', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: sales.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final sale = sales[sales.length - 1 - idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: sale.paymentMethod == PaymentMethod.udhaar
                              ? Colors.red.shade50
                              : Colors.teal.shade50,
                          child: Icon(
                            sale.paymentMethod == PaymentMethod.cash
                                ? Icons.money
                                : sale.paymentMethod == PaymentMethod.online
                                    ? Icons.qr_code
                                    : Icons.book,
                            color: sale.paymentMethod == PaymentMethod.udhaar ? Colors.red : Colors.teal,
                          ),
                        ),
                        title: Text(
                          sale.paymentMethod == PaymentMethod.udhaar
                              ? 'Udhaar: ${sale.customer?.name ?? "Customer"}'
                              : 'Sale #${sale.id.substring(sale.id.length - 4)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${dateFormat.format(sale.dateTime)}\n${sale.items.length} item(s)',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          '₹${sale.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: sale.paymentMethod == PaymentMethod.udhaar ? Colors.red : Colors.teal,
                          ),
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (dCtx) => ReceiptViewDialog(
                              sale: sale,
                              onNewBill: () {},
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
