import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/utils/faculty_catalog.dart';
import 'package:nubify/widgets/faculty_selector.dart';

void main() {
  test('faculty catalogue contains ten named faculties plus Others', () {
    expect(NubifyFacultyCatalog.all, hasLength(11));
    expect(
      NubifyFacultyCatalog.all.where((faculty) => !faculty.isOther),
      hasLength(10),
    );
    expect(NubifyFacultyCatalog.all.last.isOther, isTrue);
  });

  test('known faculty names resolve to their exact visual identity', () {
    final faculty = NubifyFacultyCatalog.exactMatch(
      'Faculty of Computer Science',
    );

    expect(faculty, same(NubifyFacultyCatalog.computerScience));
    expect(
      NubifyFacultyCatalog.selectionIdFor('Faculty of Computer Science'),
      NubifyFacultyCatalog.computerScience.id,
    );
  });

  test('custom faculty names use the Others identity', () {
    const customFaculty = 'Faculty of Veterinary Medicine';

    expect(
      NubifyFacultyCatalog.selectionIdFor(customFaculty),
      NubifyFacultyCatalog.other.id,
    );
    expect(
      NubifyFacultyCatalog.displayFor(customFaculty),
      same(NubifyFacultyCatalog.other),
    );
  });

  testWidgets('selecting Others reveals the custom faculty field', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    String? selectedId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return FacultySelectionField(
                selectedId: selectedId,
                otherController: controller,
                onSelected: (NubifyFaculty faculty) {
                  setState(() => selectedId = faculty.id);
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Type your faculty'), findsNothing);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    final Finder otherItem = find.byWidgetPredicate(
      (Widget widget) =>
          widget is DropdownMenuItem<String> && widget.value == 'other',
    );
    await tester.ensureVisible(otherItem.last);
    await tester.pumpAndSettle();
    await tester.tap(otherItem.last);
    await tester.pumpAndSettle();

    expect(find.text('Type your faculty'), findsOneWidget);
    expect(find.text('Enter your faculty name'), findsOneWidget);

    controller.dispose();
  });
}
