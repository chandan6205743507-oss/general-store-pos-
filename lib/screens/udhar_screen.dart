import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

class UdharScreen extends StatefulWidget {
  final List<UdharRecord> udharRecords;
  final Function(String) onMarkAsPaid;
  final Function(UdharRecord) onAddUdhar;

  const UdharScreen({
    super.key,
    required this.udharRecords,
    required this.onMarkAsPaid,
    required this.onAddUdhar,
  });

  @override
  State<UdharScreen> createState() => _UdharScreenState();
}

class _UdharScreenState extends State<UdharScreen> {
  String _filter = 'all'; // all, pending, paid
  final _searchController = TextEditingController();
  String _searchQuery = '';

  double get totalPendingUdhar {
    return widget.udharRecords
        .where((u) => !u.isPaid)
        .fold(0.0, (sum, u) => sum + u.amount);
  }

  void _showAddUdharDialog() {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final itemCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 18,
          right: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Naya Udhar (Khata Entry)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Grahak Ka Naam',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: mobileCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number (WhatsApp Reminder Ke Liye)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Baaki Rashi (₹)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: itemCtrl,
              decoration: const InputDecoration(
                labelText: 'Saman Ka Vivaran (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
                    final newUdhar = UdharRecord(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      customerName: nameCtrl.text.trim(),
                      customerMobile: mobileCtrl.text.trim(),
                      amount: double.tryParse(amountCtrl.text) ?? 0.0,
                      date: DateTime.now(),
                      itemSummary: itemCtrl.text.isNotEmpty ? [itemCtrl.text.trim()] : ['Dukan ka saman'],
                      isPaid: false,
                    );
                    widget.onAddUdhar(newUdhar);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text(
                  'Khata Me Jodein',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<UdharRecord> list = widget.udharRecords.where((u) {
      final matchesSearch = u.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.customerMobile.contains(_searchQuery);
      if (_filter == 'pending') return matchesSearch && !u.isPaid;
      if (_filter == 'paid') return matchesSearch && u.isPaid;
      return matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Udhar Khata Book'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Total Udhar Summary Card
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kul Baaki Udhar', style: TextStyle(color: Colors.black54, fontSize: 13)),
                    SizedBox(height: 4),
                    Text('Market Me Baaki', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Text(
                  '₹${totalPendingUdhar.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Grahak ka naam ya phone khojein...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Filter Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Sabhi'),
                selected: _filter == 'all',
                onSelected: (s) => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Baaki (Pending)'),
                selected: _filter == 'pending',
                onSelected: (s) => setState(() => _filter = 'pending'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Chuka Diya (Paid)'),
                selected: _filter == 'paid',
                onSelected: (s) => setState(() => _filter = 'paid'),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Udhar List
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Koi udhar record nahi hai.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final item = list[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: item.isPaid ? Colors.green.shade50 : Colors.red.shade50,
                              child: Icon(
                                item.isPaid ? Icons.check_circle_outline : Icons.pending_actions,
                                color: item.isPaid ? Colors.green : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.customerName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    item.customerMobile,
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                  ),
                                  Text(
                                    'Tareekh: ${item.date.day}/${item.date.month}/${item.date.year}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${item.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: item.isPaid ? Colors.green : Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (!item.isPaid)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      minimumSize: const Size(64, 28),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: () => widget.onMarkAsPaid(item.id),
                                    child: const Text('Paid', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  )
                                else
                                  const Text('Chukaya Hua', style: TextStyle(color: Colors.green, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryOrange,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('Naya Udhar', style: TextStyle(color: Colors.white)),
        onPressed: _showAddUdharDialog,
      ),
    );
  }
}
