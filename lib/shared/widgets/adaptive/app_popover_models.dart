part of 'app_popover_menu.dart';

// Data models for popover menus, trailing actions, and nested submenu items.

/// One entry of [showAppPopoverMenu] (an `ion-item button` inside the
/// `ion-list lines="none"` of an `ion-popover`).
class AppPopoverMenuItem<T> {
  const AppPopoverMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
    this.color,
    this.submenu = false,
    this.submenuItems,
    this.destructive = false,
    this.header = false,
    this.iconColor,
    this.note,
    this.selected = false,
    this.lines,
    this.end,
  })  : info = false,
        divider = true;

  /// Section header (Ionic `ion-item-divider` + `<small><b>` label): a
  /// divider line and a small bold, non-tappable label. [value] is never
  /// returned. [divider] false: only the label (a second section right
  /// below another one, Ionic: label item without `ion-item-divider`).
  const AppPopoverMenuItem.header(this.label, this.value, {this.divider = true})
    : icon = null,
      subtitle = null,
      color = null,
      submenu = false,
      submenuItems = null,
      destructive = false,
      header = true,
      iconColor = null,
      note = null,
      selected = false,
      lines = false,
      end = null,
      info = false;

  /// Only the divider line of a section (Ionic `ion-item-divider` without
  /// a label row). [value] is never returned.
  const AppPopoverMenuItem.divider(this.value)
    : label = '',
      icon = null,
      subtitle = null,
      color = null,
      submenu = false,
      submenuItems = null,
      destructive = false,
      header = true,
      divider = true,
      iconColor = null,
      note = null,
      selected = false,
      lines = false,
      end = null,
      info = false;

  /// Non-tappable text row (Ionic `ion-item` without `button`, label with
  /// `<h3>` [label] and `<p>` [subtitle]), e.g. the current sorting.
  /// [value] is never returned.
  const AppPopoverMenuItem.info(
    this.label,
    this.value, {
    this.subtitle,
    this.lines = false,
  })  : icon = null,
        color = null,
        submenu = false,
        submenuItems = null,
        destructive = false,
        header = false,
        iconColor = null,
        note = null,
        selected = false,
        end = null,
        info = true,
        divider = true;

  /// Returned by [showAppPopoverMenu] when the entry is tapped (entries with
  /// [submenuItems] open their nested popover instead).
  final T value;
  final String label;

  /// `ion-icon slot="start"`.
  final IconData? icon;

  /// Second line (`<p>` inside the label).
  final String? subtitle;

  /// Label / icon colour (e.g. primary for an active filter). Defaults to the
  /// text colour – Ionic iOS popover icons are black.
  final Color? color;

  /// The entry opens a sub menu (Ionic `detail="true"` → chevron).
  final bool submenu;

  /// PARITY_R3: entries of a nested `ion-popover` (`side="start"`,
  /// `dismissOnSelect=false`) opened by this entry. Called again after
  /// every tap in the nested popover so checkboxes reflect the new state;
  /// the parent menu stays open.
  final List<AppPopoverSubItem> Function()? submenuItems;

  /// Red label and icon.
  final bool destructive;

  /// See [AppPopoverMenuItem.header].
  final bool header;

  /// See [AppPopoverMenuItem.header].
  final bool divider;

  /// See [AppPopoverMenuItem.info].
  final bool info;

  /// Colour of the start icon only (Ionic `<ion-icon slot="start"
  /// [color]>` next to an uncoloured label), e.g. the dot of a Termin type.
  final Color? iconColor;

  /// Grey text after the label on the same line (Ionic `<ion-note>` inside
  /// the `ion-label`), e.g. "10 Min.".
  final String? note;

  /// The active entry of a filter: primary label and a primary checkmark
  /// at the end (Ionic `ion-label color="primary"` +
  /// `ion-icon slot="end" name="checkmark" color="primary"`).
  final bool selected;

  /// Item line below this entry. null: as the menu ([showAppPopoverMenu]
  /// `lines`); false: Ionic `lines="none"`; true: a line although the menu
  /// has none.
  final bool? lines;

  /// Small button at the end of the row with its own result (Ionic
  /// `ion-button slot="end" fill="clear"` with `stopPropagation`), e.g.
  /// "delete this template".
  final AppPopoverMenuEndAction<T>? end;

  bool get _hasChevron => submenu || submenuItems != null;
}

/// See [AppPopoverMenuItem.end].
class AppPopoverMenuEndAction<T> {
  const AppPopoverMenuEndAction({
    required this.value,
    required this.icon,
    required this.tooltip,
    this.color,
  });

  /// Returned by [showAppPopoverMenu] when the button is tapped.
  final T value;
  final IconData icon;
  final String tooltip;

  /// Icon colour (Ionic `color="medium"` → [AppColors.medium] by default).
  final Color? color;
}

/// PARITY_R3: one row of a nested popover (`ion-item button
/// detail="false"`): a checkbox (`ion-checkbox slot="start"`) when
/// [checked] is set, otherwise an optional icon. [onTap] runs immediately
/// and the popover stays open.
class AppPopoverSubItem {
  const AppPopoverSubItem({
    required this.label,
    required this.onTap,
    this.subtitle,
    this.checked,
    this.icon,
    this.color,
  });

  final String label;
  final String? subtitle;
  final bool? checked;
  final IconData? icon;
  final Color? color;
  final VoidCallback onTap;
}

