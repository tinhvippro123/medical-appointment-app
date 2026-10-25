import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/home_demo_data.dart';
import '../../services/function_order_store.dart';
import 'widgets/home_sections.dart';

class FunctionOrderPage extends StatefulWidget {
  const FunctionOrderPage({super.key, required this.initialOrder});
  final List<HealthService> initialOrder;
  @override
  State<FunctionOrderPage> createState() => _FunctionOrderPageState();
}

class _FunctionOrderPageState extends State<FunctionOrderPage> {
  late List<HealthService> items = List.of(widget.initialOrder);
  bool saving = false;
  void move(HealthService item, int target) {
    final source = items.indexOf(item);
    if (source < 0 || source == target || saving) return;
    setState(() {
      items.removeAt(source);
      items.insert(target, item);
    });
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await FunctionOrderStore().save(items);
      if (mounted) Navigator.of(context).pop(List<HealthService>.of(items));
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không lưu được thay đổi. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      backgroundColor: const Color(0xfff0f3f9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff075bb5),
        title: const Text(
          'Sắp xếp chức năng',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Chức năng yêu thích',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff075bb5),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: saving
                            ? null
                            : () =>
                                  setState(() => items = List.of(homeServices)),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Cài đặt lại'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth <= 20) {
                        return const SizedBox.shrink();
                      }
                      final columns = constraints.maxWidth >= 650 ? 6 : 3;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 10) / columns;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 24,
                        children: [
                          for (var index = 0; index < items.length; index++)
                            SizedBox(
                              width: width,
                              child: DragTarget<HealthService>(
                                onWillAcceptWithDetails: (details) =>
                                    !saving && details.data != items[index],
                                onAcceptWithDetails: (details) =>
                                    move(details.data, index),
                                builder: (context, candidates, rejected) =>
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: candidates.isNotEmpty
                                            ? AppColors.light
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: candidates.isNotEmpty
                                              ? AppColors.primary
                                              : Colors.transparent,
                                        ),
                                      ),
                                      child: LongPressDraggable<HealthService>(
                                        data: items[index],
                                        maxSimultaneousDrags: saving ? 0 : 1,
                                        feedback: Material(
                                          color: Colors.transparent,
                                          elevation: 6,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          child: SizedBox(
                                            width: width,
                                            child: HealthcareServiceCard(
                                              service: items[index],
                                              onTap: () {},
                                            ),
                                          ),
                                        ),
                                        childWhenDragging: Opacity(
                                          opacity: .25,
                                          child: HealthcareServiceCard(
                                            service: items[index],
                                            onTap: () {},
                                          ),
                                        ),
                                        child: Semantics(
                                          hint: 'Nhấn giữ và kéo để đổi vị trí',
                                          onIncrease:
                                              index < items.length - 1 &&
                                                  !saving
                                              ? () => move(
                                                  items[index],
                                                  index + 1,
                                                )
                                              : null,
                                          onDecrease: index > 0 && !saving
                                              ? () => move(
                                                  items[index],
                                                  index - 1,
                                                )
                                              : null,
                                          child: HealthcareServiceCard(
                                            key: ValueKey(
                                              'reorder-${items[index].asset}',
                                            ),
                                            service: items[index],
                                            onTap: () {},
                                          ),
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xffbdd9e1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.light,
                          child: Icon(
                            Icons.touch_app_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hướng dẫn sắp xếp',
                                style: TextStyle(
                                  color: Color(0xff075bb5),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Nhấn giữ và kéo thả các chức năng để sắp xếp lại vị trí menu theo ý thích của bạn.',
                                style: TextStyle(height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: saving ? null : save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      saving ? 'Đang lưu...' : 'Lưu thay đổi',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
