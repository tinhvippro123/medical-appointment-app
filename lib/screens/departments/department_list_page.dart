import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/department.dart';
import '../../models/order.dart';
import '../../models/patient_profile.dart';
import '../../repositories/department_repository.dart';
import '../booking/booking_date_page.dart';

class DepartmentListPage extends StatefulWidget {
  const DepartmentListPage({super.key, this.repository, this.patient});

  final DepartmentRepository? repository;
  final PatientProfile? patient;

  @override
  State<DepartmentListPage> createState() => _DepartmentListPageState();
}

class _DepartmentListPageState extends State<DepartmentListPage> {
  late final _repository = widget.repository ?? DepartmentRepository();
  late Future<List<Department>> _departments = _repository.list();

  void _openDepartment(Department department) {
    final navigator = Navigator.of(context);
    final patient = widget.patient;
    if (patient == null) {
      navigator.pushNamed('/doctors', arguments: department);
      return;
    }
    navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            BookingDatePage(department: department, patient: patient),
      ),
    );
  }

  Future<void> _reload() async {
    final request = _repository.list();
    setState(() {
      _departments = request;
    });
    try {
      await request;
    } catch (_) {
      // FutureBuilder displays the error and offers a retry.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.patient == null ? 'Danh sách chuyên khoa' : 'Chọn chuyên khoa',
      ),
    ),
    body: FutureBuilder<List<Department>>(
      future: _departments,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const <Department>[];
        if (snapshot.hasError || items.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    snapshot.hasError
                        ? Icons.cloud_off_outlined
                        : Icons.local_hospital_outlined,
                    size: 48,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.hasError
                        ? 'Không tải được danh sách chuyên khoa.'
                        : 'Chưa có chuyên khoa.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _reload,
                    child: Text(snapshot.hasError ? 'Thử lại' : 'Tải lại'),
                  ),
                ],
              ),
            ),
          );
        }
        final textScaler = MediaQuery.textScalerOf(context);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: RefreshIndicator(
              onRefresh: _reload,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: textScaler.scale(240),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 146 + textScaler.scale(18) * 5,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final department = items[index];
                  return _DepartmentCard(
                    name: department.name,
                    imageUrl: _repository.imageUrl(department.imageUrl),
                    consultationFee: department.consultationFee,
                    onTap: () => _openDepartment(department),
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.name,
    required this.imageUrl,
    required this.consultationFee,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final double? consultationFee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const placeholder = Center(
      child: Icon(
        Icons.local_hospital_outlined,
        size: 36,
        color: AppColors.primary,
      ),
    );
    final url = imageUrl;
    final fee = consultationFee;
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xffdce9f5)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Ink(
              height: 116,
              color: AppColors.light,
              child: url == null
                  ? placeholder
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                    Text(
                      fee == null
                          ? 'Phí khám chưa cập nhật'
                          : 'Phí khám: ${Order.formatMoney(fee)}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.dark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
