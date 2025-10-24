import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
  LatLng? _currentRiderPos;
  double? _currentDistance;

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
        _currentRiderPos = LatLng(pos.latitude, pos.longitude);
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

        if (mounted) setState(() {});
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

  // ✅ อัปโหลดหลักฐานขึ้น Cloudinary (แทน Firebase Storage)
  Future<String?> _uploadProof(String orderId, bool isPickup) async {
    if (_imageFile == null) return null;
    setState(() => _isUploading = true);
    try {
      // ⚙️ ตั้งค่า Cloudinary (แก้ให้ตรงของก้องภพ)
      const cloudName = "dwew1qkvb"; // 👉 เช่น deliverymsu
      const uploadPreset = "delivery_upload"; // 👉 เช่น unsigned_delivery

      final url =
          Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files
            .add(await http.MultipartFile.fromPath('file', _imageFile!.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final resData = await http.Response.fromStream(response);
        final data = jsonDecode(resData.body);
        final uploadedUrl = data['secure_url'];

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ อัปโหลดรูปขึ้น Cloudinary สำเร็จ")),
          );
        }
        return uploadedUrl;
      } else {
        debugPrint("❌ Cloudinary Upload Failed: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ uploadProof ล้มเหลว: $e");
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ✅ ตรวจว่าห่างจากจุดรับสินค้าน้อยกว่า 20 เมตร
  Future<bool> _isWithinDistance(LatLng? pickupLatLng) async {
    if (pickupLatLng == null) return true;
    final pos = await Geolocator.getCurrentPosition();
    final dist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      pickupLatLng.latitude,
      pickupLatLng.longitude,
    );
    setState(() => _currentDistance = dist);
    return dist <= 20;
  }

  // ✅ ยืนยันสถานะ (บังคับรูป + ตรวจระยะ + Transaction)
  Future<void> _confirmStep(
      String orderId, String currentStatus, LatLng? pickupLatLng) async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ กรุณาถ่ายรูปก่อนยืนยัน")),
      );
      return;
    }

    if (currentStatus == "ไรเดอร์รับงาน") {
      bool withinRange = await _isWithinDistance(pickupLatLng);
      if (!withinRange) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("🚫 ห่างจากจุดรับสินค้ามากกว่า 20 เมตร!")),
        );
        return;
      }
    }

    final isPickup = currentStatus == "ไรเดอร์รับงาน";
    final nextStatus =
        isPickup ? "ไรเดอร์รับสินค้าแล้ว" : "ไรเดอร์นำส่งสินค้าแล้ว";
    final imageField = isPickup ? "pickupProofUrl" : "deliveryProofUrl";

    String? proofUrl = await _uploadProof(orderId, isPickup);
    if (proofUrl == null) return;

    await _firestore.runTransaction((transaction) async {
      final docRef = _firestore.collection('deliveryRecords').doc(orderId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      transaction.update(docRef, {
        'status': nextStatus,
        imageField: proofUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ อัปเดตสถานะเป็น $nextStatus สำเร็จ")),
    );

    setState(() => _imageFile = null);
  }

  // ✅ สร้างแถบ Progress แสดงสถานะการจัดส่ง
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
                  _buildProgressBar(status),
                  const SizedBox(height: 16),
                  Text("ออเดอร์ #$orderId",
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text("ผู้ส่ง: $userName ($userPhone)"),
                  Text("ผู้รับ: $receiverName ($receiverPhone)"),
                  const Divider(height: 18),
                  if (productImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(productImageUrl,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 10),
                  if (_currentRiderPos != null &&
                      pickupLatLng != null &&
                      dropLatLng != null)
                    Column(
                      children: [
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
                                    child: const Icon(Icons.store,
                                        color: Colors.green, size: 35),
                                  ),
                                  Marker(
                                    point: dropLatLng,
                                    child: const Icon(Icons.location_on,
                                        color: Colors.red, size: 35),
                                  ),
                                  Marker(
                                    point: _currentRiderPos!,
                                    child: const Icon(Icons.motorcycle,
                                        color: Colors.blue, size: 30),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (_currentDistance != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              "📏 ระยะจากจุดรับสินค้า: ${_currentDistance!.toStringAsFixed(2)} เมตร",
                              style: TextStyle(
                                color: _currentDistance! <= 20
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
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
                              child: Text("📸 ถ่ายรูปก่อนยืนยัน",
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
                          onPressed: () =>
                              _confirmStep(orderId, status, pickupLatLng),
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
