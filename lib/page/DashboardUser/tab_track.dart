import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

class TrackTab extends StatefulWidget {
  final String? selectedOrderId;
  const TrackTab({super.key, required this.selectedOrderId});

  @override
  State<TrackTab> createState() => _TrackTabState();
}

class _TrackTabState extends State<TrackTab> {
  String? currentOrderId;

  @override
  void initState() {
    super.initState();
    currentOrderId = widget.selectedOrderId;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("กรุณาเข้าสู่ระบบใหม่อีกครั้ง"));
    }

    // ✅ ถ้ายังไม่ได้กดติดตามจากหน้า Home → แสดง “แผนที่รวมทั้งหมด”
    if (widget.selectedOrderId == null || widget.selectedOrderId!.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "🌍 แผนที่รวมทุก Shipment ของฉัน",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Expanded(child: _AllShipmentsMapView()),
            ],
          ),
        ),
      );
    }

    // ✅ ถ้ามี selectedOrderId → แสดง Timeline + รายละเอียด Shipment
    final orderStream = FirebaseFirestore.instance
        .collection('deliveryRecords')
        .doc(widget.selectedOrderId)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
          final status = data['status'] ?? 'รอไรเดอร์มารับสินค้า';
          final riderId = data['riderId'];
          final pickupLatLng = _parseLatLng(data['pickupLatLng']);
          final dropLatLng = _parseLatLng(data['dropLatLng']);
          final step = _getStatusStep(status);

          // 🟡 ถ้ายังไม่มีไรเดอร์รับงาน → แสดงสถานะรอไรเดอร์ + รายละเอียด shipment
          if (riderId == null || riderId.isEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "สถานะการจัดส่ง",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _buildTimeline(step),
                  const SizedBox(height: 20),

                  // 🔹 การ์ดสถานะรอไรเดอร์
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.timer, color: Colors.orange),
                        SizedBox(height: 8),
                        Text(
                          "กำลังรอไรเดอร์รับงาน...",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "ออเดอร์ของคุณถูกสร้างเรียบร้อยแล้ว โปรดรอไรเดอร์รับงาน",
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // 🔹 รายละเอียด Shipment
                  _buildShipmentDetailCard(data, status),
                ],
              ),
            );
          }

          // ✅ ถ้ามีไรเดอร์แล้ว → แสดงข้อมูลไรเดอร์ + แผนที่
          final riderStream = FirebaseFirestore.instance
              .collection('riders')
              .doc(riderId)
              .snapshots();

          return StreamBuilder<DocumentSnapshot>(
            stream: riderStream,
            builder: (context, riderSnap) {
              if (!riderSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final riderData =
                  riderSnap.data!.data() as Map<String, dynamic>? ?? {};
              final riderName = riderData['name'] ?? '-';
              final riderPhone = riderData['phone'] ?? '-';
              final riderBike = riderData['plate'] ?? '-';
              final riderLat = riderData['lat'] ?? 0.0;
              final riderLng = riderData['lng'] ?? 0.0;
              final hasMap = riderLat != 0.0 && riderLng != 0.0;

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
                    const SizedBox(height: 20),
                    _buildTimeline(step),
                    const SizedBox(height: 20),

                    // 🔹 แผนที่ Real-time
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: hasMap
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(riderLat, riderLng),
                                  initialZoom: 13.5,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.delivery.app',
                                  ),
                                  if (pickupLatLng != null &&
                                      dropLatLng != null)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: [pickupLatLng, dropLatLng],
                                          strokeWidth: 4,
                                          color: Colors.green,
                                        ),
                                      ],
                                    ),
                                  MarkerLayer(markers: [
                                    if (pickupLatLng != null)
                                      Marker(
                                        point: pickupLatLng,
                                        width: 40,
                                        height: 40,
                                        child: const Icon(Icons.store,
                                            color: Colors.green, size: 35),
                                      ),
                                    if (dropLatLng != null)
                                      Marker(
                                        point: dropLatLng,
                                        width: 40,
                                        height: 40,
                                        child: const Icon(Icons.location_on,
                                            color: Colors.red, size: 35),
                                      ),
                                    Marker(
                                      point: LatLng(riderLat, riderLng),
                                      width: 45,
                                      height: 45,
                                      child: const Icon(Icons.delivery_dining,
                                          color: Colors.blue, size: 40),
                                    ),
                                  ]),
                                ],
                              ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.map, color: Colors.grey, size: 40),
                                  SizedBox(height: 6),
                                  Text("ยังไม่มีข้อมูลตำแหน่งไรเดอร์",
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // 🔹 ข้อมูลไรเดอร์
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.person, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                "ข้อมูลไรเดอร์",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text("ชื่อ: $riderName"),
                          Text("เบอร์โทร: $riderPhone"),
                          Text("รถจักรยานยนต์: $riderBike"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // 🔹 รายละเอียด Shipment
                    _buildShipmentDetailCard(data, status),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------- Utility Functions ----------------

  static int _getStatusStep(String status) {
    switch (status) {
      case 'รอไรเดอร์มารับสินค้า':
        return 0;
      case 'ไรเดอร์รับงาน':
        return 1;
      case 'ไรเดอร์รับสินค้าแล้ว':
        return 2;
      case 'ไรเดอร์กำลังนำส่งสินค้าแล้ว':
        return 3;
      case 'จัดส่งสำเร็จ':
        return 4;
      default:
        return 0;
    }
  }

  static LatLng? _parseLatLng(String? raw) {
    if (raw == null || !raw.contains(",")) return null;
    try {
      final parts = raw.split(",");
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (_) {
      return null;
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
      children: List.generate(steps.length, (index) {
        final isActive = index <= step;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor:
                        isActive ? Colors.green : Colors.grey.shade300,
                    child: Icon(Icons.check,
                        size: 14,
                        color: isActive ? Colors.white : Colors.transparent),
                  ),
                  if (index < steps.length - 1)
                    Container(
                      width: 2,
                      height: 30,
                      color: isActive ? Colors.green : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  steps[index],
                  style: TextStyle(
                    color: isActive ? Colors.green.shade700 : Colors.grey,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildShipmentDetailCard(Map<String, dynamic> data, String status) {
    return Container(
      width: double.infinity,
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
          const Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.green),
              SizedBox(width: 8),
              Text(
                "รายละเอียด Shipment",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text("👤 ผู้รับ: ${data['receiverName'] ?? '-'}"),
          Text("📞 เบอร์โทรผู้รับ: ${data['receiverPhone'] ?? '-'}"),
          Text("📍 พิกัดผู้รับ: ${data['receiverAddress'] ?? '-'}"),
          const SizedBox(height: 10),
          Text(
            "สถานะล่าสุด: $status",
            style: const TextStyle(
                color: Colors.green, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "วันที่สร้าง: ${(data['createdAt'] as Timestamp?)?.toDate().toString().split('.').first ?? '-'}",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// 🔹 แผนที่รวมทุก Shipment ของผู้ใช้
class _AllShipmentsMapView extends StatelessWidget {
  const _AllShipmentsMapView();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    final stream = FirebaseFirestore.instance
        .collection('deliveryRecords')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("ยังไม่มี Shipment ในระบบ"));
        }

        final markers = <Marker>[];
        final polylines = <Polyline>[];
        final allPoints = <LatLng>[];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final pickup = _parseLatLng(data['pickupLatLng']);
          final drop = _parseLatLng(data['dropLatLng']);

          if (pickup != null && drop != null) {
            allPoints.addAll([pickup, drop]);
            polylines.add(Polyline(
              points: [pickup, drop],
              strokeWidth: 3,
              color: Colors.green.withOpacity(0.5),
            ));

            markers.addAll([
              Marker(
                point: pickup,
                width: 40,
                height: 40,
                child: const Icon(Icons.store, color: Colors.green, size: 30),
              ),
              Marker(
                point: drop,
                width: 40,
                height: 40,
                child:
                    const Icon(Icons.location_on, color: Colors.red, size: 32),
              ),
            ]);
          }
        }

        final center = allPoints.isNotEmpty
            ? LatLng(
                allPoints.map((e) => e.latitude).reduce((a, b) => a + b) /
                    allPoints.length,
                allPoints.map((e) => e.longitude).reduce((a, b) => a + b) /
                    allPoints.length,
              )
            : LatLng(16.245, 103.251);

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.delivery.app',
              ),
              PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),
        );
      },
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
}
