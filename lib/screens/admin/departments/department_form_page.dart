import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/upload_image_picker.dart';
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
  late final fee = TextEditingController(
    text: widget.department?.consultationFee != null
        ? widget.department!.consultationFee!.round().toString()
        : '',
  );
  late final description = TextEditingController(
    text: widget.department?.description,
  );
  late Department? saved = widget.department;
  UploadImage? image;
  String? error;
  bool busy = false, changed = false;
  @override
  void dispose() {
    name.dispose();
    fee.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _deleteCurrentImage() async {
    final dept = saved;
    if (dept == null || dept.imageUrl == null || dept.imageUrl!.isEmpty) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      saved = await widget.repository.deleteImage(dept.id);
      changed = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa ảnh chuyên khoa')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
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
      final parsedFee = double.parse(fee.text.trim());
      saved = await widget.repository.save(
        id: saved?.id,
        name: name.text.trim(),
        description: description.text.trim(),
        consultationFee: parsedFee,
        imageUrl: saved?.imageUrl,
      );
      changed = true;
      final selected = image;
      if (selected != null) {
        try {
          if (selected.url case final url?) {
            saved = await widget.repository.setImageUrl(saved!.id, url);
          } else {
            saved = await widget.repository.upload(
              saved!.id,
              selected.bytes!,
              selected.filename!,
            );
          }
        } catch (e) {
          throw DepartmentApiException(
            'Thông tin chuyên khoa đã lưu, nhưng chưa lưu được ảnh. Bạn có thể bấm Lưu để thử lại.\n$e',
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
  Widget build(BuildContext context) {
    final hasServerImage =
        saved?.id != null &&
        saved?.imageUrl != null &&
        saved!.imageUrl!.isNotEmpty &&
        image == null;
    return PopScope(
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
                  UploadImagePicker(
                    currentImageUrl: widget.repository.imageUrl(
                      saved?.imageUrl,
                    ),
                    selection: image,
                    enabled: !busy,
                    maxMegabytes: 5,
                    onChanged: (selection) => setState(() => image = selection),
                  ),
                  if (hasServerImage) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton.icon(
                        key: const ValueKey('department-delete-image-btn'),
                        onPressed: busy ? null : _deleteCurrentImage,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        label: const Text(
                          'Xóa ảnh hiện tại',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
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
                    key: const ValueKey('department-fee-field'),
                    controller: fee,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Phí khám (VNĐ) *',
                      hintText: 'Ví dụ: 150000',
                      suffixText: 'đ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final raw = value?.trim() ?? '';
                      if (raw.isEmpty) {
                        return 'Vui lòng nhập phí khám';
                      }
                      final parsed = double.tryParse(raw);
                      if (parsed == null || parsed <= 0) {
                        return 'Phí khám phải lớn hơn 0';
                      }
                      return null;
                    },
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
}
