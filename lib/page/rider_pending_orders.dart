import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RiderPendingOrdersPage extends StatefulWidget {
  const RiderPendingOrdersPage({super.key});

  @override
  State<RiderPendingOrdersPage> createState() => _RiderPendingOrdersPageState();
}

class _RiderPendingOrdersPageState extends State<RiderPendingOrdersPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _acceptOrder(String orderId) async {
    final rider = _auth.currentUser;
    if (rider == null) return;

    setState(() => _isLoading = true);

    try {
      // ✅ ดึงข้อมูลไรเดอร์จาก Firestore
      final riderDoc = await _firestore.collection('riders').doc(rider.uid).get();
      final riderData = riderDoc.data() ?? {};

      // ✅ ใช้ Transaction เพื่อป้องกันการรับงานซ้ำ
      await _firestore.runTransaction((txn) async {
        final orderRef = _firestore.collection('deliveryRecords').doc(orderId);
        final orderSnap = await txn.get(orderRef);

        if (!orderSnap.exists) {
          throw Exception("ออเดอร์นี้ถูกลบไปแล้ว");
        }

        final orderData = orderSnap.data()!;
        if (orderData['status'] != 'รอไรเดอร์รับงาน') {
          throw Exception("ออเดอร์นี้ถูกคนอื่นรับไปแล้ว ❌");
        }

        // ✅ อัปเดตข้อมูล
        txn.update(orderRef, {
          'status': 'ไรเดอร์รับงาน',
          'riderId': rider.uid,
          'riderName': riderData['name'] ?? 'ไม่ระบุชื่อ',
          'riderPhone': riderData['phone'] ?? '-',
          'riderBike': riderData['plate'] ?? '-',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ รับงานเรียบร้อย")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('deliveryRecords')
          .where('status', isEqualTo: 'รอไรเดอร์รับงาน')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "ยังไม่มีออเดอร์ให้รับตอนนี้",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index].data() as Map<String, dynamic>;
            final orderId = orders[index].id;

            final pickupAddress = order['pickupAddress'] ?? '-';
            final dropAddress = order['dropAddress'] ?? '-';
            final price = order['price'] ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ออเดอร์ #$orderId",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.store, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "จุดรับสินค้า\n$pickupAddress",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "จุดส่งสินค้า\n$dropAddress",
                          style: const TextStyle(fontSize: 14),
                        ),
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
                      ElevatedButton(
                        onPressed: _isLoading ? null : () => _acceptOrder(orderId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "รับงาน",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
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
