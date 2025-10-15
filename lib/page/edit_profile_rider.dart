import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditProfileRiderPage extends StatefulWidget {
  const EditProfileRiderPage({super.key});

  @override
  State<EditProfileRiderPage> createState() => _EditProfileRiderPageState();
}

class _EditProfileRiderPageState extends State<EditProfileRiderPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();

  String? _imageUrl;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchRiderData();
  }

  Future<void> fetchRiderData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('riders').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _plateController.text = data['plate'] ?? '';
        _imageUrl = data['imageUrl'];
        setState(() {});
      }
    } catch (e) {
      debugPrint("⚠️ Error loading data: $e");
    }
  }

  Future<void> pickImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ กรุณากรอกข้อมูลให้ครบถ้วน")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _imageUrl;

      // 📤 อัปโหลดรูปใหม่ถ้ามีการเลือก
      if (_selectedImage != null) {
        final ref = _storage.ref().child('profile/${user.uid}.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      // 📝 อัปเดต Firestore
      await _firestore.collection('riders').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'plate': _plateController.text.trim(),
        'imageUrl': imageUrl ?? '',
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("✅ บันทึกข้อมูลสำเร็จ")));

      Navigator.pop(context); // กลับไปหน้าโปรไฟล์
    } catch (e) {
      debugPrint("❌ Error saving data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ เกิดข้อผิดพลาดในการบันทึกข้อมูล")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          "แก้ไขข้อมูลไรเดอร์",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 10),
              // 🔹 รูปโปรไฟล์
              Stack(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: const Color(0xFF4CAF50),
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (_imageUrl != null && _imageUrl!.isNotEmpty)
                            ? NetworkImage(_imageUrl!) as ImageProvider
                            : null,
                    child: (_selectedImage == null &&
                            (_imageUrl == null || _imageUrl!.isEmpty))
                        ? const Icon(Icons.person,
                            size: 60, color: Colors.white)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.green, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // 🔹 ช่องชื่อ
              TextField(
                controller: _nameController,
                decoration:
                    _inputDecoration(Icons.person_outline, "ชื่อ–นามสกุล"),
              ),
              const SizedBox(height: 15),

              // 🔹 ช่องเบอร์โทรศัพท์
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(Icons.phone, "เบอร์โทรศัพท์"),
              ),
              const SizedBox(height: 15),

              // 🔹 ช่องทะเบียนรถ
              TextField(
                controller: _plateController,
                decoration: _inputDecoration(Icons.motorcycle, "ทะเบียนรถ"),
              ),
              const SizedBox(height: 30),

              // 🔹 ปุ่มบันทึก / กลับ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(130, 45),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("กลับ",
                        style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(130, 45),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text("บันทึกข้อมูล",
                            style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon, String hint) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.green),
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.green, width: 1.3),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.green, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
