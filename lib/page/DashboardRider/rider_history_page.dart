import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rider_history_detail_page.dart';

class RiderHistoryPage extends StatefulWidget {
  const RiderHistoryPage({super.key});

  @override
  State<RiderHistoryPage> createState() => _RiderHistoryPageState();
}

class _RiderHistoryPageState extends State<RiderHistoryPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> _fetchProofFallback(
      String orderId, Map<String, dynamic> data) async {
    // ถ้าไม่มีรูปใน history จะไปดึงจาก deliveryRecords แทน
    if ((data['pickupProofUrl'] == null || data['pickupProofUrl'] == '') ||
        (data['deliveryProofUrl'] == null || data['deliveryProofUrl'] == '')) {
      try {
        final doc =
            await _firestore.collection('deliveryRecords').doc(orderId).get();
        if (doc.exists) {
          final record = doc.data() ?? {};
          data['pickupProofUrl'] ??= record['pickupProofUrl'];
          data['deliveryProofUrl'] ??= record['deliveryProofUrl'];
        }
      } catch (e) {
        debugPrint("⚠️ ไม่สามารถดึงข้อมูลจาก deliveryRecords ได้: $e");
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final rider = _auth.currentUser;
    if (rider == null) {
      return const Center(child: Text("กรุณาเข้าสู่ระบบอีกครั้ง"));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("ประวัติการจัดส่ง"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('deliveryHistory')
            .where('riderId', isEqualTo: rider.uid)
            .where('status', isEqualTo: 'จัดส่งสำเร็จ')
            .orderBy('completedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text("ยังไม่มีประวัติการจัดส่งสำเร็จ",
                  style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final orderId = docs[index].id;
              final rawData = docs[index].data() as Map<String, dynamic>;
              return FutureBuilder<Map<String, dynamic>>(
                future: _fetchProofFallback(orderId, rawData),
                builder: (context, proofSnap) {
                  final data = proofSnap.data ?? rawData;
                  final receiverName = data['receiverName'] ?? 'ไม่ระบุผู้รับ';
                  final receiverPhone = data['receiverPhone'] ?? '-';
                  final pickupAddress = data['pickupAddress'] ?? '-';
                  final dropAddress = data['receiverAddress'] ?? '-';
                  final price = data['price'] ?? 0;
                  final completedAt =
                      (data['completedAt'] as Timestamp?)?.toDate();
                  final deliveryProofUrl = data['deliveryProofUrl'];
                  final pickupProofUrl = data['pickupProofUrl'];

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RiderHistoryDetailPage(
                            orderId: orderId,
                            data: data,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("ออเดอร์ #$orderId",
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("ผู้รับ: $receiverName ($receiverPhone)"),
                          Text("จาก: $pickupAddress"),
                          Text("ไปยัง: $dropAddress"),
                          const SizedBox(height: 8),
                          if (completedAt != null)
                            Text(
                              "ส่งสำเร็จเมื่อ: ${completedAt.day}/${completedAt.month}/${completedAt.year} ${completedAt.hour}:${completedAt.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("฿$price บาท",
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Row(
                                children: [
                                  if (pickupProofUrl != null &&
                                      pickupProofUrl != '')
                                    IconButton(
                                      icon: const Icon(Icons.image,
                                          color: Colors.orange),
                                      onPressed: () {
                                        _showImageDialog(context,
                                            pickupProofUrl, "รูปตอนรับสินค้า");
                                      },
                                    ),
                                  if (deliveryProofUrl != null &&
                                      deliveryProofUrl != '')
                                    IconButton(
                                      icon: const Icon(Icons.image,
                                          color: Colors.green),
                                      onPressed: () {
                                        _showImageDialog(
                                            context,
                                            deliveryProofUrl,
                                            "รูปตอนจัดส่งสำเร็จ");
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showImageDialog(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
            ),
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Image.network(url, fit: BoxFit.cover),
            ),
          ],
        ),
      ),
    );
  }
}
