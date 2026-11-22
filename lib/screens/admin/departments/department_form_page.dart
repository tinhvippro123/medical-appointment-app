import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/department.dart';
import '../../../repositories/department_repository.dart';

class DepartmentFormPage extends StatefulWidget {
  const DepartmentFormPage({
    super.key,
    required this.repository,
    this.department,
  });
  final DepartmentRepository repository;
  final Department? department;
  @override
  State<DepartmentFormPage> createState() => _DepartmentFormPageState();
}

class _DepartmentFormPageState extends State<DepartmentFormPage> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.department?.name);
  late final description = TextEditingController(
    text: widget.department?.description,
  );
  late Department? saved = widget.department;
  Uint8List? image;
  String? filename;
  String? error;
  bool busy = false, changed = false;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file == null) return;
      final ext = file.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(ext)) {
        throw const DepartmentApiException('Vui lòng chọn ảnh JPG hoặc PNG.');
      }
      if (await file.length() > 5 * 1024 * 1024) {
        throw const DepartmentApiException('Ảnh phải nhỏ hơn hoặc bằng 5 MB.');
      }
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          image = bytes;
          filename = file.name;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is DepartmentApiException
              ? e.message
              : 'Không mở được ảnh. Kiểm tra quyền truy cập ảnh/camera.',
        );
      }
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      saved = await widget.repository.save(
        id: saved?.id,
        name: name.text.trim(),
        description: description.text.trim(),
        imageUrl: saved?.imageUrl,
      );
      changed = true;
      if (image != null) {
        try {
          saved = await widget.repository.upload(saved!.id, image!, filename!);
        } catch (e) {
          throw DepartmentApiException(
            'Thông tin chuyên khoa đã lưu, nhưng upload ảnh thất bại. Bạn có thể bấm Lưu để thử lại.\n$e',
          );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && !changed,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !busy) Navigator.pop(context, changed);
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.department == null ? 'Thêm chuyên khoa' : 'Sửa chuyên khoa',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  height: 180,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xffeaf5ff),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: image != null
                      ? Image.memory(image!, fit: BoxFit.cover)
                      : widget.repository.imageUrl(saved?.imageUrl) != null
                      ? Image.network(
                          widget.repository.imageUrl(saved?.imageUrl)!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: Colors.blueGrey,
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 48,
                              color: Colors.blue,
                            ),
                            SizedBox(height: 8),
                            Text('Ảnh chuyên khoa'),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy ? null : pick,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Chọn ảnh / Chụp ảnh'),
                ),
                const Text(
                  'JPG, PNG • Tối đa 5 MB',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: name,
                  enabled: !busy,
                  maxLength: 200,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tên chuyên khoa *',
                    hintText: 'Ví dụ: Nội tổng quát',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập tên chuyên khoa'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: description,
                  enabled: !busy,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: busy ? null : save,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(busy ? 'Đang lưu...' : 'Lưu chuyên khoa'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
