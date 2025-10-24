import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:delivery_frontend/page/rider_history_detail_page.dart';

class RiderHistoryPage extends StatefulWidget {
  const RiderHistoryPage({super.key});

  @override
  State<RiderHistoryPage> createState() => _RiderHistoryPageState();
}

class _RiderHistoryPageState extends State<RiderHistoryPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final date = ts.toDate();
    return "${date.day}/${date.month}/${date.year} "
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final rider = _auth.currentUser;
    if (rider == null) {
      return const Center(child: Text("กรุณาเข้าสู่ระบบอีกครั้ง"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('deliveryRecords')
          .where('riderId', isEqualTo: rider.uid)
          .where('status', isEqualTo: 'ไรเดอร์นำส่งสินค้าแล้ว')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "เกิดข้อผิดพลาด: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "ยังไม่มีประวัติการจัดส่ง",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        final records = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final data = records[index].data() as Map<String, dynamic>;
            final orderId = records[index].id;

            final pickupAddress = data['pickupAddress'] ?? '-';
            final dropAddress = data['dropAddress'] ?? '-';
            final price = data['price'] ?? 0;
            final updatedAt = data['updatedAt'] as Timestamp?;
            final createdAt = data['createdAt'] as Timestamp?;
            final displayDate = updatedAt ?? createdAt;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ออเดอร์ #$orderId",
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.store, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text("จุดรับสินค้า\n$pickupAddress"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text("จุดส่งสินค้า\n$dropAddress"),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Colors.grey),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "฿$price บาท",
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "จัดส่งเมื่อ: ${_formatDate(displayDate)}",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.green),
                      label: const Text("ดูรายละเอียด",
                          style: TextStyle(color: Colors.green)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RiderHistoryDetailPage(
                              data: data,
                              orderId: orderId,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
