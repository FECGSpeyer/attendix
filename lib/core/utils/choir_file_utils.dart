/// "Chor (alle)": a Werk file without a group that is meant for all singers
/// of a choir (Ionic `Utils.CHOIR_ALL_NOTE` / `Utils.isChoirAllFile`, 4.17.16).
///
/// The category is stored as `note = 'Chor'` (instrumentId null), so copying
/// and Werk-Sync stay compatible. Detection tolerates case and spaces.
library;

/// Note marking a choir Werk file as meant for all singers ("Chor (alle)").
const String kChoirAllNote = 'Chor';

/// Selection value of the "Chor (alle)" option in the category pickers
/// (upload sheets, category dialog). Never stored: it resolves to
/// `instrumentId: null, note: 'Chor'` via [resolveFileCategoryOption].
const int kChoirAllOptionValue = -2;

/// True if the file has no group and is marked for the whole choir.
bool isChoirAllFile({int? instrumentId, String? note}) =>
    instrumentId == null && note?.trim().toLowerCase() == 'chor';

/// Value of the category picker for a file: [kChoirAllOptionValue] for a
/// "Chor (alle)" file in a choir, otherwise its instrumentId (null =
/// "Sonstige (Freitext)"). Ionic `getFileSelectValue`.
int? fileCategoryOptionValue(int? instrumentId, String? note, {required bool isChoir}) {
  if (instrumentId == null) {
    return isChoir && isChoirAllFile(note: note) ? kChoirAllOptionValue : null;
  }
  return instrumentId;
}

/// Category stored for a picked option (Ionic `changeFileInstrument` /
/// `saveCategoryModal`): "Chor (alle)" → note 'Chor'; "Sonstige (Freitext)"
/// → the free text (a leftover "Chor" is cleared); a group → no note.
({int? instrumentId, String? note}) resolveFileCategoryOption(int? value, String? freeText) {
  if (value == kChoirAllOptionValue) {
    return (instrumentId: null, note: kChoirAllNote);
  }
  if (value == null) {
    final text = freeText ?? '';
    return (instrumentId: null, note: isChoirAllFile(note: text) ? '' : text);
  }
  return (instrumentId: value, note: null);
}
