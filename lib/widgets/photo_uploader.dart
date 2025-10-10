import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';

class PhotoUploader extends StatefulWidget {
  final Future<void> Function(String uploadedUrl) onUploaded;
  final String folder;
  final String buttonText;

  const PhotoUploader({
    super.key,
    required this.onUploaded,
    this.folder = 'shipments',
    this.buttonText = 'ถ่ายรูปและอัปโหลด',
  });

  @override
  State<PhotoUploader> createState() => _PhotoUploaderState();
}

class _PhotoUploaderState extends State<PhotoUploader> {
  final _picker = ImagePicker();
  File? _preview;
  bool _busy = false;

  Future<void> _takeAndUpload() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _preview = File(picked.path));
      setState(() => _busy = true);

      final url = await CloudinaryService().uploadFile(
        _preview!,
        folder: widget.folder,
      );
      await widget.onUploaded(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดสำเร็จ ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_preview!, width: 220),
          ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _busy ? null : _takeAndUpload,
          icon: const Icon(Icons.camera_alt),
          label: Text(_busy ? 'กำลังอัปโหลด...' : widget.buttonText),
        ),
      ],
    );
  }
}
