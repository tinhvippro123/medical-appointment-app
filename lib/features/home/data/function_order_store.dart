import 'package:shared_preferences/shared_preferences.dart';
import 'home_demo_data.dart';

class FunctionOrderStore {
  static const key = 'home_function_order_v1';
  Future<List<HealthService>> load() async {
    final saved =
        (await SharedPreferences.getInstance()).getStringList(key) ?? [];
    final remaining = {for (final item in homeServices) item.asset: item};
    final result = <HealthService>[];
    for (final id in saved) {
      final item = remaining.remove(id);
      if (item != null) result.add(item);
    }
    return [...result, ...remaining.values];
  }

  Future<void> save(List<HealthService> items) async {
    final success = await (await SharedPreferences.getInstance()).setStringList(
      key,
      items.map((item) => item.asset).toList(),
    );
    if (!success) throw StateError('Không lưu được thứ tự chức năng');
  }
}
