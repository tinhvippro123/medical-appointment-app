import 'package:flutter/material.dart';
import '../../../models/department.dart';
import '../../../models/order.dart';
import '../../../repositories/department_repository.dart';
import 'department_form_page.dart';

class DepartmentAdminPage extends StatefulWidget {
  const DepartmentAdminPage({super.key, this.repository});
  final DepartmentRepository? repository;
  @override
  State<DepartmentAdminPage> createState() => _DepartmentAdminPageState();
}

class _DepartmentAdminPageState extends State<DepartmentAdminPage> {
  late final repository = widget.repository ?? DepartmentRepository();
  late Future<List<Department>> departments;
  final deleting = <int>{};
  @override
  void initState() {
    super.initState();
    departments = repository.list();
  }

  Future<void> refresh() async {
    final result = repository.list();
    setState(() {
      departments = result;
    });
    try {
      await result;
    } catch (_) {}
  }

  Future<void> edit([Department? item]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            DepartmentFormPage(repository: repository, department: item),
      ),
    );
    if (changed == true && mounted) await refresh();
  }

  Future<void> remove(Department item) async {
    if (deleting.contains(item.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa chuyên khoa?'),
        content: Text('Bạn có chắc muốn xóa chuyên khoa “${item.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => deleting.add(item.id));
    try {
      await repository.delete(item.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa chuyên khoa')));
        await refresh();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => deleting.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quản lý chuyên khoa'),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(),
      icon: const Icon(Icons.add),
      label: const Text('Thêm chuyên khoa'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: FutureBuilder<List<Department>>(
          future: departments,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 48),
                      const SizedBox(height: 16),
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      TextButton(
                        onPressed: refresh,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final items = snapshot.data ?? [];
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    'CHUYÊN KHOA • ${items.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xff1677e8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_hospital_outlined,
                            size: 56,
                            color: Colors.blueGrey,
                          ),
                          SizedBox(height: 16),
                          Text('Chưa có chuyên khoa'),
                          SizedBox(height: 8),
                          Text('Nhấn + để thêm chuyên khoa đầu tiên.'),
                        ],
                      ),
                    ),
                  for (final item in items)
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: deleting.contains(item.id)
                            ? null
                            : () => edit(item),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: ColoredBox(
                                    color: const Color(0xffeaf5ff),
                                    child:
                                        repository.imageUrl(item.imageUrl) ==
                                            null
                                        ? const Icon(
                                            Icons.local_hospital_outlined,
                                            color: Colors.blue,
                                          )
                                        : Image.network(
                                            repository.imageUrl(item.imageUrl)!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, error, stack) =>
                                                const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.blueGrey,
                                                ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (item.consultationFee != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Phí khám: ${Order.formatMoney(item.consultationFee!)}',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xff1677e8),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      item.description?.isNotEmpty == true
                                          ? item.description!
                                          : 'Chưa có mô tả',
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.blueGrey,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (deleting.contains(item.id))
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                IconButton(
                                  tooltip: 'Xóa ${item.name}',
                                  onPressed: () => remove(item),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
