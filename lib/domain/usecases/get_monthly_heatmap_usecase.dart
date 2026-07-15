import '../repositories/report_repository.dart';

/// Usecase to retrieve monthly aggregated Heat Map data.
class GetMonthlyHeatMapUseCase {
  final ReportRepository repository;

  GetMonthlyHeatMapUseCase(this.repository);

  /// Executes the monthly heat map queries.
  Future<List<HeatMapPoint>> call({required int year, required int month}) {
    if (month < 1 || month > 12) {
      throw ArgumentError('Month must be between 1 and 12.');
    }
    return repository.getMonthlyHeatMapData(year: year, month: month);
  }
}
