import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class RiderDeliveringPage extends StatefulWidget {
  const RiderDeliveringPage({super.key});

  @override
  State<RiderDeliveringPage> createState() => _RiderDeliveringPageState();
}

class _RiderDeliveringPageState extends State<RiderDeliveringPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();
  final MapController _mapController = MapController();

  File? _imageFile;
  bool _isUploading = false;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndStartTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  // ✅ ขอ permission และเริ่มติดตามตำแหน่ง
  Future<void> _checkPermissionAndStartTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    _startUpdatingLocation();
  }

  // ✅ อัปเดตพิกัดไรเดอร์เรียลไทม์ทุก 5 วิ
  void _startUpdatingLocation() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final rider = _auth.currentUser;
      if (rider == null) return;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        await _firestore.collection('riders').doc(rider.uid).update({
          'lat': pos.latitude,
          'lng': pos.longitude,
        });

        final activeOrders = await _firestore
            .collection('deliveryRecords')
            .where('riderId', isEqualTo: rider.uid)
            .where('status',
                whereIn: ['ไรเดอร์รับงาน', 'ไรเดอร์รับสินค้าแล้ว']).get();

        for (final doc in activeOrders.docs) {
          await doc.reference.update({
            'riderLat': pos.latitude,
            'riderLng': pos.longitude,
          });
        }

        if (mounted) {
          _mapController.move(
              LatLng(pos.latitude, pos.longitude), _mapController.camera.zoom);
        }
      } catch (_) {}
    });
  }

  LatLng? _parseLatLng(String? raw) {
    if (raw == null || !raw.contains(",")) return null;
    try {
      final parts = raw.split(",");
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.green),
            title: const Text('ถ่ายภาพด้วยกล้อง'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(fromCamera: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.blue),
            title: const Text('เลือกรูปจากเครื่อง'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(fromCamera: false);
            },
          ),
        ]),
      ),
    );
  }

  // ✅ อัปโหลดหลักฐานขึ้น Firebase Storage (ล้มเหลวไม่หยุดการทำงาน)
  Future<String?> _uploadProof(String orderId, bool isPickup) async {
    if (_imageFile == null) return null;
    setState(() => _isUploading = true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          isPickup ? "pickup_$timestamp.jpg" : "delivery_$timestamp.jpg";
      final ref = FirebaseStorage.instance
          .ref()
          .child('deliveryProofs/$orderId/$fileName');
      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("❌ uploadProof ล้มเหลว: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("⚠️ อัปโหลดรูปไม่สำเร็จ แต่จะอัปเดตสถานะต่อไป")),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ✅ ยืนยันสถานะ (รับของ / ส่งของ)
  Future<void> _confirmStep(String orderId, String currentStatus) async {
    bool isPickup = currentStatus == "ไรเดอร์รับงาน";
    String nextStatus =
        isPickup ? "ไรเดอร์รับสินค้าแล้ว" : "ไรเดอร์นำส่งสินค้าแล้ว";
    String fieldName = isPickup ? "pickupProofUrl" : "deliveryProofUrl";

    String? proofUrl;
    try {
      proofUrl = await _uploadProof(orderId, isPickup);
    } catch (_) {
      proofUrl = null;
    }

    try {
      final updateData = {
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (proofUrl != null) updateData[fieldName] = proofUrl;

      await _firestore
          .collection('deliveryRecords')
          .doc(orderId)
          .update(updateData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ อัปเดตสถานะเป็น $nextStatus สำเร็จ")),
      );

      setState(() => _imageFile = null);
    } catch (e) {
      debugPrint("❌ ERROR while updating status: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ เกิดข้อผิดพลาด: $e")));
    }
  }

  Widget _buildProgressBar(String status) {
    final steps = [
      "ไรเดอร์รับงาน",
      "ไรเดอร์รับสินค้าแล้ว",
      "ไรเดอร์นำส่งสินค้าแล้ว"
    ];
    final activeStep = steps.indexOf(status);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (i) {
        bool done = i <= activeStep;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i != 0)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: done ? Colors.green : Colors.grey.shade300,
                      ),
                    ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: done ? Colors.green : Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      i == 0
                          ? Icons.assignment
                          : i == 1
                              ? Icons.inventory_2
                              : Icons.check_circle,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  if (i != steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i < activeStep
                            ? Colors.green
                            : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                steps[i].replaceAll("ไรเดอร์", ""),
                style: TextStyle(
                  fontSize: 12,
                  color: done ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        );
      }),
    );
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
          .where('status',
              whereIn: ['ไรเดอร์รับงาน', 'ไรเดอร์รับสินค้าแล้ว']).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text("ยังไม่มีงานที่กำลังส่ง",
                  style: TextStyle(color: Colors.grey)));
        }

        final deliveries = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: deliveries.length,
          itemBuilder: (context, index) {
            final d = deliveries[index].data() as Map<String, dynamic>;
            final orderId = deliveries[index].id;

            final pickupAddress = d['pickupAddress'] ?? '-';
            final dropAddress = d['dropAddress'] ?? '-';
            final userName = d['userName'] ?? 'ไม่ระบุชื่อผู้ส่ง';
            final userPhone = d['userPhone'] ?? '-';
            final receiverName = d['receiverName'] ?? 'ไม่ระบุชื่อผู้รับ';
            final receiverPhone = d['receiverPhone'] ?? '-';
            final productImageUrl = d['productImageUrl'];
            final pickupProofUrl = d['pickupProofUrl'];
            final deliveryProofUrl = d['deliveryProofUrl'];
            final price = d['price'] ?? 0;
            final status = d['status'] ?? '-';
            final pickupLatLng = _parseLatLng(d['pickupLatLng']);
            final dropLatLng = _parseLatLng(d['dropLatLng']);

            final isStep1 = status == "ไรเดอร์รับงาน";
            final buttonText = isStep1 ? "ยืนยันรับสินค้า" : "ยืนยันส่งสำเร็จ";
            final buttonColor = isStep1 ? Colors.green : Colors.orange;

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
                  // ✅ แถบสถานะ 3 ขั้นตอน
                  _buildProgressBar(status),
                  const SizedBox(height: 16),

                  Text("ออเดอร์ #$orderId",
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("ผู้ส่ง: $userName ($userPhone)"),
                  Text("ผู้รับ: $receiverName ($receiverPhone)"),
                  const Divider(height: 18),

                  if (productImageUrl != null &&
                      productImageUrl.toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        productImageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 10),

                  if (pickupProofUrl != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("📦 รูปตอนรับของ"),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(pickupProofUrl, height: 120),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),

                  if (deliveryProofUrl != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("🚚 รูปตอนส่งของ"),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(deliveryProofUrl, height: 120),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),

                  Row(
                    children: [
                      const Icon(Icons.store, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text("จุดรับสินค้า\n$pickupAddress")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
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
                            initialCenter: pickupLatLng, initialZoom: 13),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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

                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _isUploading ? null : _showImageSourceDialog,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _imageFile == null
                          ? const Center(
                              child: Text("เพิ่มรูปภาพ (ไม่บังคับ)",
                                  style: TextStyle(color: Colors.green)))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_imageFile!, fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _isUploading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: () => _confirmStep(orderId, status),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(buttonText,
                              style: const TextStyle(color: Colors.white)),
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
  }
}
