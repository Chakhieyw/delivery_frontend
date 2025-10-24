import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

/// 🌤️ บริการอัปโหลดรูปขึ้น Cloudinary (ใช้ preset เดียว: delivery_upload)
class CloudinaryService {
  static const String cloudName = "dwew1qkvb"; // 👈 Cloud ของก้องภพ
  static const String uploadPreset =
      "delivery_upload"; // 👈 ใช้ preset เดียวเท่านั้น

  /// ✅ อัปโหลดรูปขึ้น Cloudinary
  /// [fromCamera] = true จะเปิดกล้อง, false จะเปิดแกลเลอรี
  /// [file] = ถ้ามีไฟล์ที่เลือกมาแล้ว จะใช้ไฟล์นั้นโดยไม่เปิด picker ซ้ำ
  /// [folder] = โฟลเดอร์ใน Cloudinary เช่น "profiles" / "riders"
  static Future<String?> uploadImage({
    bool fromCamera = true,
    File? file,
    String? folder,
  }) async {
    try {
      File? uploadFile = file;

      // 🔹 ถ้ายังไม่มีไฟล์ ให้เปิด picker (รองรับทั้งกล้องและแกลเลอรี)
      if (uploadFile == null) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 80,
        );
        if (picked == null) return null;
        uploadFile = File(picked.path);
      }

      final uri =
          Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', uploadFile.path));

      // 👇 ถ้ามี folder ให้เพิ่ม field 'folder'
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200 && response.statusCode != 201) {
        print("❌ Upload failed: ${response.statusCode}");
        print(body);
        return null;
      }

      final data = jsonDecode(body);
      print("✅ Uploaded to Cloudinary: ${data['secure_url']}");
      return data['secure_url'];
    } catch (e) {
      print("⚠️ Cloudinary upload error: $e");
      return null;
    }
  }
}
