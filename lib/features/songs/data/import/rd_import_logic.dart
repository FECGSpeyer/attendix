import 'dart:math' as math;

import '../../../../core/utils/choir_file_utils.dart' show kChoirAllNote;
import '../../../../core/utils/instrument_matcher.dart';
import '../../../../data/models/song/song.dart';
import '../file_category_guess.dart' show FileCategoryGuess, guessFileCategory, learnableTerm;
import '../rd_work_files_logic.dart' show rdMaxUploadBytes;

/// REDESIGN: "Noten importieren" (Werke aus einer ZIP von Google Drive,
/// Dropbox oder dem Rechner). The rules, free of widgets so they can be
/// tested: which folder is a Werk, which Werk in Attendix it belongs to,
/// Fassungen, duplicates, the questions about unknown part names and what
/// is uploaded in the end.
///
/// Lessons from the Speyer import (2,304 files): part names are mostly clear
/// from the file name, unknown names are asked once for all files; which
/// Fassung is current is decided by the date inside the files, never by the
/// number of files; files already in Attendix are never replaced; Werke with
/// Fassungen or an unsure Werk are only uploaded once someone looked at them.


part 'rd_import_models.dart';
part 'rd_import_matching.dart';
part 'rd_import_categories.dart';
part 'rd_import_plan.dart';
part 'rd_import_decisions.dart';
