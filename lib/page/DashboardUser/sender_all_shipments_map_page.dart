import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SenderAllShipmentsMapPage extends StatefulWidget {
  const SenderAllShipmentsMapPage({super.key});

  @override
  State<SenderAllShipmentsMapPage> createState() =>
      _SenderAllShipmentsMapPageState();
}

class _SenderAllShipmentsMapPageState extends State<SenderAllShipmentsMapPage> {
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("กรุณาเข้าสู่ระบบใหม่อีกครั้ง"),
        ),
      );
    }

    final shipmentsStream = FirebaseFirestore.instance
        .collection('deliveryRecords')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "🌍 แผนที่รวมทุก Shipment ของฉัน",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: shipmentsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "ยังไม่มีรายการจัดส่งในระบบ",
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          final docs = snapshot.data!.docs;
          final List<Marker> markers = [];
          final List<Polyline> polylines = [];
          final List<LatLng> allPoints = [];

          // ✅ ดึงข้อมูลทุก Shipment
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;

            final pickupLatLng = _parseLatLng(data['pickupLatLng']);
            final dropLatLng = _parseLatLng(data['dropLatLng']);
            final status = data['status'] ?? '-';
            final riderId = data['riderId'];

            if (pickupLatLng != null) {
              allPoints.add(pickupLatLng);
              markers.add(Marker(
                point: pickupLatLng,
                width: 40,
                height: 40,
                child: Tooltip(
                  message: "จุดรับสินค้า",
                  child: const Icon(Icons.store, color: Colors.green, size: 35),
                ),
              ));
            }

            if (dropLatLng != null) {
              allPoints.add(dropLatLng);
              markers.add(Marker(
                point: dropLatLng,
                width: 40,
                height: 40,
                child: Tooltip(
                  message: "จุดส่งสินค้า",
                  child:
                      const Icon(Icons.location_on, color: Colors.red, size: 38),
                ),
              ));
            }

            if (pickupLatLng != null && dropLatLng != null) {
              polylines.add(Polyline(
                points: [pickupLatLng, dropLatLng],
                strokeWidth: 3,
                color: Colors.green.withOpacity(0.5),
              ));
            }

            // ✅ ตำแหน่งไรเดอร์แบบเรียลไทม์
            if (riderId != null && riderId != '') {
              FirebaseFirestore.instance
                  .collection('riders')
                  .doc(riderId)
                  .snapshots()
                  .listen((riderSnap) {
                if (!riderSnap.exists) return;
                final riderData = riderSnap.data()!;
                final lat = riderData['lat'] ?? 0.0;
                final lng = riderData['lng'] ?? 0.0;

                if (lat != 0.0 && lng != 0.0) {
                  setState(() {
                    markers.add(
                      Marker(
                        point: LatLng(lat, lng),
                        width: 45,
                        height: 45,
                        child: Tooltip(
                          message:
                              "ไรเดอร์: ${riderData['name'] ?? '-'}\nสถานะ: $status",
                          child: const Icon(
                            Icons.delivery_dining,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),
                      ),
                    );
                  });
                }
              });
            }
          }

          if (allPoints.isEmpty) {
            return const Center(
              child: Text("ไม่พบตำแหน่งจัดส่งสินค้าในระบบ"),
            );
          }

          // ✅ คำนวณจุดกลางของทุก Shipment
          final avgLat =
              allPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
                  allPoints.length;
          final avgLng =
              allPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
                  allPoints.length;
          final center = LatLng(avgLat, avgLng);

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 12,
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

              // 🔹 ปุ่มกลับ
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton(
                  backgroundColor: Colors.green,
                  mini: true,
                  child: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => setState(() {}),
                ),
              ),

              // 🔹 Legend (คำอธิบาย)
              Positioned(
                bottom: 20,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  child: Row(
                    children: const [
                      Icon(Icons.store, color: Colors.green),
                      SizedBox(width: 4),
                      Text("จุดรับ", style: TextStyle(fontSize: 12)),
                      SizedBox(width: 12),
                      Icon(Icons.location_on, color: Colors.red),
                      SizedBox(width: 4),
                      Text("จุดส่ง", style: TextStyle(fontSize: 12)),
                      SizedBox(width: 12),
                      Icon(Icons.delivery_dining, color: Colors.blue),
                      SizedBox(width: 4),
                      Text("ไรเดอร์", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  LatLng? _parseLatLng(String? raw) {
    if (raw == null || !raw.contains(",")) return null;
    try {
      final parts = raw.split(",");
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }
}
