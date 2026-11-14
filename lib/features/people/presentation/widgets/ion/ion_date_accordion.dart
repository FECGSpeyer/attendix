import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive_platform.dart'
    show useIosLook;
import '../../../../../shared/widgets/adaptive/ion_md_datetime.dart'
    show IonMdCalendar, IonMdDatetime;
import 'ion_widgets.dart';

/// PEO-04/05: Ionic `ion-accordion` whose header is an `ion-item
/// color="light"` with `<h3>` title, `<p>` value and a `close-circle-outline`
/// clear button (slot end), and whose content is an inline `ion-datetime
/// presentation="date" size="cover"` – the date rows of the pause and
/// absence modals. Tapping the header expands the calendar in place; a day
/// tap sets the value (the calendar stays open, like Ionic).
class IonDateAccordion extends StatefulWidget {
  const IonDateAccordion({
    super.key,
    required this.title,
    required this.valueText,
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.onClear,
    this.initialDate,
  });

  final String title;

  /// `<p>` of the header (formatted date or "Ab heute" / "Kein Datum").
  final String valueText;
  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;

  /// Month shown when [value] is null.
  final DateTime? initialDate;
  final ValueChanged<DateTime> onChanged;

  /// Shows the clear button when set.
  final VoidCallback? onClear;

  @override
  State<IonDateAccordion> createState() => _IonDateAccordionState();
}

class _IonDateAccordionState extends State<IonDateAccordion> {
  bool _open = false;

  DateTime _clamp(DateTime d) {
    if (d.isBefore(widget.firstDate)) return widget.firstDate;
    if (d.isAfter(widget.lastDate)) return widget.lastDate;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    final initial = _clamp(
      widget.value ?? widget.initialDate ?? DateTime.now(),
    );
    final chevron = AnimatedRotation(
      turns: _open ? 0.5 : 0,
      duration: const Duration(milliseconds: 300),
      child: Icon(
        AppIcons.expandMore,
        size: ios ? 20 : 24,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonItem(
          background: ionLightColor(context),
          onTap: () => setState(() => _open = !_open),
          end: [
            if (widget.onClear != null)
              IconButton(
                icon: Icon(
                  AppIcons.highlightOff,
                  color: AppColors.medium,
                  semanticLabel: context.l10n.commonRemove,
                ),
                onPressed: widget.onClear,
              ),
            chevron,
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: IonText.h3(context)),
              const SizedBox(height: 2),
              Text(widget.valueText, style: IonText.p(context)),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child:
              !_open
                  ? const SizedBox(width: double.infinity)
                  : useIosLook(context)
                  ? CalendarDatePicker(
                    // Rebuild when the value is cleared / set outside.
                    key: ValueKey(widget.value),
                    initialDate: initial,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    onDateChanged:
                        (d) =>
                            widget.onChanged(DateTime(d.year, d.month, d.day)),
                  )
                  // The md calendar fills its parent (Expanded grid):
                  // give it the Ionic md grid height inside the scroll view.
                  : SizedBox(
                    height: IonMdDatetime.gridHeight,
                    child: IonMdCalendar(
                      key: ValueKey(widget.value),
                      initialDate: initial,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      onChanged: (d, {required bool byDay}) {
                        if (byDay) {
                          widget.onChanged(DateTime(d.year, d.month, d.day));
                        }
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}
