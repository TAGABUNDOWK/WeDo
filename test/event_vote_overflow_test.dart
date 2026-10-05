import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:choosly/models/event.dart';
import 'package:choosly/widgets/event_card_widgets.dart';

Widget _avatar(String uid, double size) {
  return Container(width: size, height: size, color: const Color(0xFF211635));
}

/// Mimics the chat event card: list padding (12) + card padding (32) are
/// applied outside, so only the option rows themselves are pumped here at the
/// exact width the `Row` inside `EventVoteOption` would receive.
Future<void> _pumpStats(
  WidgetTester tester, {
  required double screenWidth,
  required double textScale,
  required List<List<String>> votersPerOption,
  bool selected = false,
  bool locked = false,
}) async {
  const responses = EventResponse.values;
  final allVoters = votersPerOption.expand((v) => v).toList();
  final rowWidth = screenWidth - 88;

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(screenWidth, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              child: SizedBox(
                width: rowWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < responses.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: EventVoteOption(
                          label: responses[i].label,
                          count: votersPerOption[i].length,
                          total: allVoters.length,
                          voters: votersPerOption[i],
                          avatarBuilder: _avatar,
                          isSelected: selected && i == 0,
                          isLocked: locked,
                          onTap: () {},
                        ),
                      ),
                    if (locked) const EventRsvpLockRow(ended: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
}

void main() {
  // Two voters spread across the three options — the reported repro case.
  const twoVoters = [
    ['u1'],
    ['u2'],
    <String>[],
  ];
  const fourVotersEach = [
    ['a', 'b'],
    ['c', 'd'],
    ['e', 'f'],
  ];

  for (final width in [400.0, 360.0, 320.0, 280.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('stats rows do not overflow at ${width}w scale $scale',
          (tester) async {
        await _pumpStats(
          tester,
          screenWidth: width,
          textScale: scale,
          votersPerOption: twoVoters,
          selected: true,
        );
      });

      testWidgets(
          'heavy stats rows do not overflow at ${width}w scale $scale',
          (tester) async {
        await _pumpStats(
          tester,
          screenWidth: width,
          textScale: scale,
          votersPerOption: fourVotersEach,
        );
      });

      testWidgets('locked stats row does not overflow at ${width}w scale $scale',
          (tester) async {
        await _pumpStats(
          tester,
          screenWidth: width,
          textScale: scale,
          votersPerOption: twoVoters,
          locked: true,
        );
      });
    }
  }
}
