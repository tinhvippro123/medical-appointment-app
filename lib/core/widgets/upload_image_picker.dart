import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';

class UploadImage {
  const UploadImage.file(Uint8List data, String name)
    : bytes = data,
      filename = name,
      url = null;
  const UploadImage.url(String address)
    : bytes = null,
      filename = null,
      url = address;

  final Uint8List? bytes;
  final String? filename;
  final String? url;
}

enum _ImageOption { camera, gallery, url }

class UploadImagePicker extends StatefulWidget {
  const UploadImagePicker({
    super.key,
    this.currentImageUrl,
    this.selection,
    required this.onChanged,
    required this.maxMegabytes,
    this.allowWebp = false,
    this.enabled = true,
  });

  final String? currentImageUrl;
  final UploadImage? selection;
  final ValueChanged<UploadImage?> onChanged;
  final int maxMegabytes;
  final bool allowWebp;
  final bool enabled;

  @override
  State<UploadImagePicker> createState() => _UploadImagePickerState();
}

class _UploadImagePickerState extends State<UploadImagePicker> {
  bool _picking = false;

  Future<void> _chooseImage() async {
    setState(() => _picking = true);
    try {
      final option = await showModalBottomSheet<_ImageOption>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Chụp ảnh'),
                onTap: () => Navigator.pop(context, _ImageOption.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Chọn từ thư viện'),
                onTap: () => Navigator.pop(context, _ImageOption.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Nhập URL ảnh'),
                onTap: () => Navigator.pop(context, _ImageOption.url),
              ),
            ],
          ),
        ),
      );
      if (option == null || !mounted || !widget.enabled) return;
      if (option == _ImageOption.url) {
        final url = await showDialog<String>(
          context: context,
          builder: (_) => const _ImageUrlDialog(),
        );
        if (url != null && mounted && widget.enabled) {
          widget.onChanged(UploadImage.url(url));
        }
        return;
      }

      final file = await ImagePicker().pickImage(
        source: option == _ImageOption.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null || !mounted || !widget.enabled) return;
      final extension = file.name.split('.').last.toLowerCase();
      final allowed = ['jpg', 'jpeg', 'png', if (widget.allowWebp) 'webp'];
      if (!allowed.contains(extension)) {
        _showMessage('Chỉ hỗ trợ ảnh ${allowed.join(', ').toUpperCase()}.');
        return;
      }
      final size = await file.length();
      if (!mounted || !widget.enabled) return;
      if (size == 0 || size > widget.maxMegabytes * 1024 * 1024) {
        _showMessage(
          'Ảnh phải có nội dung và không quá ${widget.maxMegabytes} MB.',
        );
        return;
      }
      final bytes = await file.readAsBytes();
      if (mounted && widget.enabled) {
        widget.onChanged(UploadImage.file(bytes, file.name));
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Không thể chọn ảnh. Hãy kiểm tra quyền thư viện hoặc camera.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final bytes = widget.selection?.bytes;
    final url = widget.selection?.url ?? widget.currentImageUrl;
    final canChoose = widget.enabled && !_picking;
    Widget preview = const Icon(
      Icons.add_photo_alternate_outlined,
      color: AppColors.primary,
      size: 36,
    );
    if (bytes != null) {
      preview = Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    } else if (url != null && url.isNotEmpty) {
      preview = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    }
    return Column(
      children: [
        Container(
          width: 144,
          height: 128,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.light,
            borderRadius: BorderRadius.circular(16),
          ),
          child: preview,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: canChoose ? _chooseImage : null,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Chọn ảnh'),
            ),
            if (widget.selection != null)
              TextButton(
                onPressed: canChoose ? () => widget.onChanged(null) : null,
                child: const Text('Bỏ ảnh vừa chọn'),
              ),
          ],
        ),
        Text(
          'JPG, PNG${widget.allowWebp ? ', WebP' : ''} • Tối đa ${widget.maxMegabytes} MB',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ImageUrlDialog extends StatefulWidget {
  const _ImageUrlDialog();

  @override
  State<_ImageUrlDialog> createState() => _ImageUrlDialogState();
}

class _ImageUrlDialogState extends State<_ImageUrlDialog> {
  String _input = '';
  String? _previewUrl;
  String? _error;
  bool _loading = false;

  Future<void> _preview() async {
    final url = _input.trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      setState(() => _error = 'Nhập đường dẫn ảnh HTTP hoặc HTTPS hợp lệ.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _previewUrl = null;
    });
    var failed = false;
    try {
      await precacheImage(
        NetworkImage(url),
        context,
        onError: (_, _) => failed = true,
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (failed) {
        _error = 'Không tải được ảnh. Hãy kiểm tra lại đường dẫn.';
      } else {
        _previewUrl = url;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nhập URL ảnh'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          autofocus: true,
          enabled: !_loading,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'URL ảnh',
            hintText: 'https://',
            errorText: _error,
            errorMaxLines: 3,
          ),
          onChanged: (value) => setState(() {
            _input = value;
            _previewUrl = null;
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        if (_loading) const CircularProgressIndicator(),
        if (_previewUrl case final url?)
          Image.network(url, height: 140, fit: BoxFit.contain),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      TextButton(
        onPressed: _loading ? null : _preview,
        child: const Text('Xem trước'),
      ),
      FilledButton(
        onPressed: _previewUrl == null
            ? null
            : () => Navigator.pop(context, _previewUrl),
        child: const Text('Dùng ảnh'),
      ),
    ],
  );
}
