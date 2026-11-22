import 'package:flutter/material.dart';
import '../../repositories/cart_repository.dart';

String _money(double value) =>
    '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} đ';
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    this.repository,
    this.onBrowseDoctors,
    this.onCheckout,
    this.preview = false,
  });
  final CartRepository? repository;
  final VoidCallback? onBrowseDoctors;
  final ValueChanged<List<CartItem>>? onCheckout;
  final bool preview;
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late final repo = widget.repository ?? CartRepository();
  List<CartItem> items = [];
  bool loading = true, updating = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await repo.list();
      if (mounted) setState(() => items = result);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> remove(CartItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa lịch hẹn?'),
        content: Text(
          'Bạn có chắc muốn xóa lịch khám của ${item.patient} với ${item.doctor}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => updating = true);
    try {
      await repo.delete(item.id);
      if (mounted) {
        setState(() => items.removeWhere((e) => e.id == item.id));
        message('Đã xóa lịch hẹn');
      }
    } catch (e) {
      if (mounted) message('$e');
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  Future<void> edit(CartItem item) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _EditAppointment(item: item, repo: repo),
      ),
    );
    if (result == true && mounted) await load();
  }

  void browse() {
    if (widget.onBrowseDoctors != null) {
      widget.onBrowseDoctors!();
    } else {
      message('Danh sách bác sĩ đang được phát triển.');
    }
  }

  void checkout() {
    if (widget.onCheckout != null) {
      widget.onCheckout!(List.unmodifiable(items));
    } else {
      message('Chức năng đặt lịch đang được phát triển.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.preview ? 'Giỏ hàng · Xem thử' : 'Giỏ hàng lịch hẹn'),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: loading || updating ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 48,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(height: 12),
                      Text(error!, textAlign: TextAlign.center),
                      TextButton(onPressed: load, child: const Text('Thử lại')),
                    ],
                  ),
                ),
              )
            : items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.event_busy_outlined,
                      size: 64,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chưa có lịch hẹn nào',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: browse,
                      child: const Text('Xem bác sĩ'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final url = repo.imageUrl(item.avatar);
                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: updating ? null : () => edit(item),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 58,
                                      height: 58,
                                      child: ColoredBox(
                                        color: const Color(0xffeaf5ff),
                                        child: url == null
                                            ? const Icon(
                                                Icons.person_outline,
                                                color: Colors.blue,
                                              )
                                            : Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (_, error, stack) =>
                                                        const Icon(
                                                          Icons.person_outline,
                                                          color: Colors.blue,
                                                        ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.doctor,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.department,
                                          style: const TextStyle(
                                            color: Colors.blue,
                                          ),
                                        ),
                                        if (!item.active)
                                          const Text(
                                            'Bác sĩ hiện không hoạt động',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Xóa lịch hẹn',
                                    onPressed: updating
                                        ? null
                                        : () => remove(item),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _line(
                                Icons.calendar_today_outlined,
                                '${_date(item.date)} • ${item.slot}',
                              ),
                              const SizedBox(height: 8),
                              _line(
                                Icons.person_outline,
                                'Người khám: ${item.patient}',
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    _money(item.fee),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xff126bd1),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.edit_calendar_outlined,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Đổi ngày giờ',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    ),
    bottomNavigationBar: !loading && error == null && items.isNotEmpty
        ? SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .06),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Tổng tiền', style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      Text(
                        _money(items.fold(0.0, (sum, e) => sum + e.fee)),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff126bd1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: updating ? null : checkout,
                      child: const Text('Đặt lịch'),
                    ),
                  ),
                ],
              ),
            ),
          )
        : null,
  );
  Widget _line(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 18, color: Colors.blueGrey),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}

class _EditAppointment extends StatefulWidget {
  const _EditAppointment({required this.item, required this.repo});
  final CartItem item;
  final CartRepository repo;
  @override
  State<_EditAppointment> createState() => _EditAppointmentState();
}

class _EditAppointmentState extends State<_EditAppointment> {
  late DateTime date = widget.item.date;
  String? slot;
  late Future<List<Schedule>> schedules;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    schedules = widget.repo.schedules(widget.item.doctorId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đổi ngày giờ khám')),
    body: FutureBuilder<List<Schedule>>(
      future: schedules,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${snapshot.error}', textAlign: TextAlign.center),
                TextButton(
                  onPressed: () {
                    setState(() {
                      schedules = widget.repo.schedules(widget.item.doctorId);
                    });
                  },
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        final currentDay = date.weekday % 7;
        final available =
            snapshot.data!
                .where((s) => s.day == currentDay)
                .map((s) => s.slot)
                .toSet()
                .toList()
              ..sort();
        final now = DateTime.now();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.item.doctor,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(widget.item.department),
            const SizedBox(height: 24),
            const Text(
              'Ngày khám',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final today = DateUtils.dateOnly(DateTime.now());
                      final chosen = await showDatePicker(
                        context: context,
                        initialDate: date.isBefore(today) ? today : date,
                        firstDate: today,
                        lastDate: today.add(const Duration(days: 365)),
                      );
                      if (chosen != null) {
                        setState(() {
                          date = chosen;
                          slot = null;
                        });
                      }
                    },
              icon: const Icon(Icons.calendar_month),
              label: Text(_date(date)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Khung giờ theo lịch bác sĩ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (available.isEmpty)
              const Text('Bác sĩ không có lịch làm việc vào ngày này.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in available)
                    ChoiceChip(
                      label: Text(value),
                      selected: slot == value,
                      onSelected: saving
                          ? null
                          : (_) => setState(() => slot = value),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed:
                  saving ||
                      slot == null ||
                      date.isBefore(DateUtils.dateOnly(now))
                  ? null
                  : () async {
                      setState(() => saving = true);
                      try {
                        await widget.repo.update(widget.item, date, slot!);
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      } finally {
                        if (mounted) setState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi'),
            ),
          ],
        );
      },
    ),
  );
}
