import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ReceiverShipmentsListPage extends StatefulWidget {
  final Function(String orderId)? onTrackPressed;
  const ReceiverShipmentsListPage({super.key, this.onTrackPressed});

  @override
  State<ReceiverShipmentsListPage> createState() =>
      _ReceiverShipmentsListPageState();
}

class _ReceiverShipmentsListPageState extends State<ReceiverShipmentsListPage> {
  bool showMap = false;
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final receiver = _auth.currentUser;
    if (receiver == null) {
      return const Center(child: Text("กรุณาเข้าสู่ระบบใหม่อีกครั้ง"));
    }

    final stream = FirebaseFirestore.instance
        .collection('deliveryRecords')
        .where('receiverId', isEqualTo: receiver.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("📦 สินค้าที่จะได้รับ"),
        actions: [
          IconButton(
            icon:
                Icon(showMap ? Icons.list_alt : Icons.map, color: Colors.white),
            tooltip: showMap ? "แสดงรายการทั้งหมด" : "ดูแผนที่รวม",
            onPressed: () => setState(() => showMap = !showMap),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "ยังไม่มีสินค้าที่จะได้รับในขณะนี้",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // ✅ แสดงแผนที่รวมทั้งหมด (3.1.4–3.1.5)
          if (showMap) {
            return StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('riders').snapshots(),
              builder: (context, riderSnap) {
                final List<Marker> markers = [];
                final List<Polyline> polylines = [];
                final List<LatLng> allPoints = [];

                for (var d in docs) {
                  final data = d.data() as Map<String, dynamic>;
                  final pickup = _parseLatLng(data['pickupLatLng']);
                  final drop = _parseLatLng(data['dropLatLng']);
                  final sender = data['userName'] ?? '-';
                  final status = data['status'] ?? '-';
                  final riderId = data['riderId'];

                  if (pickup != null && drop != null) {
                    allPoints.addAll([pickup, drop]);
                    polylines.add(Polyline(
                      points: [pickup, drop],
                      strokeWidth: 4,
                      color: Colors.green.withOpacity(0.5),
                    ));

                    // จุดรับ
                    markers.add(Marker(
                      width: 40,
                      height: 40,
                      point: pickup,
                      child: GestureDetector(
                        onTap: () => _showShipmentInfo(sender, status),
                        child: const Icon(Icons.store,
                            color: Colors.green, size: 32),
                      ),
                    ));

                    // จุดส่ง
                    markers.add(Marker(
                      width: 40,
                      height: 40,
                      point: drop,
                      child: GestureDetector(
                        onTap: () => _showShipmentInfo(sender, status),
                        child: const Icon(Icons.location_on,
                            color: Colors.red, size: 34),
                      ),
                    ));
                  }

                  // ✅ แสดงตำแหน่งไรเดอร์แบบ real-time ถ้ามี riderId
                  if (riderSnap.hasData && riderId != null && riderId != '') {
                    final riders = riderSnap.data!.docs;
                    final riderDoc =
                        riders.where((r) => r.id == riderId).isEmpty
                            ? null
                            : riders.firstWhere((r) => r.id == riderId);
                    if (riderDoc != null) {
                      final rData = riderDoc.data() as Map<String, dynamic>;
                      final lat = (rData['lat'] ?? 0.0).toDouble();
                      final lng = (rData['lng'] ?? 0.0).toDouble();
                      final name = rData['name'] ?? 'ไรเดอร์';
                      if (lat != 0.0 && lng != 0.0) {
                        final riderPos = LatLng(lat, lng);
                        allPoints.add(riderPos);
                        markers.add(Marker(
                          width: 45,
                          height: 45,
                          point: riderPos,
                          child: Tooltip(
                            message: "ไรเดอร์: $name\nสถานะ: $status",
                            child: const Icon(Icons.delivery_dining,
                                color: Colors.blue, size: 38),
                          ),
                        ));
                      }
                    }
                  }
                }

                final center = allPoints.isNotEmpty
                    ? LatLng(
                        allPoints
                                .map((e) => e.latitude)
                                .reduce((a, b) => a + b) /
                            allPoints.length,
                        allPoints
                                .map((e) => e.longitude)
                                .reduce((a, b) => a + b) /
                            allPoints.length,
                      )
                    : LatLng(13.736717, 100.523186);

                return Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 12.5,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.delivery.app',
                        ),
                        PolylineLayer(polylines: polylines),
                        MarkerLayer(markers: markers),
                      ],
                    ),

                    // 🔹 Legend แสดงสัญลักษณ์
                    Positioned(
                      bottom: 20,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.store, color: Colors.green, size: 20),
                            SizedBox(width: 4),
                            Text("จุดรับ", style: TextStyle(fontSize: 12)),
                            SizedBox(width: 12),
                            Icon(Icons.location_on,
                                color: Colors.red, size: 20),
                            SizedBox(width: 4),
                            Text("จุดส่ง", style: TextStyle(fontSize: 12)),
                            SizedBox(width: 12),
                            Icon(Icons.delivery_dining,
                                color: Colors.blue, size: 20),
                            SizedBox(width: 4),
                            Text("ไรเดอร์", style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          }

          // ✅ แสดงรายการแบบลิสต์ (3.1.1–3.1.3)
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final orderId = docs[index].id;
              final senderName = data['userName'] ?? '-';
              final senderPhone = data['userPhone'] ?? '-';
              final pickupAddress = data['pickupAddress'] ?? '-';
              final price = data['price'] ?? 0;
              final status = data['status'] ?? 'รอจัดส่ง';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final imageUrl = data['imageUrl'];

              Color statusColor = Colors.green;
              if (status.contains('นำส่ง')) statusColor = Colors.orange;
              if (status.contains('สำเร็จ')) statusColor = Colors.grey;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Shipment #${index + 1}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "📅 ${createdAt.day}/${createdAt.month}/${createdAt.year} • ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    const Divider(height: 16),
                    Text("👤 ผู้ส่ง: $senderName"),
                    Text("📞 เบอร์โทร: $senderPhone"),
                    Text("📍 ที่อยู่ผู้ส่ง: $pickupAddress"),
                    const SizedBox(height: 12),
                    if (imageUrl != null && imageUrl.toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 12),
                    _buildTimeline(status),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "฿$price",
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => widget.onTrackPressed?.call(orderId),
                          icon: const Icon(Icons.location_on),
                          label: const Text("ติดตาม"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
      ),
    );
  }

  // ---------------- Helper Functions ----------------
  static LatLng? _parseLatLng(String? raw) {
    if (raw == null || !raw.contains(',')) return null;
    try {
      final parts = raw.split(',');
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  void _showShipmentInfo(String sender, String status) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("🚚 ข้อมูล Shipment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ผู้ส่ง: $sender"),
            Text("สถานะ: $status"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ปิด"),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(String status) {
    final steps = [
      "ผู้ส่งสร้างออเดอร์สำเร็จ",
      "ไรเดอร์รับงานแล้ว",
      "ไรเดอร์รับสินค้าแล้ว",
      "ไรเดอร์กำลังส่งสินค้าแล้ว",
      "จัดส่งสำเร็จ",
    ];

    int currentStep = 0;
    if (status == "ไรเดอร์รับงาน") currentStep = 1;
    if (status == "ไรเดอร์รับสินค้าแล้ว") currentStep = 2;
    if (status == "ไรเดอร์กำลังส่งสินค้าแล้ว") currentStep = 3;
    if (status == "จัดส่งสำเร็จ") currentStep = 4;

    return Column(
      children: List.generate(steps.length, (index) {
        final isActive = index <= currentStep;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor:
                      isActive ? Colors.green : Colors.grey.shade300,
                  child: Icon(Icons.check,
                      size: 12,
                      color: isActive ? Colors.white : Colors.transparent),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 2,
                    height: 25,
                    color: isActive ? Colors.green : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive ? Colors.green.shade700 : Colors.grey,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
