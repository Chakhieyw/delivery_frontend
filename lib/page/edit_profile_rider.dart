import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cloudinary_service.dart';

class EditRiderProfilePage extends StatefulWidget {
  const EditRiderProfilePage({super.key});

  @override
  State<EditRiderProfilePage> createState() => _EditRiderProfilePageState();
}

class _EditRiderProfilePageState extends State<EditRiderProfilePage> {
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _plateCtl = TextEditingController();
  String? _imageUrl;
  File? _imageFile;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await _firestore.collection('riders').doc(user.uid).get();
    if (doc.exists) {
      setState(() {
        _nameCtl.text = doc['name'];
        _phoneCtl.text = doc['phone'];
        _plateCtl.text = doc['plate'];
        _imageUrl = doc['imageUrl'];
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    final user = _auth.currentUser;
    if (user == null) return;

    String? newUrl = _imageUrl;
    if (_imageFile != null) {
      newUrl = await CloudinaryService.uploadImage(
        fromCamera: false,
        folder: "profiles",
      );
    }

    await _firestore.collection('riders').doc(user.uid).update({
      "name": _nameCtl.text.trim(),
      "phone": _phoneCtl.text.trim(),
      "plate": _plateCtl.text.trim(),
      "imageUrl": newUrl ?? "",
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ อัปเดตโปรไฟล์เรียบร้อย")),
    );

    Navigator.pop(context);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("แก้ไขโปรไฟล์ Rider")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green.shade100,
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : (_imageUrl != null && _imageUrl!.isNotEmpty)
                        ? NetworkImage(_imageUrl!) as ImageProvider
                        : null,
                child: (_imageUrl == null || _imageUrl!.isEmpty) &&
                        _imageFile == null
                    ? const Icon(Icons.person, size: 55, color: Colors.green)
                    : null,
              ),
            ),
            const SizedBox(height: 15),
            _buildField(_nameCtl, "ชื่อ Rider", Icons.person),
            _buildField(_phoneCtl, "เบอร์โทรศัพท์", Icons.phone),
            _buildField(_plateCtl, "ทะเบียนรถ", Icons.directions_bike),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("บันทึกการแก้ไข"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctl, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: ctl,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.green),
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
        ),
      ),
    );
  }
}
