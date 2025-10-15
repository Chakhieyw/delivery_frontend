import 'package:delivery_frontend/page/edit_profile_rider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 👈 สำหรับกรณี imageUrl เป็น path

class RiderProfilePage extends StatefulWidget {
  const RiderProfilePage({super.key});

  @override
  State<RiderProfilePage> createState() => _RiderProfilePageState();
}

class _RiderProfilePageState extends State<RiderProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? name;
  String? phone;
  String? plate;
  String? imageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRiderData();
  }

  /// แปลง path -> URL (ในกรณีที่ Firestore เก็บเป็น path)
  Future<String?> _normalizeImageUrl(String? raw) async {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http')) return s;
    try {
      final ref = FirebaseStorage.instance.ref(s);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('❌ Error getDownloadURL: $e');
      return null;
    }
  }

  Future<void> fetchRiderData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snap = await _firestore.collection('riders').doc(user.uid).get();
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final rawImage = (data['imageUrl'] ??
          data['photo'] ??
          data['profileImage']) as String?;

      final normalizedUrl = await _normalizeImageUrl(rawImage);

      setState(() {
        name = (data['name'] as String?)?.trim();
        phone = (data['phone'] as String?)?.trim();
        plate = (data['plate'] as String?)?.trim();
        imageUrl = normalizedUrl;
        _isLoading = false;
      });

      debugPrint("🖼 imageUrl(final): $imageUrl");
    } catch (e) {
      debugPrint("⚠️ Error fetching rider data: $e");
      setState(() => _isLoading = false);
    }
  }

  /// วิดเจ็ตแสดงรูปโปรไฟล์ ป้องกัน crash
  Widget _buildAvatar() {
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    if (hasImage) {
      // ✅ มีรูปภาพ
      return CircleAvatar(
        key: ValueKey(imageUrl),
        radius: 50,
        backgroundColor: const Color(0xFF4CAF50),
        backgroundImage: NetworkImage(imageUrl!),
        onBackgroundImageError: (error, stackTrace) {
          debugPrint("⚠️ โหลดรูปไม่ได้: $error");
          if (mounted) setState(() => imageUrl = null);
        },
      );
    } else {
      // ✅ ไม่มีรูปภาพ
      return const CircleAvatar(
        radius: 50,
        backgroundColor: Color(0xFF4CAF50),
        child: Icon(Icons.person, color: Colors.white, size: 60),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          "โปรไฟล์ไรเดอร์",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 🔹 รูปโปรไฟล์
                    _buildAvatar(),
                    const SizedBox(height: 15),
                    Text(
                      name ?? 'ไม่ระบุชื่อ',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 2,
                      color: const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          phone ?? '-',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.motorcycle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          plate ?? '-',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    TextButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditProfileRiderPage()),
                        );
                        fetchRiderData(); // รีเฟรชหลังกลับมา
                      },
                      icon: const Icon(Icons.edit, color: Colors.green),
                      label: const Text(
                        "แก้ไขข้อมูล",
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Delivery AppT&K © 2025",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
