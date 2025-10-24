import 'dart:io';
import 'package:flutter/material.dart';
import '../services/cloudinary_service.dart';

class PhotoUploader extends StatefulWidget {
  final Future<void> Function(String uploadedUrl) onUploaded;
  final String folder;
  final String buttonText;

  const PhotoUploader({
    super.key,
    required this.onUploaded,
    this.folder = 'shipments',
    this.buttonText = 'ถ่ายรูปหรือเลือกรูปเพื่ออัปโหลด',
  });

  @override
  State<PhotoUploader> createState() => _PhotoUploaderState();
}

class _PhotoUploaderState extends State<PhotoUploader> {
  File? _preview;
  bool _busy = false;

  /// 📸 ฟังก์ชันอัปโหลดรูป (กล้องหรือแกลเลอรี)
  Future<void> _uploadImage({required bool fromCamera}) async {
    try {
      setState(() => _busy = true);

      final url = await CloudinaryService.uploadImage(
        fromCamera: fromCamera,
        folder: widget.folder,
      );

      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ อัปโหลดไม่สำเร็จ')),
        );
        return;
      }

      await widget.onUploaded(url);

      setState(() {
        _preview = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ อัปโหลดสำเร็จ')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_preview != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _preview!,
                width: 220,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _busy ? null : () => _uploadImage(fromCamera: true),
              icon: const Icon(Icons.camera_alt),
              label: Text(_busy ? 'กำลังอัปโหลด...' : 'ถ่ายรูป'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _busy ? null : () => _uploadImage(fromCamera: false),
              icon: const Icon(Icons.photo_library),
              label: Text(_busy ? 'กำลังอัปโหลด...' : 'เลือกรูปจากแกลเลอรี'),
            ),
          ],
        ),
      ],
    );
  }
}
