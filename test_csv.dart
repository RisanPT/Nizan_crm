import 'dart:developer';

import 'package:csv/csv.dart';

void main() {
  final rows = [['a', 'b'], ['c', 'd']];
  final result = const CsvEncoder().convert(rows);
  log(result);
}
