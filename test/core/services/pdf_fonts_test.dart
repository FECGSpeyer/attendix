import 'package:attendix/core/services/pdf_fonts.dart';
import 'package:attendix/core/utils/plan_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF exports embed NotoSans (Ionic registerExportFont)', () async {
    PdfFonts.debugReset();
    final doc = await PdfFonts.document();
    doc.addPage(pw.Page(build: (_) => pw.Text('Иван Петров „Test“ – 5 €')));
    final bytes = await doc.save();
    expect(String.fromCharCodes(bytes), contains('NotoSans'));
  });

  test('planningTitle mirrors Ionic getPlanningTitle', () {
    expect(PlanUtils.planningTitle(planningTitle: 'Probe', typeInfo: 'Jugend', typeName: 'X'), 'Probe (Jugend)');
    expect(PlanUtils.planningTitle(planningTitle: 'Probe', typeName: 'X'), 'Probe');
    expect(PlanUtils.planningTitle(typeInfo: 'Jugend', typeName: 'X'), 'Jugend');
    expect(PlanUtils.planningTitle(typeName: 'Gottesdienst'), 'Gottesdienst');
  });
}
