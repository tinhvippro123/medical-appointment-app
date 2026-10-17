import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/home_demo_data.dart';
import 'home_sections.dart';
import '../../data/function_order_store.dart';
import '../function_order_page.dart';

class HealthcareFunctionsPanel extends StatefulWidget {
  const HealthcareFunctionsPanel({super.key, required this.onSelected});
  final ValueChanged<HealthService> onSelected;
  @override
  State<HealthcareFunctionsPanel> createState() =>
      _HealthcareFunctionsPanelState();
}

class _HealthcareFunctionsPanelState extends State<HealthcareFunctionsPanel> {
  final controller = TextEditingController();
  bool searching = false;
  String query = '';
  List<HealthService> orderedServices = List.of(homeServices);
  bool loaded = false;
  @override
  void initState() {
    super.initState();
    loadOrder();
  }

  Future<void> loadOrder() async {
    try {
      final items = await FunctionOrderStore().load();
      if (mounted) {
        setState(() {
          orderedServices = items;
          loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loaded = true);
    }
  }

  Future<void> openOrder() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push<List<HealthService>>(
      MaterialPageRoute(
        builder: (_) => FunctionOrderPage(initialOrder: orderedServices),
      ),
    );
    if (result != null && mounted) setState(() => orderedServices = result);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String normalize(String value) {
    var result = value.toLowerCase().replaceAll('\n', ' ').replaceAll('đ', 'd');
    const groups = [
      'àáạảãâầấậẩẫăằắặẳẵ',
      'èéẹẻẽêềếệểễ',
      'ìíịỉĩ',
      'òóọỏõôồốộổỗơờớợởỡ',
      'ùúụủũưừứựửữ',
      'ỳýỵỷỹ',
    ];
    const replacements = ['a', 'e', 'i', 'o', 'u', 'y'];
    for (var i = 0; i < groups.length; i++) {
      for (final rune in groups[i].runes) {
        result = result.replaceAll(String.fromCharCode(rune), replacements[i]);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final services = orderedServices
        .where(
          (service) =>
              normalize(service.title).contains(normalize(query.trim())),
        )
        .toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffdff5ff), Color(0xfff5fbff), Colors.white],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Chức năng',
                  style: TextStyle(
                    color: Color(0xff125bb5),
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Sắp xếp chức năng',
                      onPressed: loaded ? openOrder : null,
                      icon: const Icon(
                        Icons.tune_rounded,
                        color: Color(0xff125bb5),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: const Color(0xffb5d6ed),
                    ),
                    IconButton(
                      tooltip: searching
                          ? 'Đóng tìm kiếm'
                          : 'Tìm kiếm chức năng',
                      icon: Icon(
                        searching ? Icons.close_rounded : Icons.search_rounded,
                        color: const Color(0xff125bb5),
                      ),
                      onPressed: () => setState(() {
                        searching = !searching;
                        if (!searching) {
                          query = '';
                          controller.clear();
                        }
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (searching)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  hintText: 'Tìm chức năng...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xffbdd9ec)),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (services.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Không tìm thấy chức năng phù hợp.',
                textAlign: TextAlign.center,
              ),
            )
          else
            HealthcareServiceGrid(
              services: services,
              onSelected: widget.onSelected,
            ),
        ],
      ),
    );
  }
}
