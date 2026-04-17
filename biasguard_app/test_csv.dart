import 'dart:io';
import 'package:csv/csv.dart';

void main() {
  final csvContent = File('assets/demo/bihar_scholarship_2026.csv').readAsStringSync();
  List<List<dynamic>> rows = const CsvToListConverter().convert(csvContent);
  print('Rows detected by default CsvToListConverter: ${rows.length}');
  
  if (rows.isNotEmpty) {
    print('Header: ${rows.first}');
  }
}
