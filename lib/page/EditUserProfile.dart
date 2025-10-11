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
  final _addressCtl = TextEditingController();

  File? _imageFile;
  String? _imageUrl;
  bool _loading = false;
  LatLng? _selectedPosition;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nameCtl.text = data['name'] ?? '';
        _phoneCtl.text = data['phone'] ?? '';
        _addressCtl.text = data['address'] ?? '';
        _imageUrl = data['imageUrl'];
        if (data['location'] != null) {
          _selectedPosition = LatLng(
            data['location']['lat'] ?? 0,
            data['location']['lng'] ?? 0,
          );
        }
      });
    }
  }

  /// ✅ เลือกรูปใหม่
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  /// ✅ พรีวิวรูป
  void _previewImage() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_imageFile != null)
              Image.file(_imageFile!, fit: BoxFit.cover)
            else if (_imageUrl != null && _imageUrl!.isNotEmpty)
              Image.network(_imageUrl!, fit: BoxFit.cover),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.red),
              label:
                  const Text("ปิดดูรูป", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ ลบรูป
  Future<void> _deleteProfileImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _imageFile = null;
      _imageUrl = null;
    });

    await _firestore.collection('users').doc(user.uid).update({'imageUrl': ''});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🗑️ ลบรูปโปรไฟล์เรียบร้อย")),
    );
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
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedPosition = LatLng(pos.latitude, pos.longitude);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("📍 พิกัดปัจจุบัน: ${pos.latitude}, ${pos.longitude}"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ ไม่สามารถดึงตำแหน่งได้: $e")),
      );
    }
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

  /// ✅ บันทึกข้อมูล
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
      "address": _addressCtl.text.trim(),
      "imageUrl": newImageUrl ?? "",
      "location": _selectedPosition != null
          ? {
              "lat": _selectedPosition!.latitude,
              "lng": _selectedPosition!.longitude,
            }
          : null,
    });

    setState(() => _loading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ บันทึกข้อมูลสำเร็จ")),
    );
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
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GestureDetector(
                        onTap: _previewImage,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _iconButton(Icons.photo_library, Colors.blue,
                              "เปลี่ยนรูป", _pickImage),
                          const SizedBox(width: 6),
                          _iconButton(Icons.delete, Colors.red, "ลบรูป",
                              _deleteProfileImage),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _buildTextField(_nameCtl, Icons.person, "ชื่อผู้ใช้"),
                  _buildTextField(_phoneCtl, Icons.phone, "เบอร์โทรศัพท์",
                      keyboardType: TextInputType.phone),
                  _buildTextField(_addressCtl, Icons.home, "ที่อยู่"),
                  const SizedBox(height: 15),
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
                    ],
                  ),
                  const SizedBox(height: 15),
                  if (_selectedPosition != null)
                    SizedBox(
                      height: 200,
                      width: 340,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: _selectedPosition!,
                          initialZoom: 15,
                          onTap: (tapPos, point) {
                            setState(() => _selectedPosition = point);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.thunderforest.com/atlas/{z}/{x}/{y}.png?apikey=12183dd51e894a75b97d6786c14a83ac',
                            userAgentPackageName:
                                'com.example.delivery_frontend',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedPosition!,
                                width: 50,
                                height: 50,
                                child: const Icon(Icons.location_pin,
                                    color: Colors.red, size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    const Text("📍 ยังไม่ได้เลือกตำแหน่ง",
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

  Widget _iconButton(
      IconData icon, Color color, String tooltip, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 18),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.green, width: 2),
          ),
        ),
      ),
    );
  }
}
