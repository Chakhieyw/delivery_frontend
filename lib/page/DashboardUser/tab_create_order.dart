import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_frontend/page/map_picker_page.dart';

class CreateOrderForm extends StatefulWidget {
  final VoidCallback? onOrderCreated;
  const CreateOrderForm({super.key, this.onOrderCreated});

  @override
  State<CreateOrderForm> createState() => _CreateOrderFormState();
}

class _CreateOrderFormState extends State<CreateOrderForm> {
  final _pickupAddressCtl = TextEditingController();
  final _dropAddressCtl = TextEditingController();
  final _detailCtl = TextEditingController();
  final _priceCtl = TextEditingController();
  final _searchPhoneCtl = TextEditingController();

  File? _imageFile;
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  bool _loading = false;

  // ผู้รับที่เลือก
  String? selectedReceiverId;
  String? selectedReceiverName;
  String? selectedReceiverPhone;
  String? selectedReceiverAddress;

  // ดึงข้อมูลผู้ใช้ทั้งหมดจาก Firestore
  Stream<QuerySnapshot> get receiversStream =>
      FirebaseFirestore.instance.collection('users').snapshots();

  // ✅ แปลงพิกัดเป็นชื่อที่อยู่
  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return "${p.street ?? ''} ${p.subLocality ?? ''} ${p.locality ?? ''} ${p.administrativeArea ?? ''}"
            .trim();
      }
      return "ไม่พบที่อยู่";
    } catch (e) {
      return "ไม่สามารถระบุที่อยู่ได้";
    }
  }

  // 📍 ใช้ตำแหน่งปัจจุบัน
  Future<void> _getCurrentLocation(bool isPickup) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("⚠️ โปรดเปิดสิทธิ์ Location ในการตั้งค่าแอป")),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final address = await _getAddressFromLatLng(pos.latitude, pos.longitude);

      setState(() {
        final latLng = LatLng(pos.latitude, pos.longitude);
        if (isPickup) {
          _pickupLatLng = latLng;
          _pickupAddressCtl.text = address;
        } else {
          _dropLatLng = latLng;
          _dropAddressCtl.text = address;
        }
      });
    } catch (e) {
      debugPrint("⚠️ GPS error: $e");
    }
  }

  // 🗺️ เปิดแผนที่ให้เลือกตำแหน่ง
  Future<void> _openMapPicker(bool isPickup) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          onPositionSelected: (pos) async {
            final address =
                await _getAddressFromLatLng(pos.latitude, pos.longitude);
            setState(() {
              if (isPickup) {
                _pickupLatLng = pos;
                _pickupAddressCtl.text = address;
              } else {
                _dropLatLng = pos;
                _dropAddressCtl.text = address;
              }
            });
          },
        ),
      ),
    );
  }

  // 📸 ถ่ายรูปพัสดุ
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  // ✅ สร้างออเดอร์ใหม่
  Future<void> _createOrder() async {
    if (selectedReceiverId == null ||
        _pickupAddressCtl.text.isEmpty ||
        _dropAddressCtl.text.isEmpty ||
        _priceCtl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ กรุณากรอกข้อมูลให้ครบ")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};

      // ✅ บันทึกข้อมูล shipment ลง Firestore
      await FirebaseFirestore.instance.collection("deliveryRecords").add({
        "userId": user.uid, // ✅ กลับมาใช้ userId
        "userName": userData['name'] ?? 'ไม่ระบุ',
        "userPhone": userData['phone'] ?? '-',

        "receiverId": selectedReceiverId,
        "receiverName": selectedReceiverName,
        "receiverPhone": selectedReceiverPhone,
        "receiverAddress": selectedReceiverAddress ?? '-',

        "pickupAddress": _pickupAddressCtl.text,
        "dropAddress": _dropAddressCtl.text,
        "pickupLatLng": _pickupLatLng != null
            ? "${_pickupLatLng!.latitude},${_pickupLatLng!.longitude}"
            : "-",
        "dropLatLng": _dropLatLng != null
            ? "${_dropLatLng!.latitude},${_dropLatLng!.longitude}"
            : "-",

        "details": _detailCtl.text,
        "price": double.tryParse(_priceCtl.text) ?? 0.0,
        "status": "รอไรเดอร์รับงาน",
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ สร้างออเดอร์สำเร็จ")),
      );

      widget.onOrderCreated?.call();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("สร้างออเดอร์ใหม่"),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle("ค้นหาผู้รับจากเบอร์โทรศัพท์"),
            TextField(
              controller: _searchPhoneCtl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "พิมพ์เบอร์โทรผู้รับ เช่น 0812345678",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() => _searchPhoneCtl.clear());
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 15),
            _buildTitle("เลือกผู้รับสินค้า"),
            StreamBuilder<QuerySnapshot>(
              stream: receiversStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allUsers = snapshot.data!.docs;

                // 🔍 กรองจากเบอร์โทร
                final filteredUsers = allUsers.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final phone = data['phone']?.toString() ?? '';
                  return phone.contains(_searchPhoneCtl.text.trim());
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Text("ไม่พบผู้ใช้ที่ตรงกับเบอร์โทรนี้",
                      style: TextStyle(color: Colors.grey));
                }

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "เลือกผู้รับจากรายชื่อผู้ใช้",
                  ),
                  value: selectedReceiverId,
                  items: filteredUsers.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text("${data['name']} (${data['phone'] ?? '-'})"),
                    );
                  }).toList(),
                  onChanged: (val) {
                    final user = allUsers.firstWhere((u) => u.id == val);
                    final data = user.data() as Map<String, dynamic>;
                    setState(() {
                      selectedReceiverId = val;
                      selectedReceiverName = data['name'];
                      selectedReceiverPhone = data['phone'];
                      selectedReceiverAddress = data['address'] ?? '-';
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            _buildAddressSection("จุดรับสินค้า", _pickupAddressCtl, true),
            const SizedBox(height: 20),
            _buildAddressSection("จุดส่งสินค้า", _dropAddressCtl, false),
            const SizedBox(height: 20),
            _buildTitle("รายละเอียดเพิ่มเติม"),
            TextField(
              controller: _detailCtl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "รายละเอียดพัสดุ, คำแนะนำ",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _buildTitle("รูปถ่ายพัสดุ"),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : const Center(child: Text("แตะเพื่อถ่ายรูปพัสดุ")),
              ),
            ),
            const SizedBox(height: 20),
            _buildTitle("ค่าใช้จ่าย"),
            TextField(
              controller: _priceCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "ระบุราคา (บาท)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    minimumSize: const Size(130, 45),
                  ),
                  child: const Text("ยกเลิก"),
                ),
                ElevatedButton(
                  onPressed: _loading ? null : _createOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(130, 45),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("สร้างออเดอร์"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );

  Widget _buildAddressSection(
      String title, TextEditingController ctl, bool isPickup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(title),
        TextField(
          controller: ctl,
          readOnly: true,
          decoration: InputDecoration(
            hintText: "แตะปุ่มด้านขวาเพื่อเลือกที่อยู่",
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.my_location, color: Colors.green),
                  onPressed: () => _getCurrentLocation(isPickup),
                ),
                IconButton(
                  icon: const Icon(Icons.map, color: Colors.orange),
                  onPressed: () => _openMapPicker(isPickup),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
