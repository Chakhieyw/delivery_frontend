import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ReceiverTrackPage extends StatelessWidget {
  final String orderId;
  const ReceiverTrackPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final orderStream = FirebaseFirestore.instance
        .collection('deliveryRecords')
        .doc(orderId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("🚚 ติดตามพัสดุของฉัน"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: orderStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text("ไม่พบข้อมูลออเดอร์นี้"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] ?? '-';
          final pickupLatLng = _parseLatLng(data['pickupLatLng']);
          final dropLatLng = _parseLatLng(data['dropLatLng']);
          final riderId = data['riderId'];
          final pickupProof = data['pickupProofUrl'];
          final deliveryProof = data['deliveryProofUrl'];

          final step = _getStatusStep(status);

          return StreamBuilder<DocumentSnapshot>(
            stream: riderId != null && riderId != ''
                ? FirebaseFirestore.instance
                    .collection('riders')
                    .doc(riderId)
                    .snapshots()
                : const Stream.empty(),
            builder: (context, riderSnap) {
              final riderData =
                  riderSnap.data?.data() as Map<String, dynamic>? ?? {};
              final riderName = riderData['name'] ?? '-';
              final riderPhone = riderData['phone'] ?? '-';
              final riderPlate = riderData['plate'] ?? '-';
              final riderLat = (riderData['lat'] ?? 0.0).toDouble();
              final riderLng = (riderData['lng'] ?? 0.0).toDouble();
              final hasMap = pickupLatLng != null && dropLatLng != null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "สถานะการจัดส่ง",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildTimeline(step),
                    const SizedBox(height: 20),

                    // 🗺️ แผนที่
                    if (hasMap)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 220,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: pickupLatLng!,
                              initialZoom: 13.5,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.delivery.app',
                              ),
                              PolylineLayer(polylines: [
                                Polyline(
                                  points: [pickupLatLng, dropLatLng!],
                                  strokeWidth: 4,
                                  color: Colors.green,
                                ),
                              ]),
                              MarkerLayer(markers: [
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
                                if (riderLat != 0.0 && riderLng != 0.0)
                                  Marker(
                                    point: LatLng(riderLat, riderLng),
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.delivery_dining,
                                        color: Colors.blue, size: 35),
                                  ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // 👤 ข้อมูลไรเดอร์
                    const Text(
                      "ข้อมูลไรเดอร์",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("ชื่อ: $riderName"),
                          Text("เบอร์โทร: $riderPhone"),
                          Text("ทะเบียนรถ: $riderPlate"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    if (pickupProof != null &&
                        pickupProof.toString().isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("📦 รูปตอนรับสินค้า:",
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              pickupProof,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    if (deliveryProof != null &&
                        deliveryProof.toString().isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("📸 รูปตอนจัดส่งสำเร็จ:",
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              deliveryProof,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
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

  static LatLng? _parseLatLng(String? raw) {
    if (raw == null || !raw.contains(',')) return null;
    try {
      final parts = raw.split(',');
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  static int _getStatusStep(String status) {
    switch (status) {
      case 'รอไรเดอร์มารับสินค้า':
        return 0;
      case 'ไรเดอร์รับงาน':
        return 1;
      case 'ไรเดอร์รับสินค้าแล้ว':
        return 2;
      case 'ไรเดอร์นำส่งสินค้าแล้ว':
      case 'ไรเดอร์กำลังส่งสินค้าแล้ว':
        return 3;
      case 'จัดส่งสำเร็จ':
        return 4;
      default:
        return 0;
    }
  }

  Widget _buildTimeline(int step) {
    final steps = [
      "สร้างออเดอร์สำเร็จ",
      "ไรเดอร์รับงานแล้ว",
      "ไรเดอร์รับสินค้าแล้ว",
      "ไรเดอร์กำลังนำส่งสินค้าแล้ว",
      "จัดส่งสำเร็จ",
    ];

    return Column(
      children: List.generate(steps.length, (i) {
        final isActive = i <= step;
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
                if (i < steps.length - 1)
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
                  steps[i],
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
