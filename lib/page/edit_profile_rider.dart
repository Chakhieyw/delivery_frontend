import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileRiderPage extends StatefulWidget {
  const EditProfileRiderPage({super.key});

  @override
  State<EditProfileRiderPage> createState() => _EditProfileRiderPageState();
}

class _EditProfileRiderPageState extends State<EditProfileRiderPage> {
  File? _imageFile;
  bool _loading = false;
  final picker = ImagePicker();

  // ✅ กำหนดค่าของ Cloudinary
  final String cloudName = "YOUR_CLOUD_NAME"; // 🔹 ใส่ cloud name จริง
  final String uploadPreset = "delivery_unsigned"; // 🔹 ใส่ preset ที่สร้างไว้

  // ✅ เลือกรูปจากคลังภาพ
  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  // ✅ อัปโหลดรูปขึ้น Cloudinary และบันทึก Firestore
  Future<void> _uploadToCloudinary() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาเลือกรูปก่อน")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final url =
          Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files
            .add(await http.MultipartFile.fromPath('file', _imageFile!.path));

      final response = await request.send();
      final res = await http.Response.fromStream(response);
      final data = json.decode(res.body);

      if (response.statusCode == 200) {
        final imageUrl = data['secure_url'];

        // ✅ บันทึก URL ลง Firestore
        await FirebaseFirestore.instance
            .collection('riders')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({'imageUrl': imageUrl});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("อัปโหลดสำเร็จ ✅")),
        );

        Navigator.pop(context); // 🔹 กลับไปหน้าโปรไฟล์
      } else {
        debugPrint("❌ Upload failed: ${res.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("อัปโหลดไม่สำเร็จ ❌")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("แก้ไขโปรไฟล์ไรเดอร์"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _imageFile != null
                ? CircleAvatar(
                    radius: 70, backgroundImage: FileImage(_imageFile!))
                : const CircleAvatar(
                    radius: 70,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 70, color: Colors.white),
                  ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text("เลือกรูปจากเครื่อง"),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600),
                    onPressed: _uploadToCloudinary,
                    icon: const Icon(Icons.cloud_upload, color: Colors.white),
                    label: const Text(
                      "อัปโหลดขึ้น Cloudinary",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
