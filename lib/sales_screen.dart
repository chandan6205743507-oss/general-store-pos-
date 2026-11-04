import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class SalesScreen extends StatefulWidget {
  final List<SaleRecord> salesHistory;
  final Function(String) onMarkPaid;

  const SalesScreen({
    super.key,
    required this.salesHistory,
    required this.onMarkPaid,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  double get _totalSales =>
      widget.salesHistory.fold(0.0, (sum, item) => sum + item.totalAmount);

  double get _totalProfit =>
      widget.salesHistory.fold(0.0, (sum, item) => sum + item.totalProfit);

  double get _cashSales => widget.salesHistory
      .where((s) => s.paymentMethod == PaymentMethod.cash)
      .fold(0.0, (sum, item) => sum + item.totalAmount);

  double get _onlineSales => widget.salesHistory
      .where((s) => s.paymentMethod == PaymentMethod.online)
      .fold(0.0, (sum, item) => sum + item.totalAmount);

  double get _udhaarSales => widget.salesHistory
      .where((s) => s.paymentMethod == PaymentMethod.udhaar && !s.isPaid)
      .fold(0.0, (sum, item) => sum + item.totalAmount);

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Sales & Profit',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              border: Border(bottom: BorderSide(color: Colors.teal.shade100)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Daily Sales',
                            style: TextStyle(fontSize: 14, color: Colors.black54)),
                        Text(currencyFormat.format(_totalSales),
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total Profit',
                            style: TextStyle(fontSize: 14, color: Colors.black54)),
                        Text(currencyFormat.format(_totalProfit),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard('Cash', _cashSales, Colors.green),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard('Online', _onlineSales, Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard('Udhaar', _udhaarSales, Colors.orange),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('All Orders & Khata',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: widget.salesHistory.isEmpty
                ? const Center(
                    child: Text('No transactions recorded yet.',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: widget.salesHistory.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final sale = widget.salesHistory[i];
                      final isUdhaarPending =
                          sale.paymentMethod == PaymentMethod.udhaar && !sale.isPaid;

                      return Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isUdhaarPending
                                ? Colors.orange.shade300
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('hh:mm a, dd MMM').format(sale.dateTime),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isUdhaarPending
                                          ? Colors.orange.shade100
                                          : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isUdhaarPending
                                          ? 'Udhaar (Pending)'
                                          : (sale.paymentMethod == PaymentMethod.udhaar
                                              ? 'Udhaar (Paid)'
                                              : sale.paymentMethod.name.toUpperCase()),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isUdhaarPending
                                            ? Colors.orange.shade900
                                            : Colors.green.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    currencyFormat.format(sale.totalAmount),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal),
                                  ),
                                  Text(
                                    'Profit: +₹${sale.totalProfit.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              if (sale.customer != null) ...[
                                const Divider(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Customer: ${sale.customer!.name} (${sale.customer!.phone})',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                    if (isUdhaarPending)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 0),
                                          minimumSize: const Size(60, 28),
                                        ),
                                        onPressed: () => widget.onMarkPaid(sale.id),
                                        child: const Text('Mark Paid', style: TextStyle(fontSize: 11)),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
