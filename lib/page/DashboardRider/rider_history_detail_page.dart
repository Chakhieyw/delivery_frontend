import 'package:flutter/material.dart';

class RiderHistoryDetailPage extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;

  const RiderHistoryDetailPage({
    super.key,
    required this.orderId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final userName = data['userName'] ?? '-';
    final receiverName = data['receiverName'] ?? '-';
    final pickupAddress = data['pickupAddress'] ?? '-';
    final dropAddress = data['receiverAddress'] ?? '-';
    final price = data['price'] ?? 0;
    final pickupProofUrl = data['pickupProofUrl'];
    final deliveryProofUrl = data['deliveryProofUrl'];
    final completedAt = data['completedAt']?.toDate();

    return Scaffold(
      appBar: AppBar(
        title: Text("รายละเอียดออเดอร์ #$orderId"),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ผู้ส่ง: $userName"),
            Text("ผู้รับ: $receiverName"),
            const SizedBox(height: 8),
            Text("ที่อยู่รับของ: $pickupAddress"),
            Text("ที่อยู่ส่งของ: $dropAddress"),
            const Divider(height: 24),
            Text("ราคา: ฿$price",
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (completedAt != null)
              Text("จัดส่งเมื่อ: ${completedAt.toString().split('.')[0]}"),
            const Divider(height: 24),
            const Text("หลักฐานการรับของ:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (pickupProofUrl != null && pickupProofUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(pickupProofUrl, fit: BoxFit.cover),
                ),
              )
            else
              const Text("ไม่มีรูปหลักฐานการรับของ"),
            const SizedBox(height: 16),
            const Text("หลักฐานการส่งของ:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (deliveryProofUrl != null && deliveryProofUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(deliveryProofUrl, fit: BoxFit.cover),
                ),
              )
            else
              const Text("ไม่มีรูปหลักฐานการส่งของ"),
          ],
        ),
      ),
    );
  }
}
