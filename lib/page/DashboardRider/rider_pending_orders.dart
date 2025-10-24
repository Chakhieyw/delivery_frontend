import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RiderPendingOrdersPage extends StatefulWidget {
  const RiderPendingOrdersPage({super.key});

  @override
  State<RiderPendingOrdersPage> createState() => _RiderPendingOrdersPageState();
}

class _RiderPendingOrdersPageState extends State<RiderPendingOrdersPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final MapController _mapController = MapController();

  LatLng? _parseLatLng(String? raw) {
    if (raw == null || !raw.contains(",")) return null;
    try {
      final parts = raw.split(",");
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  // ✅ ดึง Download URL อัตโนมัติถ้าเป็น path
  Future<String?> _resolveImageUrl(dynamic rawValue) async {
    if (rawValue == null) return null;
    final value = rawValue.toString();

    // ถ้าเป็น URL แล้ว (https://...) ใช้ได้เลย
    if (value.startsWith("http")) return value;

    // ถ้าเป็น path เช่น "uploads/xxx.jpg" ดึงจาก Storage
    try {
      final ref = FirebaseStorage.instance.ref().child(value);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint("⚠️ ดึงรูปจาก path ไม่สำเร็จ: $e");
      return null;
    }
  }

  // ✅ ป้องกันการรับงานซ้ำ + ใช้ Transaction ป้องกันชนกัน
  Future<void> _acceptOrder(String orderId) async {
    final rider = _auth.currentUser;
    if (rider == null) return;

    try {
      // 🔸 1. ตรวจว่ามีงานค้างอยู่ไหม (กันรับงานซ้ำ)
      final currentJobs = await _firestore
          .collection('deliveryRecords')
          .where('riderId', isEqualTo: rider.uid)
          .where('status', whereIn: ['ไรเดอร์รับงาน', 'ไรเดอร์รับสินค้าแล้ว'])
          .limit(1)
          .get();

      if (currentJobs.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("⚠️ คุณมีงานที่ยังไม่เสร็จ กรุณาส่งงานเดิมก่อน")),
        );
        return;
      }

      // 🔸 2. ใช้ Transaction กันชน (Atomic Update)
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('deliveryRecords').doc(orderId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          throw Exception("ไม่พบออเดอร์นี้");
        }

        final data = snapshot.data() as Map<String, dynamic>;

        // ถ้ามีคนรับไปแล้ว หรือสถานะเปลี่ยนไปจาก "รอไรเดอร์รับงาน"
        if (data['riderId'] != null && data['riderId'] != '' ||
            data['status'] != 'รอไรเดอร์รับงาน') {
          throw Exception("ออเดอร์นี้ถูกผู้อื่นรับไปแล้ว");
        }

        transaction.update(docRef, {
          'riderId': rider.uid,
          'status': 'ไรเดอร์รับงาน',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ รับงานสำเร็จ")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ รับงานไม่สำเร็จ: $e")),
      );
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
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("ยังไม่มีงานที่รอรับ",
                style: TextStyle(color: Colors.grey)),
          );
        }

        final deliveries = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: deliveries.length,
          itemBuilder: (context, index) {
            final data = deliveries[index].data() as Map<String, dynamic>;
            final orderId = deliveries[index].id;

            final pickupAddress = data['pickupAddress'] ?? '-';
            final dropAddress = data['receiverAddress'] ?? '-';
            final price = data['price'] ?? 0;
            final pickupLatLng = _parseLatLng(data['pickupLatLng']);
            final dropLatLng = _parseLatLng(data['dropLatLng']);
            final pickupName = data['userName'] ?? 'ไม่ระบุชื่อผู้ส่ง';
            final pickupPhone = data['userPhone'] ?? '-';
            final dropName = data['receiverName'] ?? 'ไม่ระบุชื่อผู้รับ';
            final dropPhone = data['receiverPhone'] ?? '-';
            final rawImageValue = data['imageUrl'];

            return FutureBuilder<String?>(
              future: _resolveImageUrl(rawImageValue),
              builder: (context, imageSnapshot) {
                final productImageUrl = imageSnapshot.data;

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
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
                              color: Colors.green,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text("ผู้ส่ง: $pickupName ($pickupPhone)",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87)),
                      Text("ผู้รับ: $dropName ($dropPhone)",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87)),
                      const Divider(height: 18),

                      // ✅ แสดงรูปสินค้าจากผู้ส่ง (รองรับทั้ง URL และ path)
                      if (imageSnapshot.connectionState ==
                          ConnectionState.waiting)
                        const Center(
                            child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ))
                      else if (productImageUrl != null &&
                          productImageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            productImageUrl,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Text("ไม่สามารถโหลดรูปสินค้าได้")),
                          ),
                        )
                      else
                        const Center(
                            child: Text("ไม่มีรูปสินค้าจากผู้ส่ง",
                                style: TextStyle(color: Colors.grey))),

                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.store, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text("จุดรับสินค้า\n$pickupAddress")),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text("จุดส่งสินค้า\n$dropAddress")),
                        ],
                      ),
                      const Divider(height: 24),
                      if (pickupLatLng != null && dropLatLng != null)
                        SizedBox(
                          height: 200,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: pickupLatLng,
                              initialZoom: 13,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.kongphob.deliveryapp',
                              ),
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: [pickupLatLng, dropLatLng],
                                    strokeWidth: 4,
                                    color: Colors.green,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: pickupLatLng,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.store,
                                        color: Colors.green, size: 35),
                                  ),
                                  Marker(
                                    point: dropLatLng,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.location_on,
                                        color: Colors.red, size: 35),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () => _acceptOrder(orderId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("รับงาน",
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                      const SizedBox(height: 10),
                      Text("฿$price บาท",
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
