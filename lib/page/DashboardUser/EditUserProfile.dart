import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class EditProfileUserPage extends StatefulWidget {
  const EditProfileUserPage({super.key});

  @override
  State<EditProfileUserPage> createState() => _EditProfileUserPageState();
}

class _EditProfileUserPageState extends State<EditProfileUserPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();

  File? _imageFile;
  String? _imageUrl;
  bool _loading = false;

  LatLng? _selectedPosition;
  List<Map<String, dynamic>> _addresses = []; // ✅ ใช้ list แทน address เดี่ยว

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// ✅ โหลดข้อมูลผู้ใช้จาก Firestore
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nameCtl.text = data['name'] ?? '';
        _phoneCtl.text = data['phone'] ?? '';
        _imageUrl = data['imageUrl'];
        _addresses = List<Map<String, dynamic>>.from(data['addresses'] ?? []);
      });
    }
  }

  /// ✅ เลือกรูปใหม่
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  /// ✅ ดึงตำแหน่งปัจจุบัน
  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ กรุณาอนุญาตให้เข้าถึงตำแหน่ง")),
        );
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _selectedPosition = LatLng(pos.latitude, pos.longitude));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("📍 พิกัดปัจจุบัน: ${pos.latitude}, ${pos.longitude}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ ไม่สามารถดึงตำแหน่งได้: $e")));
    }
  }

  /// ✅ เพิ่มที่อยู่ใหม่
  Future<void> _addAddressDialog() async {
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาเลือกพิกัดก่อนเพิ่มที่อยู่")),
      );
      return;
    }

    final addrCtl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("เพิ่มที่อยู่ใหม่"),
        content: TextField(
          controller: addrCtl,
          decoration: const InputDecoration(
            hintText: "กรอกชื่อหรือรายละเอียดที่อยู่",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _addresses.add({
                  "address": addrCtl.text.isNotEmpty
                      ? addrCtl.text
                      : "ที่อยู่ ${_addresses.length + 1}",
                  "lat": _selectedPosition!.latitude,
                  "lng": _selectedPosition!.longitude,
                });
                _selectedPosition = null;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("เพิ่ม"),
          ),
        ],
      ),
    );
  }

  /// ✅ ลบที่อยู่
  void _removeAddress(int index) {
    setState(() => _addresses.removeAt(index));
  }

  /// ✅ อัปโหลดรูปไป Cloudinary
  Future<String?> _uploadToCloudinary(File file) async {
    try {
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']!;
      final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET']!;
      final cloudinary = CloudinaryPublic(cloudName, preset, cache: false);
      final res = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(file.path, folder: "delivery_app/users"),
      );
      return res.secureUrl;
    } catch (e) {
      debugPrint("🔥 Upload Cloudinary Error: $e");
      return null;
    }
  }

  /// ✅ บันทึกข้อมูลทั้งหมดกลับ Firestore
  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _loading = true);

    String? newImageUrl = _imageUrl;
    if (_imageFile != null) {
      final uploadedUrl = await _uploadToCloudinary(_imageFile!);
      if (uploadedUrl != null) newImageUrl = uploadedUrl;
    }

    await _firestore.collection('users').doc(user.uid).update({
      "name": _nameCtl.text.trim(),
      "phone": _phoneCtl.text.trim(),
      "imageUrl": newImageUrl ?? "",
      "addresses": _addresses, // ✅ บันทึก addresses ทั้งหมด
    });

    setState(() => _loading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("✅ บันทึกข้อมูลสำเร็จ")));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_imageFile != null) {
      imageProvider = FileImage(_imageFile!);
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_imageUrl!);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("แก้ไขโปรไฟล์"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _loading ? null : _saveProfile,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 65,
                      backgroundColor: Colors.green.shade100,
                      backgroundImage: imageProvider,
                      child: imageProvider == null
                          ? const Icon(Icons.camera_alt,
                              size: 50, color: Colors.green)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(_nameCtl, Icons.person, "ชื่อผู้ใช้"),
                  _buildTextField(_phoneCtl, Icons.phone, "เบอร์โทรศัพท์",
                      keyboardType: TextInputType.phone),

                  const SizedBox(height: 20),
                  const Text("📍 จัดการที่อยู่และพิกัด",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 10),

                  // 🔹 แสดงแผนที่เลือกพิกัด
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter:
                            _selectedPosition ?? LatLng(13.7367, 100.5231),
                        initialZoom: 13,
                        onTap: (tapPos, point) {
                          setState(() => _selectedPosition = point);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.delivery_frontend',
                        ),
                        if (_selectedPosition != null)
                          MarkerLayer(markers: [
                            Marker(
                              width: 50,
                              height: 50,
                              point: _selectedPosition!,
                              child: const Icon(Icons.location_pin,
                                  color: Colors.red, size: 40),
                            ),
                          ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text("ใช้ตำแหน่งปัจจุบัน"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _addAddressDialog,
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text("เพิ่มที่อยู่จากพิกัดนี้"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 🔹 แสดงรายการที่อยู่ทั้งหมด
                  if (_addresses.isNotEmpty)
                    Column(
                      children: _addresses.asMap().entries.map((entry) {
                        final i = entry.key;
                        final addr = entry.value;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          child: ListTile(
                            leading:
                                const Icon(Icons.home, color: Colors.green),
                            title: Text(addr['address']),
                            subtitle: Text(
                                "Lat: ${addr['lat'].toStringAsFixed(4)} / Lng: ${addr['lng'].toStringAsFixed(4)}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeAddress(i),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    const Text("ยังไม่มีที่อยู่ในระบบ",
                        style: TextStyle(color: Colors.grey)),

                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save),
                    label: const Text("บันทึกการเปลี่ยนแปลง"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController ctl, IconData icon, String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: ctl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.green),
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.green, width: 2),
          ),
        ),
      ),
    );
  }
}
