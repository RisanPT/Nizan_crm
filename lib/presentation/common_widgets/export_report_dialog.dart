import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import '../../core/utils/export_utils.dart';

class ExportReportDialog<T> extends HookWidget {
  final String title;
  final List<T> items;
  final String? Function(T) getVehicleName;
  final String? Function(T) getDriverName;
  final List<String> headers;
  final List<String> Function(T) buildRow;
  
  const ExportReportDialog({
    super.key,
    required this.title,
    required this.items,
    required this.getVehicleName,
    required this.getDriverName,
    required this.headers,
    required this.buildRow,
  });

  @override
  Widget build(BuildContext context) {
    final selectedVehicle = useState<String?>(null);
    final selectedDriver = useState<String?>(null);
    final isExporting = useState(false);

    // Get unique vehicles and drivers for filters
    final vehicles = items.map((e) => getVehicleName(e)).whereType<String>().toSet().toList()..sort();
    final drivers = items.map((e) => getDriverName(e)).whereType<String>().toSet().toList()..sort();

    Future<void> handleExport(bool isPdf) async {
      isExporting.value = true;
      try {
        final filteredItems = items.where((item) {
          if (selectedVehicle.value != null && getVehicleName(item) != selectedVehicle.value) return false;
          if (selectedDriver.value != null && getDriverName(item) != selectedDriver.value) return false;
          return true;
        }).toList();

        final rows = filteredItems.map((e) => buildRow(e)).toList();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final cleanTitle = title.replaceAll(' ', '_').toLowerCase();
        
        if (isPdf) {
          final fileName = '${cleanTitle}_$timestamp.pdf';
          await ExportUtils.exportPdf(fileName, title, headers, rows);
        } else {
          final fileName = '${cleanTitle}_$timestamp.csv';
          final csvRows = [headers, ...rows];
          await ExportUtils.exportCsv(fileName, csvRows);
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported successfully as ${isPdf ? 'PDF' : 'CSV'}!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e')),
          );
        }
      } finally {
        isExporting.value = false;
      }
    }

    return AlertDialog(
      title: Text('Export $title'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select filters (optional) before exporting your report.'),
            const SizedBox(height: 16),
            if (vehicles.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: selectedVehicle.value,
                decoration: const InputDecoration(labelText: 'Filter by Car', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Cars')),
                  ...vehicles.map((v) => DropdownMenuItem(value: v, child: Text(v))),
                ],
                onChanged: (val) => selectedVehicle.value = val,
              ),
            const SizedBox(height: 16),
            if (drivers.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: selectedDriver.value,
                decoration: const InputDecoration(labelText: 'Filter by Driver', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Drivers')),
                  ...drivers.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                ],
                onChanged: (val) => selectedDriver.value = val,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isExporting.value ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: isExporting.value ? null : () => handleExport(false),
          icon: const Icon(Icons.table_chart, size: 18),
          label: const Text('CSV'),
        ),
        ElevatedButton.icon(
          onPressed: isExporting.value ? null : () => handleExport(true),
          icon: const Icon(Icons.picture_as_pdf, size: 18),
          label: const Text('PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[50],
            foregroundColor: Colors.red[900],
          ),
        ),
      ],
    );
  }
}
