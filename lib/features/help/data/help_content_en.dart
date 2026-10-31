// GENERATED from Ionic src/app/settings/help/content/en (English).
// Do not edit by hand; regenerate when the Ionic help content changes.
// Keyed by the ids of the German content in help_content.dart; missing
// entries fall back to German (Ionic localizeHelp).

import 'help_models.dart';

const Map<String, String> helpCategoriesEn = {
  "getting-started": "Getting started",
  "attendance": "Attendance",
  "people": "People",
  "planning": "Run sheet",
  "songs": "Pieces",
  "self-service": "My attendance",
  "settings": "Settings",
  "team": "Team organisation",
  "duty": "Duty roster",
  "other": "More features",
};

const Map<String, HelpArticleTranslation> helpArticlesEn = {
  "gs-overview": HelpArticleTranslation(
    title: "What is Attendix?",
    keywords: ["start", "introduction", "overview", "app"],
    body: "Attendix helps orchestras, choirs and similar groups record attendance, manage [[Piece|pieces]], plan rehearsals and performances and keep track of their members.\n\nIt works in the browser on a laptop just as well as an app on your smartphone. What you can see and do depends on your [[Role|role]] in the current [[Instance|instance]].\n\nFor the board or leadership team there is [[Team organisation]]: agenda in the run sheet, minutes and tasks, all directly on the event (see \"What is team organisation?\").",
  ),
  "gs-navigation": HelpArticleTranslation(
    title: "How is the app structured?",
    keywords: ["tabs", "navigation", "menu", "overview"],
    body: "At the bottom of the app you find different tabs depending on your [[Role|role]], e.g. Dashboard, Attendance, Members, Pieces and Settings.\n\n- **Dashboard**: overview of upcoming events, birthdays and important notes (only for [[Administrator]] and [[Person in charge]]).\n- **Attendance**: create events and keep the [[Attendance status|attendance status]] of members.\n- **Members**: list of people with their [[Personal details|personal details]].\n- **Pieces**: the club's sheet music library.\n- **Settings**: club details, notifications, roles and help.\n\nMembers without management rights usually only see \"My attendance\" and \"Pieces\" instead.",
  ),
  "gs-switch-instance": HelpArticleTranslation(
    title: "Switching between several instances",
    keywords: ["switch instance", "switch club", "several clubs"],
    body: "If your account is linked to several [[Instance|instances]] (e.g. because you are active in several clubs), you can switch at any time via \"Switch instance\" in the settings. All data shown (people, events, pieces) always refers only to the instance currently selected.",
  ),
  "att-list-layout": HelpArticleTranslation(
    title: "Reading the event overview",
    keywords: ["event list", "events overview", "open run sheet", "upcoming events", "past events", "next event", "percent", "average", "month"],
    body: "Under \"Events\", conductors and helpers see today's event (or the next one) at the top as a large card, with the expected attendance and how many people are present, excused or absent. Tap the card to record attendance. If the event has a run sheet, open it via \"Run sheet\" right in the card; if the event is currently running, the plan starts in live mode. Before the first item nothing is highlighted yet; instead, the time until the start counts down next to \"Start\". The pencil at the top right takes you straight to the editor to change the plan. In the list of upcoming events, the plan icon also leads directly to the run sheet.\n\nBelow that, the upcoming events follow, grouped by month. The date is on the left; highlighted event types have a coloured date tile. On the right you see the attendance in percent: green from 75 %, yellow from 50 %, otherwise red.\n\nUnder \"Past\" you find the average and the last three events; \"Show all\" expands the whole list. Conductors can still delete an event by swiping left.",
  ),
  "att-mark-status": HelpArticleTranslation(
    title: "Marking attendance",
    keywords: ["change status", "present", "absent", "excused", "late"],
    body: "Open an event in the \"Attendance\" area and tap the status next to a person to move it on. The [[Attendance status|attendance status]] changes in a fixed order, e.g. Neutral → Present → Excused → Late → Absent.\n\nWhich steps are part of the cycle can be configured per event type in the settings under \"General\" (e.g. without \"Late\" if that is not relevant for an instance).",
  ),
  "att-excuse-reason": HelpArticleTranslation(
    title: "Excusing an absence with a reason",
    keywords: ["absence reason", "ill", "sick", "excuse", "choose reason"],
    body: "When setting the status \"Excused\" or \"Late\", you can pick an [[Absence reason|absence reason]] or [[Lateness reason|lateness reason]] from a predefined list (e.g. \"Illness\", \"Holiday\"). This list can be adjusted per instance in the settings.",
  ),
  "att-change-date": HelpArticleTranslation(
    title: "Moving an event to another day",
    keywords: ["change date", "move", "reschedule", "other day", "move event", "date", "reset status"],
    body: "Open the event, expand **General** and tap **Date**. Pick the new day and confirm. For an event with an agenda you can also do this in team organisation on the **Topics** tab via **Change → Change date of this event**.\n\nIf people already have a status other than the default status of the type, Attendix asks: **Reset** sets everyone back to the default status, **Keep** leaves the existing responses in place.\n\nMoving an event also does the following:\n- The sign-up deadline and the deadlines of the [[Checklist|checklist]] move by the same number of days.\n- The pieces of the event get the new date in the [[History|history]].\n- Shifts are checked again for the new day, and absences entered for the new day excuse the people concerned.",
  ),
  "att-checklist": HelpArticleTranslation(
    title: "Checklist for an event",
    keywords: ["tasks", "todo", "deadline", "due"],
    body: "For every event you can add a [[Checklist|checklist]] with tasks, e.g. \"Bring sheet music\" or \"Book the room\". Each item can optionally get a deadline relative to the event (1 hour, 1 day, 2 days or 1 week before), so you get reminded in time.",
  ),
  "att-checklist-deadlines": HelpArticleTranslation(
    title: "Spotting checklist deadlines",
    keywords: ["overdue", "deadline passed", "checklist red", "warning"],
    body: "If a [[Checklist|checklist]] item has a deadline, Attendix shows both the exact time and a relative note (e.g. \"in 3 hours\") in the event. If the deadline has passed and the item is not done yet, it is highlighted in colour (yellow = due soon, red = overdue) so nothing gets forgotten.",
  ),
  "att-songs-plan": HelpArticleTranslation(
    title: "Adding pieces to an event",
    keywords: ["choose pieces", "programme", "conductor", "songs"],
    body: "In the event details you can add [[Piece|pieces]] that were played or are planned in the \"Pieces\" area and assign who leads them (conductor/choir leader). These entries automatically end up in the [[History|history]] and can be selected in the [[Run sheet|run sheet]].",
  ),
  "att-reminder": HelpArticleTranslation(
    title: "Sending a reminder to members (ad-hoc reminder)",
    keywords: ["reminder", "ad-hoc", "adhoc", "send notification", "email", "push", "neutral", "without status", "no response", "remind one person"],
    body: "In addition to the automatic event reminders, you can remind people of an event manually at any time. [[Helper|Helpers]] do not have this function.\n\n**Remind everyone**\nOpen the event, tap the menu (⋮) and then \"Send reminder\". Subject and message are pre-filled with event type, date and time and can be changed freely. If there are still people without a status (\"Neutral\") in the event, **\"Only people without status\"** lets you remind just those who have not responded yet.\n\n**Remind a single person**\nIn the event, swipe a person to the left, tap the three dots and choose \"Send reminder\". The reminder then only goes to this person.\n\n**How the reminder is delivered**\n- By push (or Telegram) to everyone with an app account who has enabled notifications and \"Event reminders\". [[Observer|Observers]] do not get it.\n- By email to people of the event with a stored email address, except the [[Main group|main group]] and people who have left. Without \"Only people without status\", this only applies to people who already have a status. The email contains a link directly to the event.\n- Anyone reminded by email who has an app account also sees the reminder in the bell.\n\nFor general messages not related to an event, use announcements instead (Settings → Communication → Announcements).",
  ),
  "att-options-menu": HelpArticleTranslation(
    title: "Options and view in the event",
    keywords: ["menu", "options", "view", "filter", "sorting", "pictures", "sign-up fields", "status filter", "additional fields"],
    body: "The menu (⋮) at the top right of the event contains several sections:\n\n**Status filter** – Shows only people with certain statuses (e.g. only absent people). Active filters are indicated by a coloured counter on the menu button.\n\n**Sorting** – Sorts the list of people by an [[Additional field|additional field]] (person or sign-up fields), ascending or descending (↑ / ↓). Without active sorting, the default group order applies. The sorted field value and the group are shown as extra info under the name.\n\n**View** – Controls what is visible in the event:\n- *Show pictures* – Shows profile pictures next to the names.\n- *Show sign-up fields* – Shows or hides the answers to sign-up fields under the names (only visible if the event type has sign-up fields).\n- *Explicit status selection* – Switches to a mode in which each person shows a dropdown to choose the status, instead of moving the status on when tapped.",
  ),
  "people-add": HelpArticleTranslation(
    title: "Adding a new person",
    keywords: ["add member", "new person", "create"],
    body: "Under \"Members\" you can add a new person with the plus icon: name, date of birth, contact details, [[Group|group]]/instrument and joining date. You can also fill in instance-specific [[Additional field|additional fields]].\n\nAssign a [[Role|role]] right away (e.g. [[Member]] or [[Helper]]) so the person can log in and use the app accordingly.",
  ),
  "people-info-mail": HelpArticleTranslation(
    title: "Which email does a newly added person get?",
    keywords: ["info mail", "welcome mail", "invitation", "access", "set password", "create account", "added notification"],
    body: "If you add a person with an email address and give them access to the app, they automatically get an email:\n\n- **No Attendix account yet:** An account is created. The welcome email names the [[Instance|instance]] and the assigned [[Role|role]] and contains a button with which the person sets their password and logs in.\n- **Already has an Attendix account:** The person gets an info email that they were added to your instance and logs in with their existing credentials. The new instance then appears in their instance selection.\n\nIf no email arrives, check the spam folder and the stored email address.",
  ),
  "people-roles": HelpArticleTranslation(
    title: "Assigning and changing roles",
    keywords: ["assign role", "rights", "permissions", "make admin"],
    body: "In a person's [[Personal details|personal details]], an [[Administrator]] or [[Person in charge]] sets the [[Role|role]]. The role controls what the person can see and edit, from [[Observer]] (read only) to [[Administrator]] (full access).\n\nA person can have different roles in different [[Instance|instances]].",
  ),
  "people-pending": HelpArticleTranslation(
    title: "Approving registrations",
    keywords: ["applicant", "self-registration", "unlock", "approve"],
    body: "When someone registers themselves via a registration link, the person first appears as an [[Applicant|applicant]] on a waiting list. An [[Administrator]] or [[Person in charge]] checks the request and approves it with a suitable [[Role|role]] or declines it.",
  ),
  "people-pause-leave": HelpArticleTranslation(
    title: "Pausing and leaving",
    keywords: ["pause", "leave", "archive", "former members"],
    body: "If a person is temporarily not active (e.g. parental leave, injury), they can be paused without deleting their [[Personal details|personal details]]. If someone leaves the club for good, the person is marked as \"left\" and appears in the list of former members, but is kept for the history.",
  ),
  "people-church-overview": HelpArticleTranslation(
    title: "Church overview",
    keywords: ["churches", "count churches", "origin", "church statistics", "bfecg"],
    body: "If your instance has an [[Additional field|additional field]] of the type \"BFECG church\", you find the church overview in the list of people (filter menu) and in an event (options menu). It shows how many people come from which church and how many are not assigned to any church.\n\nIn the list of people, the overview counts the people currently filtered; in an event, only those present (including late).",
  ),
  "plan-create": HelpArticleTranslation(
    title: "Creating a run sheet",
    keywords: ["create plan", "create programme", "schedule", "add field", "programme item", "info text", "note", "description"],
    body: "Under \"Planning\" you choose an event and create a [[Run sheet|run sheet]]: a sequence of programme items (pieces, speeches, breaks), each with its duration and start time. The end time is calculated automatically from the duration of all items.\n\n**Adding an item:** In the schedule, tap **+** and then **Add field**. Next to name, performer and duration you can also enter an optional **info text**, for example a song title or a note. The info text appears in small print under the programme item. To change it later, tap the item.\n\nWith \"Reset\" you can return to the default programme items of the event type at any time; changes you have made are lost.",
  ),
  "plan-multiple": HelpArticleTranslation(
    title: "Several run sheets for one event",
    keywords: ["several plans", "another plan", "multi-day", "retreat", "weekend", "day", "day plan", "per day", "second run sheet"],
    body: "An event can have more than one [[Run sheet|run sheet]], for example one for each day of a retreat, or a rehearsal and a concert on the same day.\n\n**Creating a plan:** Open the run sheet in the editor, tap **+** in the schedule and, at the very bottom, **Create another run sheet**. You then decide whether the new plan takes over the current schedule as a **copy** or starts **empty**. Agenda topics always stay in the first plan.\n\n**Names:** For multi-day events the plans are named after their day automatically (e.g. \"Sat 18.10.\"), otherwise \"Plan 1\", \"Plan 2\" and so on.\n\n**Switching and managing:** As soon as there is more than one plan, a bar with small chips appears above the schedule. With **⋯** next to it you can rename the selected plan, assign it to another day, move it or delete it. If only one plan is left, the bar disappears again.\n\n**What members see:** On the event page, in the view for members and parents and via the share link, the same chips appear. Today's plan is selected automatically, otherwise the first one. The dashboard card \"Current plan\" also shows the plan for today.\n\n**Sharing and PDF:** When sharing, you choose at the top whether only the plan currently shown or all plans are exported. \"All\" produces one PDF with one page per plan.",
  ),
  "plan-blocks": HelpArticleTranslation(
    title: "Programme blocks with sub-items",
    keywords: ["programme block", "block", "sub-item", "sub-items", "group", "programme", "nested", "indent", "youth choir", "children programme", "block template", "ad-hoc", "planning tool", "public"],
    body: "Some programme items consist of several parts, for example \"Youth choir programme\" with songs and a poem. That is what **programme blocks** are for.\n\n**Creating a block:** In the run sheet editor, tap **+** in the schedule and then **Add programme block**. Enter a name and optionally a performer. Then you create the first sub-item right away. Add more sub-items with **Add sub-item** at the end of the block.\n\n**Times:** The duration of the block results automatically from its sub-items. The first sub-item starts with the block, after that the schedule continues as normal.\n\n**Sorting:** If you drag the block by its handle, all sub-items move with it. Drag a normal programme item between two sub-items to make it part of the block. If you drag a sub-item out of the block, it becomes a normal item again. Alternatively, swipe an item to the left and tap **Indent** or **Outdent**. The arrow on the left collapses or expands a block.\n\n**Editing a block:** Tap the block name. There you can edit the block, **dissolve** it (the sub-items stay as normal items) or delete it completely.\n\n**Block templates:** Admins can save a block with **Save as template**. Saved blocks appear in the **+** menu under \"Programme blocks\" and are added to the end of the schedule with one tap. Admins delete a template again with the bin icon next to it.\n\n**Ad-hoc run sheets and the public planning tool:** The ad-hoc run sheet (Settings › Ad-hoc run sheet) and the public planning tool at attendix.de/planung also offer **Add programme block** in the **+** menu. Creating, sorting, indenting and outdenting work just like in the run sheet editor. When you are signed in, you can also insert your group's block templates there. With an edit link, blocks are moved together with their sub-items as well.\n\n**What members see:** On the event page, in the plan view, on the dashboard card and in the PDF, sub-items appear indented under their block. In live mode the running sub-item is marked, and the block stays highlighted as long as one of its sub-items is running.",
  ),
  "plan-live-activity": HelpArticleTranslation(
    title: "Running run sheet on the lock screen",
    keywords: ["live activity", "dynamic island", "lock screen", "lockscreen", "live update", "countdown", "time left", "colour", "color", "event type", "current item", "notification", "iphone", "android"],
    body: "While a [[Run sheet|run sheet]] is running, the Attendix app shows the current programme item in large print with the time left on your lock screen, below it a bar for the whole schedule and the next item with its time. Long titles may take two lines. On the iPhone it also appears in the Dynamic Island, on Android as an ongoing notification with a countdown.\n\n**When:** The display starts automatically 15 minutes before the first item. Until the start it shows a countdown and the first programme items with their times. After that it moves on to the next item by itself and disappears 15 minutes after the end. If the plan is changed during the event, the display is up to date within a minute at the latest. The plan runs by the clock: when an item's time is up, the time left stays at 0:00 briefly until the next item appears. On the iPhone the display moves on to the next item by itself within a minute, even without a connection.\n\n**Who:** Everyone who may see the run sheet: admins and people in charge always, everyone else if the plan is shared with members. Observers never see the run sheet, so they get no display either. Anyone who has signed out of the event does not get one. ORG plans of your organisation (events marked as ORG plan and ORG plans without an event) run on the lock screen the same way, for the admins and people in charge of all choirs in the organisation.\n\n**Several plans:** For events with several plans (e.g. one per day of a retreat), the plan that is currently running is shown.\n\n**Colour:** Each display has the colour of its event type (set under **More → Settings → Attendance types**), so you can tell several plans running at the same time apart. ORG plans without an event stay teal. On the iPhone this needs the current app version from the App Store.\n\n**Tapping** opens the run sheet in the app in live mode.\n\n**Switching off:** Under Settings → Notifications → **Running run sheet**. On the iPhone the automatic start needs iOS 17.2 or later; on older versions the display appears as soon as you open the app during the event. The feature is only available in the app from the App Store or Play Store, not in the browser.",
  ),
  "plan-beamer": HelpArticleTranslation(
    title: "Projector files in the run sheet (Gemeinde App)",
    keywords: ["projector", "projector file", "beamer", "songbeamer", "sng", "slides", "gemeinde app", "fecg", "org plan", "edit item", "edit field", "song", "poem"],
    body: "This feature is only available to the organisations FECG Speyer and FECG Schwegenheim, whose org plans appear in the Gemeinde App.\n\n**Switching on:** Admins switch on **Projector files in the run sheet** under Settings › Organisation › Gemeinde App. There you also create the **connection key** for the Gemeinde App. It is only visible right after you create it. If you renew it, the old key stops working.\n\n**In the run sheet:** The projector details only appear when **Organization plan** is switched on for the plan. If a programme item needs a projector file, a line below it shows the file name or \"Projector file missing\".\n\n**Needed or not:** Tap a programme item. In the **Edit field** window you find the switch **Projector file needed** under \"Projector\". It is on automatically for [[Piece|pieces]] and when the title contains \"Lied\" (song) or \"Gedicht\" (poem). If you switch it by hand, it stays that way. Notes and programme blocks need no file.\n\n**Linking the file:** You link the file itself (.sng from the media library) in the Gemeinde App under More › Run sheets. Attendix then shows it on the programme item. If you remember the file for a [[Piece|piece]] there, it appears on the piece page under **SongBeamer file** and applies to every plan containing the piece, as long as the item has no file of its own.\n\n**When saving:** Linked files stay on the programme item even if you edit, rename or move it in Attendix at the same time. If you delete the item or copy the plan, the new item has no file.",
  ),
  "plan-conductor": HelpArticleTranslation(
    title: "Assigning a lead/conductor",
    keywords: ["choose conductor", "choir leader", "lead"],
    body: "Each programme item in the [[Run sheet|run sheet]] can be assigned a lead (conductor/choir leader). Attendix suggests people from the [[History|history]] of the respective [[Piece|piece]].",
  ),
  "plan-templates": HelpArticleTranslation(
    title: "Plan templates & default fields",
    keywords: ["template", "default field", "organisation", "reusable"],
    body: "Under **Settings → Organisation → Plan templates & fields** (or **Settings → Planning → Plan templates & fields**) two kinds of planning aids can be defined at organisation level:\n\n**Default fields** are reusable single fields (e.g. \"Welcome 5 min\") with name, performer and duration. They appear in the planning menu and in ad-hoc run sheets under the \"Fields\" section and can be added to the current schedule with one tap.\n\n**Templates** are complete run sheets with a name, an optional start time and any number of fields (including piece placeholders). In the planning menu they appear under \"Templates\"; one tap replaces the current schedule completely. In ad-hoc run sheets they appear in the template selection as \"(Org)\" entries.\n\nBoth templates and default fields are available to all instances of the organisation.",
  ),
  "plan-share": HelpArticleTranslation(
    title: "Exporting and sharing a run sheet",
    keywords: ["pdf export", "share", "link", "telegram", "ad-hoc", "image"],
    body: "A finished [[Run sheet|run sheet]] can be exported as PDF, sent via Telegram or shared via a public link. When sharing via link you can decide whether viewers can only look at the plan or also follow it live while it is updated during the event.\n\nIf an event has several run sheets, you can choose when sharing whether only the plan shown or all plans end up in one PDF (see \"Several run sheets for one event\").\n\nThe ad-hoc run sheet (Settings › Ad-hoc run sheet) can also send the plan via Telegram, as PDF, PDF 2x A5 or image. The options appear when exporting and sharing once you are signed in and have connected Telegram in your notifications.",
  ),
  "songs-add": HelpArticleTranslation(
    title: "Adding a piece",
    keywords: ["add piece", "sheet music library", "new piece", "song", "open file", "view pdf", "web app"],
    body: "Under \"Pieces\" you create a new [[Piece|piece]] with number, name, difficulty and categories. Optionally you can store matching sheet music files (PDF) for each [[Group|group]]/voice.\n\nTap a file and then \"Open file\": Attendix shows PDFs and images right inside the app. Other files open in a new tab or in the matching app. If you use Attendix as an installed web app (e.g. on a Mac via \"Add to Dock\"), you get a hint with \"Download file\" and \"Close\" for such files instead. In the Attendix app from the App Store on a Mac with Apple silicon, they open in the browser.",
  ),
  "songs-filter": HelpArticleTranslation(
    title: "Searching and filtering pieces",
    keywords: ["search", "filter", "difficulty", "last played", "last sung", "planned", "not sung yet", "prefix", "song book", "load more", "scroll"],
    body: "The list of pieces can be filtered with the search field (title, number or prefix with number, e.g. \"LB12\") as well as by instrument, difficulty or date of the last performance. That way you quickly find, for example, all pieces that have not been played for a long time. Under each piece you see when it was last sung or played. If it is already planned for a future event, it also says \"Planned on …\", and for new pieces \"Not sung yet · Planned on …\". Only events that have already taken place count for \"Last sung\" and for sorting. For large lists Attendix shows the first 100 pieces first and loads more automatically as you scroll down.",
  ),
  "songs-import": HelpArticleTranslation(
    title: "Importing pieces",
    keywords: ["bulk import", "import list", "csv"],
    body: "Larger lists of pieces can be imported. Attendix tries to assign instruments/voices to the matching [[Group|groups]] automatically based on the file names.",
  ),
  "songs-export-pdf": HelpArticleTranslation(
    title: "Exporting the list of pieces as PDF",
    keywords: ["pdf export", "print list of pieces", "export list", "pdf"],
    body: "Via the menu (three dots at the top right) you can export the current list of pieces as PDF. The list is exported as currently filtered and sorted, including all visible columns such as difficulty, last sung and custom fields.",
  ),
  "songs-group-directory": HelpArticleTranslation(
    title: "Printing the group directory and music folder",
    keywords: ["group directory", "music folder", "voice", "sheet music of a group", "score", "conductors", "print"],
    body: "Via \"Group directory\" in the list of pieces you choose a [[Group|group]] and see all sheet music files stored for this group. With the printer icon at the top right you print the group's complete music folder at once.\n\nIf scores are stored, there is also the group \"Conductors\", which contains all scores. The group directory is also available if your instance does not use piece categories.",
  ),
  "songs-sync": HelpArticleTranslation(
    title: "Sharing pieces with another instance (piece sync)",
    keywords: ["piece sync", "synchronise", "source instance", "share pieces", "shared pieces", "merge pieces", "delete piece"],
    body: "Linked [[Instance|instances]] can use a shared piece library. As super admin you choose a source instance under \"Organisation → Piece sync\". Your instance then shows the pieces, categories and sheet music files of the source instance, and all changes are saved there. Events and history stay separate per instance.\n\nImportant when deleting: a piece exists only once for all instances involved. If you delete it, it is gone everywhere, including the history of all instances. Attendix points this out when deleting and names the instances affected.",
  ),
  "self-signout": HelpArticleTranslation(
    title: "Signing myself in or out",
    keywords: ["sign out", "sign in", "my events", "signout", "sign-up fields", "note", "change answers", "edit registration", "accept", "late", "decline", "today", "next event", "more options", "past events", "attendance rate", "not invited", "all events visible", "other events"],
    body: "Under \"My attendance\" you see your greeting at the top with your attendance rate and how often you were late. Below are the tiles \"Current pieces\" and \"Report absence\", if they are enabled for you.\n\nToday's event (or the next one) has its own card. There you sign in or out directly with \"Accept\", \"Late\" or \"Decline\". You can tap the small markers such as \"Run sheet\", \"Info\", \"Attachment\", \"Files\" or \"Route\" directly to open the plan, the description, the attachment, the file storage or the navigation. Everything else, e.g. signing in with a note or sign-up fields, is under the link \"More options\". It only lists what is not already visible as a button or marker on the card. Tapping the card itself does not open a menu.\n\nThe upcoming events are grouped by month. Each event shows the date on the left, time and place below it and your [[Attendance status|attendance status]] on the right. Notes such as sign-up deadline, note, run sheet or info appear as small markers. Tap an event to change your status. If you sign out, you can optionally choose an [[Absence reason|absence reason]].\n\nIf your instance has turned on \"All events visible to members\", you also see events you are not invited to. They have a grey background, the date has a dashed outline and instead of your status it says \"Not invited\" on the right. This applies to the card of the current event and to the upcoming events. \"Past\" only lists events you took part in.\n\nUnder \"Past\" you see your rate, coloured dots for your recent events and the last three events. \"Show all\" expands the whole list.\n\nIf an event has sign-up fields (e.g. \"Joining for dinner?\"), the app asks for them when you sign in, even if you choose \"Sign in with note\": first you enter your note, then you fill in the sign-up fields.\n\nIf you are already signed in, tap the event and choose \"Edit sign-up fields\" to change your answers afterwards. This works as long as the event's sign-up deadline has not passed.",
  ),
  "self-pause": HelpArticleTranslation(
    title: "Entering a planned absence",
    keywords: ["pause", "enter holiday", "plan absence", "period", "vacation"],
    body: "If you already know in advance that you cannot come for a period (e.g. holiday), you can enter it with a from/to date and a reason. Attendix automatically marks you as absent for all events affected.",
  ),
  "self-children": HelpArticleTranslation(
    title: "Keeping attendance for my child",
    keywords: ["parents", "sign in child", "parent", "all children", "sign out children"],
    body: "As a [[Parent|parent]] you also see your children's events under \"My attendance\" and can keep their [[Attendance status|attendance status]] just like your own.\n\nEach event is a card listing your children with their status. Tap a child to change only their status, or \"All\" to sign all children in or out at once. Today's event (or the next one) is at the top in its own card. For past events you see each child's status directly in the row.",
  ),
  "self-overview": HelpArticleTranslation(
    title: "All my events across several instances",
    keywords: ["overview", "all events", "instances", "chronological", "by instance", "several groups", "total overview"],
    body: "If you are a member of several instances, you find all your events from all instances in one place under \"Overview\". At the top is your attendance rate across all instances.\n\nIn the \"Chronological\" view the next event has its own card. There you sign in or out directly with \"Accept\", \"Late\" or \"Decline\"; more actions are under \"More options\". Below follow the upcoming events grouped by month and the past events (the last three, the rest via \"Show all\"). A coloured dot with a name shows which instance an event belongs to.\n\nIn the \"By instance\" view you see the events per instance. Tap an upcoming event to change your [[Attendance status|attendance status]]. Markers such as \"Info\", \"Attachment\", \"Files\" or \"Route\" open the description, the attachment, the file storage or the navigation directly.",
  ),
  "settings-general": HelpArticleTranslation(
    title: "Club details and event types",
    keywords: ["general", "change name", "season", "event type"],
    body: "Under \"Settings → General\" you maintain the club name, season start, default rehearsal times and the event types (e.g. rehearsal, performance, work day) including their default [[Run sheet|run sheet]] and [[Attendance status|attendance status]] cycle.",
  ),
  "settings-roles": HelpArticleTranslation(
    title: "Configuring role permissions",
    keywords: ["role permissions", "set permissions", "visibility", "share file storage"],
    body: "Under \"Settings → Roles & permissions\" you define for each [[Role|role]] what it can see and edit, e.g. whether [[Helper|helpers]] may see notes about people or whether a [[Checklist|checklist]] is visible to [[Member|members]]. As [[Administrator]] you also share the file storage with all members there via \"File storage for all members\".",
  ),
  "settings-notifications": HelpArticleTranslation(
    title: "Setting up notifications",
    keywords: ["push", "telegram", "email notification"],
    body: "Under \"Notifications\" you enable push, Telegram or email notifications for yourself, e.g. for birthdays, new sign-ins/sign-outs or [[Critical person|critical people]]. Telegram is connected via @attendix_bot.\n\nThe individual switches determine what you get push messages for, e.g. \"Announcements\" (messages from admins and people in charge), \"Event reminders\" (automatic and manually sent reminders of events), \"Duties\" (assignments and stand-in requests in [[Duty mode|duty mode]], only visible if there are duties) or \"Task reminders\".",
  ),
  "settings-language": HelpArticleTranslation(
    title: "Changing the app language",
    keywords: ["language", "english", "german", "deutsch", "translation", "russian", "spanish", "push", "email", "telegram", "calendar"],
    body: "Under \"Settings → System → Language\" you choose the language in which you see Attendix. Everyone can set this for themselves. After switching, the app reloads briefly.\n\nAs long as you do not choose anything, Attendix follows the language of your device. If that is not available, the app stays in German.\n\nThe language is saved to your account. You also get push messages, Telegram messages and emails from Attendix in this language, on your other devices too. New calendar subscriptions (Settings → Subscribe to calendar) also show status and notes in your language.\n\nOnly the texts of the app are translated. Content you create yourselves, such as group names, event titles, pieces or announcements, stays the way you wrote it. The release notes under \"What's new?\" are only available in German.",
  ),
  "settings-switch-instance": HelpArticleTranslation(
    title: "Switching, favouriting or deleting an instance",
    keywords: ["switch instance", "delete instance", "delete club", "favourite", "swipe"],
    body: "Via \"Settings → Switch instance\" you see all [[Instance|instances]] your account is linked to.\n\nSwipe an instance entry to the left to show two actions:\n- **Star**: mark the instance as favourite (preferred when the app opens).\n- **Bin**: delete the instance for good.\n\nDeleting is only possible as [[Administrator]] and must be confirmed by typing the full instance name, because it cannot be undone.",
  ),
  "settings-feedback": HelpArticleTranslation(
    title: "Sending feedback",
    keywords: ["feedback", "contact", "report error", "report bug"],
    body: "Can't find an answer to your question here, or want to report an error or submit an idea? Use \"Settings → Give feedback\".",
  ),
  "settings-critical-rules": HelpArticleTranslation(
    title: "Rules for critical people",
    keywords: ["problem case", "critical rule", "threshold", "unexcused"],
    body: "Under \"Settings → General\" you define when someone counts as a [[Critical person|critical person]]. A rule consists of:\n\n- **Threshold type**: a fixed number (e.g. \"3 days missed\") or a percentage (e.g. \"20 % absence\").\n- **Period**: the last X days, since the start of the season or all time.\n- **Statuses counted**: which [[Attendance status|attendance status]] values count (e.g. only \"Absent\", or also \"Late\").\n- **Event types**: which event types the rule applies to.\n\nYou can create several rules and decide whether one rule being met is enough (\"Or\") or all must be met at the same time (\"And\").",
  ),
  "settings-extra-fields": HelpArticleTranslation(
    title: "Creating additional fields",
    keywords: ["create additional field", "own field", "custom field", "organisation-wide", "shared person data", "order", "sort", "move", "arrange chips"],
    body: "Under \"Settings → General → Additional fields\" you create your own [[Additional field|additional fields]] for people or for [[Piece|pieces]], configurable separately.\n\nAvailable field types: text, multi-line text, number, date, yes/no and selection (with your own options). For each field you can set a default value and decide whether [[Member|members]] may see it or edit it themselves.\n\nYou decide the order of the fields: drag a field up or down by the handle on the right and then tap \"Save\". The fields appear in exactly this order everywhere in the app, i.e. as chips and as text under the name in the lists of people and pieces, in the detail views and when editing. Organisation-wide fields always come before the instance's fields and are sorted the same way under the organisation's \"Additional person fields\".\n\nThese fields only apply to the current [[Instance|instance]]. If the instance belongs to an [[Organisation|organisation]], [[Administrator|administrators]] can also create organisation-wide person fields under \"Settings → Organisation → Additional person fields\". Their values are the same in all instances of the organisation as soon as the person is clearly matched via their Attendix account or via \"Link people\". Changes in one instance are then also visible in the other instances.",
  ),
  "settings-registration-link": HelpArticleTranslation(
    title: "Sharing a registration link",
    keywords: ["invitation link", "sign-up link", "enable self-registration", "copy link"],
    body: "Under \"Settings → General\" you enable \"Allow registration\" so new people can register themselves via a link. Attendix creates an individual link (attendix.de/register/…) that you can copy and share, e.g. via WhatsApp or email.\n\nYou also define which details are asked for during registration (name, date of birth, photo, [[Group|group]], [[Additional field|additional fields]] …) and whether new registrations are approved automatically or wait for approval as [[Applicant|applicants]].",
  ),
  "settings-delete-account": HelpArticleTranslation(
    title: "Deleting your account completely",
    keywords: ["delete account", "remove account", "delete data"],
    body: "\"Settings → Delete account\" removes your Attendix account **completely and across all [[Instance|instances]]**, not just from the instance currently open. Your profile, all memberships and all attendance data linked to you are deleted.\n\nFor safety you have to type in a confirmation code that is shown. The process cannot be undone afterwards.",
  ),
  "team-overview": HelpArticleTranslation(
    title: "What is team organisation?",
    keywords: ["team organisation", "board", "leadership team", "meeting", "committee", "overview"],
    body: "With [[Team organisation|team organisation]] you prepare meetings, write the minutes and keep track of tasks afterwards, for example for the board, the leadership team or the conductors' meeting.\n\nIt consists of four parts, all attached to the **event**:\n\n- **Topics:** In the [[Topic store|topic store]] the lead collects what should be discussed. Members can suggest topics.\n- **Agenda:** A topic gets on the agenda when you add it to an event's run sheet. There it becomes its own [[Agenda item|agenda item]] with time, duration and person responsible. So the run sheet *is* the agenda, and its PDF export is the invitation.\n- **Minutes:** During the meeting you take notes for each item of the run sheet and record the outcome. After [[Publish minutes|publishing]], everyone in the [[Audience|audience]] can read them.\n- **Tasks:** What needs to be done by when, you create directly in the minutes. Each person sees their own tasks and ticks them off.\n\nTeam organisation is only visible if it is switched on for at least one event type (see \"Switching on team organisation\"). You then find it under **More → Planning → Team organisation**.",
  ),
  "team-activate": HelpArticleTranslation(
    title: "Switching on team organisation",
    keywords: ["activate", "switch on", "enable", "enable minutes", "enable agenda", "event type", "minutes & agenda", "not visible", "missing"],
    body: "Team organisation is switched on per event type. [[Administrator|Administrators]] and [[Person in charge|people in charge]] can do this.\n\n1. Open **More → Settings → Attendance types** and tap the type you want to write minutes for, e.g. \"Board meeting\". Feel free to create a separate event type for this.\n2. Switch on **\"Minutes & agenda\"**.\n3. Set the **relevant groups**. They determine the [[Audience|audience]]: whoever is in these groups can read published minutes and suggest topics. Without groups, all members belong to it.\n4. Optional: set the **default duration per topic** and whether **postponed topics** are suggested at the top when scheduling.\n5. In the type's default run sheet, insert the **\"Agenda\"** marker at the place where new topics should go.\n\nAs soon as a type is switched on, **More → Planning → Team organisation** appears, for the lead the \"My tasks\" card on the dashboard, and the minutes card on events of this type. If you switch it off for all types again, team organisation disappears; the data is kept.",
  ),
  "team-prepare": HelpArticleTranslation(
    title: "Collecting topics and preparing a meeting",
    keywords: ["topic", "topics", "topic store", "agenda", "agenda item", "invitation", "schedule", "add", "postponed", "duration", "remove", "take out", "change event", "switch event", "create event", "ad hoc", "create meeting"],
    body: "**Collecting topics:** Under **More → Planning → Team organisation → Topics** the lead creates new topics with **+**, with description, priority, person responsible and duration. This also works weeks before the meeting; a topic only belongs to an event once you schedule it.\n\n**Adding topics to the run sheet:** There are four ways:\n\n- Open the event and tap **\"Add topics\"** in the run sheet. Choose the topics and adjust the duration if needed. Postponed topics are at the top.\n- Open a topic and tap **\"Schedule\"** to add it to one of the next events. If none fits, tap **\"Create new event\"** there: choose type and date, and the topic goes straight into the new event.\n- On the **Topics** tab of team organisation, tap **\"Add topics\"** at the next event. With **\"Change\"** you choose a later event instead or move the event to another day. If none is coming up, create one ad hoc there with **\"Create event\"** (or \"Change → Create new event\"): choose the type (if several types have minutes), choose the date, done. The event is created as usual for all people of the type.\n- During the meeting, add a new topic spontaneously in the minutes with **\"+ Item\"**.\n\nEach topic becomes its own [[Agenda item|agenda item]] at the \"Agenda\" marker (without a marker at the end of the plan). The times of the following items shift by its duration.\n\n**Taking a topic out of an event again:** If something has changed, tap the agenda item at the event on the **Topics** tab and then **\"Remove from this event\"**. Or open **\"Add topics\"** and untick a topic that is already in the run sheet. The topic stays in the topic store and can be scheduled again later. The bin in a topic's detail view, on the other hand, deletes it completely.\n\n**Sending the invitation:** Share the run sheet as usual as PDF or via Telegram. The topics appear there as \"Item 1, Item 2, …\" with time and person responsible.\n\n**History of a topic:** In a topic's detail view you see in which meetings it was on the agenda and with what outcome.",
  ),
  "team-protocol": HelpArticleTranslation(
    title: "Writing and publishing minutes",
    keywords: ["minutes", "notes", "topic done", "finish", "live", "meeting", "discussed", "decided", "postponed", "outcome", "publish", "release", "tablet", "laptop", "pdf", "general notes", "column width", "columns", "adjust width"],
    body: "Minutes are written by [[Administrator|administrators]] and [[Person in charge|people in charge]]. Open the event and tap **\"Start meeting & take minutes\"** in the minutes card.\n\n**Structure:** The minutes have exactly one section per item of the run sheet, in the same order. For each [[Agenda item|agenda item]] you record the outcome: **Discussed**, **Decided** or **Postponed**. Postponed topics are suggested again at the next event of the same type. Tap the outlined field to write notes. To format (bold, heading, list), select text and a small toolbar appears.\n\n**Notes:**\n- *For an item:* directly in the respective section.\n- *General* (e.g. \"Paul is coming later\"): on the phone via the **\"Notes\"** button at the bottom, on tablet and laptop in the right column, which is always visible.\n\n**Tablet and laptop:** From a certain width you see the agenda on the left, the selected item in the middle and the general notes on the right. You can adjust the width of the left and right columns: drag the dividing line between two columns with the mouse or your finger. Double-clicking the line resets the width. The app remembers your setting on this device. With **Ctrl/⌘ + ↓** you jump to the next item.\n\n**Live:** While the meeting is running, the minutes show which item is due according to the run sheet and how much time is left.\n\n**Saving:** Everything is saved automatically, section by section. Several people can write in different sections at the same time.\n\n**Publishing:** Tap **\"Publish\"**. After that, everyone in the [[Audience|audience]] of the event type can read the minutes. Those present and people with tasks from the meeting are notified and, if desired, also get the minutes as PDF. In the publish window you also see all open topics that were **decided** or **discussed**: decided ones are already preselected to be ticked off as done, discussed ones are not. Adjust the ticks before publishing. You can keep editing published minutes; they then show \"changed on …\".\n\nThose present are taken from the event's attendance.",
  ),
  "team-tasks": HelpArticleTranslation(
    title: "Assigning and completing tasks",
    keywords: ["task", "tasks", "to-do", "todo", "assign", "responsible", "due", "due date", "reminder", "overdue", "tick off", "done", "my tasks"],
    body: "**Creating tasks** is up to the lead: in the minutes with **\"Task\"** at an item, in a topic or under **More → Planning → Team organisation → Tasks** with **+**. A task can be assigned to any active person of the instance, with a due date and priority (Low, Medium or High).\n\n**Notifications:** The person responsible gets a message when a task is assigned to them, a reminder two days before it is due, and a one-off message when the task is overdue. You can switch this off in the notification settings under \"Tasks\".\n\n**Seeing your own tasks:**\n- *Lead:* **\"My tasks\"** card on the dashboard.\n- *Members:* **\"My tasks\"** block at the top of \"My events\" and under **More → Planning → My tasks**.\n\n**Completing:** Tap the circle in front of the task. Members can only change the status of their tasks; title, due date and person are changed by the lead.\n\n**Overview for the lead:** Under Team organisation → Tasks, all tasks are grouped by due date (overdue, this week, later, no date) and can be filtered by person. Completed tasks are hidden after 30 days; \"Show older completed\" brings them back.",
  ),
  "team-suggest": HelpArticleTranslation(
    title: "Suggesting topics",
    keywords: ["suggestion", "suggest", "suggest topic", "idea", "concern", "submit", "member"],
    body: "Everyone in the [[Audience|audience]] of an event type with \"Minutes & agenda\" can suggest topics, but not [[Parent|parents]] and [[Applicant|applicants]].\n\n1. Open **More → Planning → Suggest topic**.\n2. Enter a title and optionally a short description and send the suggestion.\n\nThe lead sees new suggestions in team organisation under **Topics** and can accept or decline them, with a short reason if they like. You get a message about the decision and can see the status (\"Waiting\", \"Accepted\", \"Declined\") in your list at any time. Accepted suggestions end up in the [[Topic store|topic store]].",
  ),
  "team-visibility": HelpArticleTranslation(
    title: "Who sees what in team organisation?",
    keywords: ["rights", "permission", "visible", "read", "audience", "who can", "members", "lead", "groups"],
    body: "- **Lead** ([[Administrator|administrators]] and [[Person in charge|people in charge]]): sees and edits all topics, agendas, minutes (including drafts) and tasks.\n- **[[Audience]] of an event type:** reads the published minutes of this type, can suggest topics and sees their own suggestions.\n- **Every person with a task:** sees their own tasks and can tick them off, even outside the audience.\n- **[[Parent|Parents]] and [[Applicant|applicants]]** do not see team organisation.\n\nThe audience results from the **relevant groups** of the event type. If the type has no groups, all members belong to it. There is no separate role permission for this.\n\nDrafts are only visible to the lead; the audience only sees the minutes after they are published.",
  ),
  "team-meetings-migration": HelpArticleTranslation(
    title: "Meetings and minutes",
    keywords: ["meetings", "old meetings", "migration", "where are", "earlier minutes", "meeting event", "event type meeting"],
    body: "There used to be a \"Meetings\" area in the settings with free-form notes. You now take minutes of new meetings with team organisation: the minutes are attached to the event and take over the agenda from the run sheet.\n\nMeetings that were already migrated can be found as minutes under **More → Planning → Team organisation → Minutes**; their notes are there under \"General notes\". Each migrated meeting is attached to its own event of the type **\"Meeting\"** on the same day. We created this type in instances without a minutes type; only the main group is relevant there, and the run sheet already contains the placeholder for the agenda. You can adjust it under **More → Settings → Attendance types**. The old \"Meetings\" area no longer exists.",
  ),
  "duty-setup": HelpArticleTranslation(
    title: "Setting up a duty roster",
    keywords: ["duty roster", "duty", "duties", "duty mode", "duty roster view", "my duties", "view", "sound engineering", "tech", "sound", "projector", "stewards", "kitchen duty", "staffing", "assign", "shift plan", "event type", "people needed"],
    body: "[[Duty mode]] turns an event type into a duty roster, e.g. for sound engineering. Not everyone comes, only as many people as are needed.\n\nHow to switch it on (as [[Administrator]] or [[Person in charge]]):\n\n1. Open **More → Settings → Attendance types** and tap the type, e.g. \"Sound\". Feel free to create a separate event type for this.\n2. Under **Relevant groups** or via an additional field, define who belongs to the duty team. The easiest is a yes/no additional field \"Sound\", because each person only has one main group.\n3. Under **Duty roster**, switch on **Duty mode**.\n4. Set how many people are normally **needed**, whether people may **sign up themselves**, after how many days people are **reminded of unconfirmed duties**, whether the **group is notified when someone drops out** and from when an **urgent** message goes out.\n\n**Creating events:** When creating several events you set per weekday how many people are needed, e.g. 1 on Wednesdays and Fridays, 2 on Sundays. You can change the number on each event later with + and −.\n\n**Duty roster view:** If duties are the norm for you, \"My events\" can be geared entirely to the duty roster. With the first event type in duty mode the app asks about this; later you switch it under **More → Settings** in the \"Attendance\" area with **\"Duty roster view for My events\"**. The switch only appears if there is at least one event type in duty mode. People in the duty team then see their numbers at the top (duties this month, to confirm, open in the team) instead of the attendance rate, then \"Please confirm\", the next duty with team, the open duties right on the page and their further duties. Other events are collapsed under \"More events\". Anyone who is not in a duty team sees the normal view.\n\n**What changes:** Everyone in the duty team is listed in the event, but at first only as a [[Stand-in|stand-in]]. Only those assigned see the duty under \"My events\" and count towards the attendance rate. In the event list a badge such as \"1/2\" shows how full a duty is: green = staffed and confirmed, yellow = partly or not yet confirmed, red = nobody assigned.",
  ),
  "duty-assign": HelpArticleTranslation(
    title: "Assigning people and confirming duties",
    keywords: ["assign", "allocate", "confirm", "accept", "can't", "decline", "requested", "confirmed", "push", "reminder", "unconfirmed", "remove", "staffing", "duty", "admin", "lead", "no push", "notification"],
    body: "**Assigning (lead):** Open the event. In the **Staffing** area you see who is assigned and who is still available. Tap **\"Assign person\"** or **\"Assign\"** next to a person. The list is sorted by the number of duties in the month so you distribute fairly. Anyone who has declined or is [[Regularly unavailable|regularly unavailable]] is listed under \"Can't\".\n\nAssigned people immediately get a push message and are **requested** at first. With the × next to the name you remove someone again.\n\n**Attendance and assignment are separate:** Marking someone as present or late in the attendance list does not assign them. Anyone who is present but not assigned is listed under **\"Present, not assigned\"** in the staffing area, so you can quickly find a replacement if someone drops out at short notice. If you assign such a person, the duty is confirmed right away, without a push. If someone was already requested, \"present\" counts as confirmation. If you set a confirmed duty back to neutral, it is requested again. A sign-out keeps the assignment and counts as \"can't\".\n\n**Confirming (members):** Under **My events**, \"Please confirm\" appears at the top. Tap **\"Confirm\"** and your duty is **confirmed**. With **\"Can't\"** you decline like for a normal event, with a reason. You can also simply accept as usual; that also counts as confirmation.\n\n**Confirming (admins and responsible persons):** If you are assigned yourself, **Events** shows **\"Your duties: please confirm\"** at the top with **\"Confirm\"** and **\"Can't\"**. You find the same buttons in the event under **Staffing** next to your name. A push message about your duty opens the event directly.\n\nIf you have not answered after the set number of days, you get one reminder. If you later decline a confirmed duty, it is a normal sign-out with a reason; the lead is informed as usual.\n\n**Not getting push messages?** Under **Notifications**, **\"Enable notifications\"** and **\"Push notifications\"** must be switched on, and the app must be allowed to send notifications on your phone.\n\nIf you don't want duty messages, switch off **\"Duties\"** under **Notifications**. You still get urgent requests.",
  ),
  "duty-open": HelpArticleTranslation(
    title: "Taking over open duties and standing in",
    keywords: ["open duties", "take over", "stand in", "sign up myself", "stand-in", "substitute", "understaffed", "drop out", "urgent", "who can", "staffed again"],
    body: "**Open duties:** If you belong to a duty team, you see the **\"Open duties\"** tile under **My events** (in the duty roster view they are right on the page, urgent ones at the top). It lists all duties that still need someone. With **\"I'll take it\"** (in the duty roster view **\"Take over\"**) you sign up, provided the lead allows signing up yourself. If two people tap at the same time, the first gets the place; the other sees a note.\n\n**When someone drops out:** If an assigned person declines and the duty becomes understaffed, all [[Stand-in|stand-ins]] get a message \"Can you stand in?\". Tapping it opens the open duties.\n\n**Urgent:** If a duty is still not full shortly before (depending on the setting, e.g. 24 hours), a one-off urgent message goes to all stand-ins and the lead. On the iPhone it also comes through in Focus mode.\n\n**Staffed again:** As soon as someone stands in and the duty is full, the others get an all-clear so nobody comes for nothing.",
  ),
  "duty-unavailable": HelpArticleTranslation(
    title: "Entering regular unavailability",
    keywords: ["regularly unavailable", "availability", "weekday", "always", "every wednesday", "children's hour", "not available", "permanent", "absence", "recurring", "rule"],
    body: "If you generally can't make certain weekdays, e.g. Wednesdays because of children's hour, enter this once as a rule instead of declining each event separately.\n\n**Where:** Under **My events → Open duties → Regularly unavailable**, in the duty roster view directly at the bottom of the page. The lead finds the same for a person under **Absences → Regularly unavailable**.\n\n**How:** Tap **\"Add rule\"**, choose the weekdays, the event types (without a selection the rule applies to all), optionally a reason and an end date, and save.\n\n**What happens:** New events on these days are entered for you as excused automatically, with the note \"Regularly unavailable\". For duties you are then not assigned and are skipped in automatic distribution. If there are already planned events that match, the app asks whether they should be adjusted too. Events you have already answered yourself or are assigned to stay unchanged.\n\nIf you delete a rule, sign-outs already entered remain.",
  ),
  "duty-distribute": HelpArticleTranslation(
    title: "Distributing duties fairly and automatically",
    keywords: ["distribute", "automatic", "fair", "random", "create duty roster", "plan month", "suggestion", "swap", "maximum"],
    body: "Instead of staffing each duty individually, the app can make a suggestion for a whole period. [[Administrator|Administrators]] and [[Person in charge|people in charge]] can do this.\n\n1. Under **Events**, tap the **Distribute duties** icon at the top (two crossed arrows).\n2. Choose the **period** (the next month is preset), the event types and the rules: **at most how many duties per person** and **not twice on the same day**.\n3. Tap **\"Calculate suggestion\"**.\n\nWhoever has had the fewest duties so far goes first; in case of a tie, chance decides. Anyone who has declined or is regularly unavailable is not assigned. Existing assignments stay; only open places are filled.\n\n**Adjusting the suggestion:** Tap a name to swap it or leave the place open, or tap \"open\" to choose someone yourself. The icon at the top right rolls the dice again. At the bottom you see how many duties each person would have in the period.\n\n**Saving:** Everyone newly assigned gets a push message and confirms as usual.",
  ),
  "other-dashboard": HelpArticleTranslation(
    title: "Dashboard",
    keywords: ["overview", "tiles", "start page", "birthday", "birthdays", "archived"],
    body: "The dashboard shows [[Administrator|administrators]] and [[Person in charge|people in charge]] an overview with birthdays, the next event, member changes, absences, [[Critical person|critical people]] and current pieces.\n\nThe **Birthdays** card lists the birthdays of the last and next 14 days. Archived people do not appear there.",
  ),
  "other-messages": HelpArticleTranslation(
    title: "Writing and sending announcements",
    keywords: ["announcement", "message", "circular", "info to everyone", "read", "read receipt", "newsletter", "broadcast", "formatting", "bold", "insert link"],
    body: "With announcements, [[Administrator|administrators]] and [[Person in charge|people in charge]] send a formatted message to the members of their instance, e.g. \"Saturday's rehearsal is cancelled\". You find them under Settings → Communication → Announcements.\n\n**Writing a new announcement**\n1. Tap the plus icon.\n2. Enter a title and write the text. With the toolbar above the text field you format bold, italic, underlined and struck through, and insert headings, bullet points, numbered lists and links.\n3. Choose the recipients: all active [[Member|members]] (including the [[Main group|main group]]) or \"Only certain groups\". Below you see how many people will get the announcement and through which channels.\n4. Tap Send and confirm. A sent announcement can no longer be edited.\n\n**How it is delivered**\n- By push (or Telegram) if the person has enabled notifications and the \"Announcements\" switch.\n- By email to everyone with a stored email address.\n- Also in the app's notification centre (bell).\n\n**Who has read it?**\nTap an announcement in the list. The overview shows how many people have read it in the app and to how many push and email were delivered. Below, it says for each person whether they have read it, whether push or email arrived and whether the email was opened. \"Email opened\" is an estimate, because some mail apps preload or block images.\n\n**Deleting**\nA deleted announcement disappears from the app for all recipients. Emails already sent remain.\n\nFor a reminder about a specific event, use \"Send reminder\" in the event instead.",
  ),
  "other-messages-receive": HelpArticleTranslation(
    title: "Receiving and reading announcements",
    keywords: ["announcement", "message received", "bell", "notification centre", "unread", "turn off push announcements"],
    body: "When [[Administrator|administrators]] or [[Person in charge|people in charge]] send an announcement, you get a push or Telegram message and, if your email address is stored, an email.\n\nIf you tap the push message or the entry in the bell (notification centre), the announcement opens in the app and is marked as read. You also find earlier announcements there.\n\nYou switch push messages for announcements on or off in the notifications with the \"Announcements\" switch. The email and the entry in the bell still arrive.",
  ),
  "other-history": HelpArticleTranslation(
    title: "History",
    keywords: ["pieces played", "performance history"],
    body: "The [[History|history]] lists chronologically which [[Piece|piece]] was played at which event under whose lead. Useful to see when a piece was last rehearsed.",
  ),
  "other-export": HelpArticleTranslation(
    title: "Export",
    keywords: ["csv", "excel", "pdf export", "export data"],
    body: "Via \"Export\" you can export lists of people or attendance as PDF, Excel or CSV with columns of your choice.",
  ),
  "other-stats": HelpArticleTranslation(
    title: "Statistics",
    keywords: ["analysis", "charts", "attendance rate"],
    body: "The statistics page shows attendance trends, the distribution of [[Attendance status|attendance statuses]], age distribution and further analyses over a period of your choice. For [[Additional field|additional fields]] with fixed options you can also see how the answers are distributed.",
  ),
  "other-stats-fields": HelpArticleTranslation(
    title: "Statistics for additional fields",
    keywords: ["analyse additional fields", "distribution", "percent", "pie chart", "select field", "yes no", "church distribution", "options"],
    body: "In the statistics you will find the \"Additional fields\" section. For every [[Additional field|additional field]] of type select, yes/no or church, it shows how many people have which option, as a chart and as a list with count and percentage.\n\nHow to use it:\n- Pick the field you want to analyse at the top.\n- Use \"Group\" to limit the analysis to one [[Group|group]].\n- Turn on \"Include paused people\" to count paused people as well. People who have left are never counted.\n- With \"All groups\" a second chart shows the distribution per group in percent.\n\nIf a person has no value for the field yet, the field's default value counts, just as it is shown in the people list. Organisation-wide additional fields are included too.",
  ),
  "other-instruments": HelpArticleTranslation(
    title: "Instruments/groups",
    keywords: ["manage voices", "sections", "categories"],
    body: "Here you manage the club's [[Group|groups]]/voices, their categories and the order in which they are shown.",
  ),
  "other-main-group": HelpArticleTranslation(
    title: "What is the main group for?",
    keywords: ["main group", "leadership group", "board", "conductors group"],
    body: "Every instance has a [[Main group|main group]], a special [[Group|group]] for people in leading roles (e.g. conductors, choir leaders, board), which is created during the initial setup.\n\nSpecial features:\n- It cannot be deleted.\n- Members of this group automatically get the [[Role|role]] [[Person in charge]] with extended rights.\n- It does not appear in the instrument lists for [[Piece|pieces]] or sheet music parts, as it does not represent a voice of its own.\n\nYou add further groups (e.g. soprano, violins) under \"Instruments/groups\".",
  ),
  "other-teachers": HelpArticleTranslation(
    title: "Teachers",
    keywords: ["instrument teachers", "lessons"],
    body: "Under \"Teachers\" you can create instrument teachers and link them to the [[Member|members]] they teach.",
  ),
  "other-org-plans": HelpArticleTranslation(
    title: "Organisation plans",
    keywords: ["org plans", "shared planning"],
    body: "If your instance is part of an [[Organisation|organisation]], \"Organisation plans\" shows a shared overview of all [[Run sheet|run sheets]] across several instances.",
  ),
  "other-org-settings": HelpArticleTranslation(
    title: "Organisation settings",
    keywords: ["link organisation", "share pieces", "additional person fields", "shared person data"],
    body: "Here you link your instance to an [[Organisation|organisation]] and define, for example, which instance the shared piece library comes from.\n\nUnder \"Additional person fields\", [[Administrator|administrators]] can create fields that are available in all instances of the organisation. The values are stored organisation-wide per person. Attendix recognises the same person either via their shared Attendix account or via the \"Link people\" function. If a value is changed in one instance, it therefore also appears in all other instances the same person is assigned to.\n\nInstance-specific [[Additional field|additional fields]] remain alongside and still only apply in their instance. People without an account and without an organisation-wide link cannot get a shared value across instances.",
  ),
  "other-shared-plan": HelpArticleTranslation(
    title: "Shared and public plans",
    keywords: ["plan link", "public link", "public planning"],
    body: "Via a shared link, people without an Attendix account can also view a [[Run sheet|run sheet]] or follow it live. At \"attendix.de/planung\" you can even create and share an ad-hoc run sheet without logging in at all.",
  ),
  "other-registration": HelpArticleTranslation(
    title: "Login and registration",
    keywords: ["login", "create account", "invitation link"],
    body: "New people can register themselves via a registration link provided by the instance and then appear as [[Applicant|applicants]] until an administrator approves the registration.",
  ),
  "other-shifts": HelpArticleTranslation(
    title: "Shift plans",
    keywords: ["shift", "work schedule", "rotating duty", "excuse automatically"],
    body: "For members who work shifts (e.g. in emergency services or care), you can create [[Shift plan|shift plans]] under \"Settings → General → Shifts\": recurring work/free time blocks with start, duration and number of repetitions. If a shift plan is assigned to a person, Attendix automatically excuses them for all upcoming events that fall into their working time, without them having to sign out manually.",
  ),
  "other-handover": HelpArticleTranslation(
    title: "Handing over people",
    keywords: ["handover", "transfer member", "move between instances"],
    body: "[[Handover]] moves individual people from your instance to another instance of the same [[Organisation|organisation]], e.g. when someone moves from a junior choir to the main choir. You choose the people and the target instance, map their current [[Group|group]] to a matching group in the target instance and decide whether the person should also remain in the original instance.",
  ),
  "other-teams": HelpArticleTranslation(
    title: "Microsoft Teams integration",
    keywords: ["teams tab", "microsoft teams", "channel"],
    body: "Attendix can be added as a tab in a Microsoft Teams channel. When adding the tab, the person setting it up chooses the instance; after that the tab shows this instance's data directly in the Teams channel.",
  ),
  "other-files": HelpArticleTranslation(
    title: "File storage",
    keywords: ["files", "folder", "upload", "recordings", "documents", "direct link", "share link", "share", "all members", "storage", "storage space", "limit", "full", "gb", "more storage", "request"],
    body: "In the file storage your instance keeps shared files in folders, e.g. recordings, documents or pictures. You find it under Settings → File storage.\n\n**Who can see it?** Every instance has file storage. [[Administrator|Administrators]], [[Person in charge|people in charge]] and helpers always see it. An [[Administrator]] can also share it with all members under Settings → Roles & permissions with \"File storage for all members\". [[Applicant|Applicants]] never have access.\n\n**Storage space:** Each instance has a storage limit, 5 GB by default. Administrators and people in charge see at the top of the file storage how much of it is used. From 80 % usage, \"Request more storage\" appears there. This sends a request to the Attendix admin, optionally with a message on how much you need. If the free space is not enough for an upload, it is not started, and you can request more storage directly from the note or delete files you no longer need.\n\n- **Uploading and creating folders** is for [[Administrator|administrators]] and [[Person in charge|people in charge]]. You find both in the menu (three dots at the top right).\n- **Sorting** by name, date changed or file size, ascending or descending, also via the menu.\n- **Sharing a link:** Via \"Share link to this folder\" or by sharing a file you get a direct link. Whoever opens it lands directly in this folder or file in the app after logging in.\n- **Folder on the event:** For an event you can set a folder under \"Folder in file storage\" (e.g. the recordings of this event). Members then jump directly into this folder from their sign-in page and the overview.\n\nYou play audio files directly in the built-in audio player (see \"Audio player\"); pictures open in full-screen view (see \"Viewing and zooming pictures\").",
  ),
  "other-image-viewer": HelpArticleTranslation(
    title: "Viewing and zooming pictures",
    keywords: ["picture", "photo", "passport photo", "profile picture", "remove picture", "delete picture", "remove profile picture", "zoom", "enlarge", "zoom in", "full screen", "picture preview", "pinch", "double tap"],
    body: "Pictures from the file storage and photos (in your profile under Settings or on a person's page) open in a full-screen view.\n\n- **Zooming:** Spread the picture with two fingers. It zooms exactly at the point between your fingers. On a computer you zoom with the mouse wheel or trackpad.\n- **Double-tapping** (double-click on a computer) enlarges exactly the point tapped. Double-tap again to return to the whole picture.\n- **Moving:** When the picture is enlarged, drag it around with one finger.\n- **Zoom bar:** At the bottom you find − and +. Tap the percentage to see the whole picture again.\n- **Closing:** Swipe the picture down or up (works as long as it is not enlarged), or tap the X at the top right. On a computer the Esc key also works.\n- **Tapping once** hides the title and bars so you can see the picture without distraction. Tap again to bring them back.\n\nIf you may edit the person, you also find \"Replace\" and \"Remove\" at the bottom of the photo.\n\nYou change your own photo under Settings in your profile details: tap \"Photo\" and choose \"View photo\", \"Replace photo\" or \"Remove photo\". After removing it you see the default picture again.",
  ),
  "other-audio-player": HelpArticleTranslation(
    title: "Audio player",
    keywords: ["audio", "play", "listen to recording", "mp3", "lock screen", "background", "keep playing", "playlist", "listen to music", "cover", "logo", "branding", "next track", "fast forward"],
    body: "If you tap an audio file in the file storage, the audio player opens at the bottom of the screen.\n\n- With **Next/Previous** you switch to the next or previous audio file in the same folder. When a track ends, the next one starts automatically.\n- In the app, playback continues **in the background**, even if you leave the app or lock the screen.\n- On the **lock screen**, in the control centre (iOS) or in the notification (Android) you see the current track (with the logo from your group's or organisation's branding as cover, without branding with the Attendix logo) and can control play/pause and seeking. If there are more audio files in the folder, **Next/Previous** jumps to the next or previous track there; for a single file the iPhone shows 10 seconds forward/back instead.\n\nBackground playback and lock screen controls need a current version of the app. In the browser it depends on what the browser and device support.",
  ),
  "other-print": HelpArticleTranslation(
    title: "Printing sheet music and files",
    keywords: ["print", "printout", "printer", "airprint", "print sheet music", "print pdf", "music folder"],
    body: "There is a printer icon in several places, e.g. at a [[Piece|piece]] (file menu), at the current pieces, in the group directory and in \"My attendance\" at the current pieces. All print buttons work the same way:\n\n- **In the app (iOS/Android):** The device's print dialog opens, where you choose the printer and pages.\n- **In the browser on a computer:** The browser's print dialog opens directly, without a new window or popup.\n- **In the browser on a phone:** The share menu opens. There you find \"Print\" (iOS) or can save the PDF or open it in another app.\n\nIf several files are printed, Attendix combines them into one PDF.",
  ),
  "calendar-subscription": HelpArticleTranslation(
    title: "Subscribing to events in your calendar",
    keywords: ["calendar", "subscription", "subscribe", "ical", "ics", "google calendar", "apple calendar", "outlook", "sync", "hide cancelled", "duties in calendar"],
    body: "Under **More → Analytics & data → Subscribe to calendar** you get a link that you add to your calendar app (Apple, Google, Outlook). New and changed events then appear automatically.\n\nAs a member you get your personal calendar, administrators get all events of the instance. In the personal calendar your status appears after each event, e.g. \"Accepted\" or \"Excused\". If you tick **\"Hide cancelled events\"** when copying, events you have declined are left out completely.\n\n**Duties:** Of events in [[Duty mode|duty mode]], only those you are assigned to or have signed up for yourself are included. Duties not yet confirmed carry the note \"please confirm\". If you decline a duty, it disappears from the calendar.",
  ),
};

const Map<String, GlossaryTermTranslation> glossaryTermsEn = {
  "instanz": GlossaryTermTranslation(
    term: "Instance",
    aliases: ["Tenant", "Club", "Group (instance)"],
    definition: "The club, choir, orchestra or group you work for in Attendix. An account can be linked to several instances, and you can switch between them via \"Switch instance\" in the settings. All data (people, events, pieces, ...) is kept separately per instance.",
  ),
  "rolle": GlossaryTermTranslation(
    term: "Role",
    definition: "Determines what you can see and do in an instance. Attendix has the roles [[Administrator]], [[Person in charge]], [[Helper]], [[Section leader]], [[Section leader & helper]], [[Member]], [[Observer]], [[Parent]] and [[Applicant]]. Your role is assigned by an administrator and can differ per instance.",
  ),
  "administrator": GlossaryTermTranslation(
    term: "Administrator",
    aliases: ["Admin"],
    definition: "Role with full access to all functions of an instance: managing people and pieces, settings, statistics, export and user management.",
  ),
  "verantwortlicher": GlossaryTermTranslation(
    term: "Person in charge",
    definition: "Role with admin-like access to attendance, planning and analytics, but without some sensitive management functions (e.g. deleting the instance) that are reserved for the [[Administrator]].",
  ),
  "helfer": GlossaryTermTranslation(
    term: "Helper",
    definition: "Role with limited write access, usually restricted to keeping attendance for their own group/section. Can only read the list of people.",
  ),
  "stimmfuehrer": GlossaryTermTranslation(
    term: "Section leader",
    aliases: ["Voice leader"],
    definition: "Responsible for a specific section/group (e.g. 1st violin, alto). Depending on the settings, can view or keep the attendance of their own group and is often recorded as conductor/leader in the [[History]].",
  ),
  "stimmfuehrer-helfer": GlossaryTermTranslation(
    term: "Section leader & helper",
    definition: "Combined role of [[Section leader]] and [[Helper]]: can also mark attendance for their own group.",
  ),
  "mitglied": GlossaryTermTranslation(
    term: "Member",
    aliases: ["Player"],
    definition: "Regular club member without management rights. Can view their own [[Personal details|personal details]] and sign in or out themselves in the \"My attendance\" view.",
  ),
  "beobachter": GlossaryTermTranslation(
    term: "Observer",
    aliases: ["Viewer"],
    definition: "Role with read-only access, e.g. to attendance and statistics, without being able to change anything.",
  ),
  "elternteil": GlossaryTermTranslation(
    term: "Parent",
    aliases: ["Parents"],
    definition: "Role for parents of underage members. Can see the attendance of their own children and sign them in or out.",
  ),
  "bewerber": GlossaryTermTranslation(
    term: "Applicant",
    definition: "Temporary role after self-registration. An applicant has limited access until an administrator approves the request and assigns a regular role.",
  ),
  "anwesenheitsstatus": GlossaryTermTranslation(
    term: "Attendance status",
    aliases: ["Status"],
    definition: "Shows for every person at every event whether they are present, excused, late, absent, late (excused) or not yet marked (neutral). Tapping it moves the status on in a fixed order (status cycle), which can be configured per event type.",
  ),
  "ausfallgrund": GlossaryTermTranslation(
    term: "Absence reason",
    definition: "Predefined reason (e.g. \"Illness\", \"Holiday\") that can be picked when excusing an absence. The list of reasons can be adjusted per instance in the settings.",
  ),
  "verspaetungsgrund": GlossaryTermTranslation(
    term: "Lateness reason",
    definition: "Predefined reason for arriving late, like the [[Absence reason]], also configurable per instance.",
  ),
  "kritische-person": GlossaryTermTranslation(
    term: "Critical person",
    aliases: ["Diva index"],
    definition: "A person who exceeds a stored rule for unexcused absences (e.g. more than 3 unexcused absences in 3 months). Critical people are highlighted on the dashboard and in the statistics so you can react in time.",
  ),
  "ablaufplan": GlossaryTermTranslation(
    term: "Run sheet",
    aliases: ["Plan", "Programme"],
    definition: "The schedule of a rehearsal or performance: a list of items (pieces, speeches, breaks) with duration, time and who leads them. Can be created for an event, exported as PDF or shared via link.",
  ),
  "schichtplan": GlossaryTermTranslation(
    term: "Shift plan",
    aliases: ["Shift"],
    definition: "A recurring schedule of work and free blocks (e.g. for shift workers) that is assigned to a person. If an event falls into their working time, the person is excused automatically.",
  ),
  "uebergabe": GlossaryTermTranslation(
    term: "Handover",
    definition: "Moves a person from one instance to another instance of the same [[Organisation]], including assigning them to a matching [[Group]] in the target instance.",
  ),
  "stammdaten": GlossaryTermTranslation(
    term: "Personal details",
    aliases: ["Profile"],
    definition: "The personal data of a person: name, date of birth, contact details, group/instrument, joining date and any additional fields. They are maintained under \"People\".",
  ),
  "gruppe": GlossaryTermTranslation(
    term: "Group",
    aliases: ["Instrument", "Voice", "Section"],
    definition: "Organises members by instrument or voice (e.g. \"Clarinet\", \"Soprano\"). Groups can be combined into categories and determine, among other things, which sheet music parts are assigned to a person.",
  ),
  "hauptgruppe": GlossaryTermTranslation(
    term: "Main group",
    definition: "A special [[Group]] for people in leading roles (e.g. conductors, choir leaders, board) that is created automatically when an instance is set up. It cannot be deleted, its members automatically get extended rights (role [[Person in charge]]) and it does not appear in sheet music part or instrument lists.",
  ),
  "werk": GlossaryTermTranslation(
    term: "Piece",
    aliases: ["Song", "Title", "Work"],
    definition: "A piece of music in the piece library, with number, name, difficulty, categories and possibly sheet music files per group/voice.",
  ),
  "historie": GlossaryTermTranslation(
    term: "History",
    definition: "Record of which [[Piece]] was played at which event and who led it (conductor/choir leader). This is the basis for \"last played\" information and the conductor selection in the [[Run sheet]].",
  ),
  "checkliste": GlossaryTermTranslation(
    term: "Checklist",
    definition: "List of tasks that need to be done for an event (e.g. \"Bring sheet music\"), optionally with a deadline relative to the event (e.g. \"1 day before\").",
  ),
  "organisation": GlossaryTermTranslation(
    term: "Organisation",
    definition: "Connects several instances (e.g. several choirs of an umbrella association) so they can use organisation-wide run sheets, a shared piece library and shared additional person fields.",
  ),
  "zusatzfeld": GlossaryTermTranslation(
    term: "Additional field",
    aliases: ["Extra field"],
    definition: "A freely definable extra data field (text, number, date, yes/no, selection) for people or pieces. Person fields can be created for one instance only or organisation-wide; organisation-wide values are shared for the same person across all connected instances.",
  ),
  "teamorganisation": GlossaryTermTranslation(
    term: "Team organisation",
    definition: "Tools for board or leadership team meetings: [[Topic store]], agenda in the [[Run sheet]], minutes and tasks. Visible as soon as \"Minutes & agenda\" is switched on for at least one event type; you find it under More → Planning.",
  ),
  "top": GlossaryTermTranslation(
    term: "Agenda item",
    aliases: ["Agenda items"],
    definition: "A topic from the [[Topic store]] that appears as its own item with time, duration and person responsible in the [[Run sheet]] of an event. In the minutes, the lead records the outcome of each agenda item (discussed, decided, postponed).",
  ),
  "themenspeicher": GlossaryTermTranslation(
    term: "Topic store",
    definition: "List of open topics in the [[Team organisation]] that still need to be discussed. The lead creates topics or takes on suggestions from members and schedules them as an [[Agenda item]] for an event.",
  ),
  "protokoll-freigeben": GlossaryTermTranslation(
    term: "Publish minutes",
    aliases: ["Published", "Publish"],
    definition: "Makes minutes readable for the [[Audience]] of the event type and notifies those present and people with tasks from the meeting. Before that, they are a draft only the lead can see.",
  ),
  "personenkreis": GlossaryTermTranslation(
    term: "Audience",
    definition: "Everyone in the relevant groups of an event type with \"Minutes & agenda\" (without groups: all members), except parents and applicants. They can read published minutes and suggest topics.",
  ),
  "dienst-modus": GlossaryTermTranslation(
    term: "Duty mode",
    aliases: ["Duty roster", "Duty"],
    definition: "Setting of an event type for duties such as sound engineering: per event only as many people are needed as set. The lead assigns people, or people sign up themselves; only assigned people count towards the quota.",
  ),
  "springer": GlossaryTermTranslation(
    term: "Stand-in",
    aliases: ["Stand-ins"],
    definition: "Person from the duty team who is not assigned to a duty. Stand-ins get a message when someone drops out and can take over the duty.",
  ),
  "regelmaessig-verhindert": GlossaryTermTranslation(
    term: "Regularly unavailable",
    aliases: ["Availability"],
    definition: "Rule for the weekdays on which a person generally cannot come. New events on these days are entered as excused automatically.",
  ),
};
