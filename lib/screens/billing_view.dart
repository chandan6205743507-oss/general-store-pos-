import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

class BillingViewScreen extends StatelessWidget {
  final ShopProfile shopProfile;
  final List<CartItem> cartItems;
  final VoidCallback onClearCart;
  final Function(UdharRecord) onSaveAsUdhar;

  const BillingViewScreen({
    super.key,
    required this.shopProfile,
    required this.cartItems,
    required this.onClearCart,
    required this.onSaveAsUdhar,
  });

  double get totalBillAmount {
    return cartItems.fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  void _showUdharDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Udhar Khata Me Likhein'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Grahak Ka Naam',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final newUdhar = UdharRecord(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  customerName: nameCtrl.text.trim(),
                  customerMobile: phoneCtrl.text.trim(),
                  amount: totalBillAmount,
                  date: DateTime.now(),
                  itemSummary: cartItems.map((c) => '${c.product.name} (${c.quantity})').toList(),
                  isPaid: false,
                );
                onSaveAsUdhar(newUdhar);
                Navigator.pop(ctx);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bill udhar khata me darj ho gaya!')),
                );
              }
            },
            child: const Text('Save Udhar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Digital Bill Slip'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Printable Bill Receipt Slip
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      shopProfile.shopName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (shopProfile.ownerMobile.isNotEmpty)
                    Center(
                      child: Text(
                        'Mob: ${shopProfile.ownerMobile}',
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Tareekh: ${now.day}/${now.month}/${now.year}  |  ${now.hour}:${now.minute}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                  const Divider(height: 24, thickness: 1),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Saman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Qty / Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Rashi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const Divider(height: 16),
                  ...cartItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.product.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${item.quantity} ${item.product.unit} @ ₹${item.product.sellingPrice}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '₹${item.totalAmount.toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const Divider(height: 24, thickness: 1.2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kul Rashi (Net Total):',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${totalBillAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Bina Kisi GST Ke Seedha Hisaab\nShubh Aagman!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black38, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Share & Payment Actions
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text(
                  'WhatsApp Par Bill Bhejein',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('WhatsApp receipt share khul gaya!')),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        onClearCart();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nagar (Cash) payment poora hua!')),
                        );
                      },
                      child: const Text(
                        'Cash Mil Gaya',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB800),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showUdharDialog(context),
                      child: const Text(
                        'Udhar Me Dalein',
                        style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
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
