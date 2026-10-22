import '../../../core/constants/task_log_status.dart';

enum ActivityFilter {
  all('Todas', null),
  pending('Pendientes', TaskLogStatus.pending),
  approved('Aprobadas', TaskLogStatus.approved),
  rejected('Rechazadas', TaskLogStatus.rejected);

  const ActivityFilter(this.label, this.status);
  final String label;
  final TaskLogStatus? status;
}
