import 'package:excel/excel.dart';
void main() {
  var excel = Excel.createExcel();
  var sheet = excel.sheets[excel.getDefaultSheet()]!;
  
  sheet.appendRow([TextCellValue('ID'), TextCellValue('Name')]);
  
  var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
  cell.cellStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.blue,
  );

  sheet.setColumnWidth(0, 10);
  sheet.setColumnAutoFit(1);
  
  print("OK!");
}
