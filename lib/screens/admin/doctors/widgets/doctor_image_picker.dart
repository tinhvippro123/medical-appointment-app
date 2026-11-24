import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';

class DoctorImagePicker extends StatefulWidget {
  const DoctorImagePicker({
    super.key,
    this.currentImageUrl,
    required this.onImageSelected,
  });

  final String? currentImageUrl;
  final ValueChanged<XFile?> onImageSelected;

  @override
  State<DoctorImagePicker> createState() => _DoctorImagePickerState();
}

class _DoctorImagePickerState extends State<DoctorImagePicker> {
  final _picker = ImagePicker();
  XFile? _pickedFile;
  Uint8List? _previewBytes;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _pickedFile = file;
          _previewBytes = bytes;
        });
        widget.onImageSelected(file);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể chọn ảnh từ thiết bị.'),
            backgroundColor: Color(0xffef4444),
          ),
        );
      }
    }
  }

  void _clear() {
    setState(() {
      _pickedFile = null;
      _previewBytes = null;
    });
    widget.onImageSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (_previewBytes != null) {
      imageWidget = Image.memory(_previewBytes!, fit: BoxFit.cover);
    } else if (widget.currentImageUrl != null &&
        widget.currentImageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        widget.currentImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.person_rounded,
          size: 50,
          color: AppColors.muted,
        ),
      );
    } else {
      imageWidget = const Icon(
        Icons.add_a_photo_outlined,
        size: 38,
        color: AppColors.primary,
      );
    }

    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.light,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade100, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: imageWidget,
                ),
              ),
              if (_pickedFile != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: IconButton(
                    onPressed: _clear,
                    icon: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                    ),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('pick-gallery-button'),
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 16),
              label: const Text('Thư viện', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const ValueKey('pick-camera-button'),
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 16),
              label: const Text('Chụp ảnh', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
