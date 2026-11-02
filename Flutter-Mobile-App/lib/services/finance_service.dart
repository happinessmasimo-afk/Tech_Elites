import '../models/finance_summary.dart';
import 'api_client.dart';

class FinanceService {
  final ApiClient _api = ApiClient();

  Future<FinanceSummary> getSummary() async {
    final data = await _api.get('/api/finance/summary');
    return FinanceSummary.fromJson(data as Map<String, dynamic>);
  }
}
