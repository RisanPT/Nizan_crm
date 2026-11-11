# Stylist / Consultation module

Implements the **Team N Makeovers SRS v1.2** (bridal client management, video consultation and appointment scheduling) inside the existing Nizan CRM. Written for the IT team and for whoever runs user-acceptance testing.

Status: code complete on the working tree, **not yet committed, deployed, or run against a database.** Everything below was verified with offline tests only (see [Testing](#testing)).

---

## 1. What it does

A stylist (or stylist lead) can:

1. Find a bridal enquiry (an existing CRM *lead*) and **book a consultation** with a date, time, duration, stylist, and either a pasted Meet/Zoom link (video) or a location (in-person).
2. See a **shared calendar** (month / week), a filterable **list**, and a **dashboard** with today's work, outcomes still to record, pending follow-ups, enquiry status and a team report.
3. **Share the invitation** to the bride through WhatsApp click-to-chat (the app opens WhatsApp with the message prefilled; staff press send).
4. **Reschedule, cancel, mark no-show, or complete** a consultation, recording notes, preferences and next steps.
5. Get **in-app and browser notifications** for assignments, changes and reminders.

A consultation is a separate record from a booking: the booking/appointment flow is unchanged.

### Decisions already made (SRS section 13)

| Decision | Choice |
|---|---|
| Video platform | Staff paste a Google Meet or Zoom link. No video integration. |
| Bride invitation | WhatsApp click-to-chat. No WhatsApp template approval needed. |
| Calendar | Internal only. No Google/Outlook sync. |
| Bride portal / recording / payments | Out of scope (as in the SRS). |

### Still open

- **Who gets a login** (business owner + IT lead).
- **Retention and deletion rules** for client data and consultation notes (SRS section 8). Until agreed, consultations are never deleted by the app — see [Known limitations](#8-known-limitations).

---

## 2. Setting it up (admin steps)

The module is controlled by **role permissions** — no code change per user.

1. Deploy backend + app (see [Deployment checklist](#6-deployment-checklist)).
2. In **Settings → Roles & Permissions**, create two roles. The *Consultations* feature appears in the list.

   | Role | Permissions to tick | Effect |
   |---|---|---|
   | **Stylist** (suggested key `stylist`) | Only the **sub-permissions**: *Consultation Calendar* (`consultations.calendar`). Add *Consultation Notes* only if stylists should read **other** stylists' notes (normally leave off). | Sees and acts on **their own** consultations only. Reads/writes notes on their own. |
   | **Stylist Lead** (suggested key `stylist_lead`) | The **whole Consultations module** (the parent `consultations` key). | Sees **everyone's** consultations, assigns/reassigns, books over a clash, reads all notes, sees the team report, is told about new enquiries, can back up the consultations data. |

   > The rule: **a parent key means the whole module; sub-keys are exact.** That is how the Flutter `Access` class and the backend already treat every module.

3. Set each role's **landing page** to `/consultations/dashboard` (or `/consultations`).
4. Give a stylist who needs to open the enquiry page the **Sales → Leads** sub-permission (`sales.leads`). Without it they can still book from the consultations screens; they just won't get the "Enquiry" shortcut.
5. Create the users (Settings → Users) and assign the role.
6. Admins and managers need nothing extra: they always have full access.

A role change is enforced by the server within about 30 seconds (its permission cache). The app reads a user's permissions when they sign in, so **menus update the next time that user signs in** (ask them to sign out and back in).

### What each permission shows

| Key | Where it shows |
|---|---|
| `consultations` (any) | Sidebar: *Stylist Dashboard* and *Consultations*; lead page card; API access |
| `consultations.calendar` | Calendar / list / booking (all module users) |
| `consultations.notes` | Reading other stylists' notes, preferences, next steps |
| `consultations.reports` | Same as the whole module for visibility: *all* stylists' data, team report, assign/override |

---

## 3. Business rules

- **Clashes.** A stylist cannot have two *Scheduled* consultations that overlap. Back-to-back slots (10:00–10:45, 10:45–11:30) are fine. A clash returns HTTP 409 listing the clashing bookings; only a stylist lead can choose "Book anyway", and that choice is recorded in the history.
- **Status.** Scheduled → Completed / Cancelled / No-show. These are final; to change a time, reschedule *before* it ends. "Rescheduled" is a history entry, not a status.
- **Client status (SRS FR-11)** is *derived*, so `Lead.status` and the sales reports are untouched:

  | Shown as | When |
  |---|---|
  | Cancelled | Lead is Lost |
  | Appointment Confirmed | Lead is Converted |
  | Consultation Scheduled | Any Scheduled consultation |
  | Follow-up Required | Lead is in Follow-up / Pending Lost Approval, or a consultation ended (Completed / No-show) |
  | Contacted | Lead is Contacted / Qualified |
  | New | Otherwise |

  The SRS's separate *Completed* client status is not derived (it would need the linked booking's state).
- **Notes** (notes, preferences, next steps) are removed from every API response for anyone who is not the assigned stylist and lacks `consultations.notes`. List/summary endpoints never include notes at all.
- **History.** Every change appends who/when/what to the consultation's `history`. It records *which* fields changed, never the notes text. It lives on the consultation, deliberately **not** in `LeadActivity`, because the sales reports count all lead activities.
- **Times** are stored in UTC and the API requires an explicit timezone. Day filters (`from`/`to`) and "today" are **IST** days. The app sends the device's calendar day, so devices should be on IST.

### Notifications

| Event | Who is told | Type |
|---|---|---|
| Booked for a stylist by someone else | That stylist | `consultation_assigned` |
| Rescheduled / cancelled by someone else | The assigned stylist | `consultation_changed` |
| Reassigned | New stylist (assigned) and previous stylist (changed) | both |
| ~24 hours before | The assigned stylist | `consultation_reminder` |
| ~1 hour before | The assigned stylist | `consultation_reminder` |
| New enquiry created | Roles holding the **parent** `consultations` key (stylist leads), excluding managers/admins who already get the usual notice | `new_lead` |

The person who made a change is never notified about it. Admins only ever receive the month-end summary (existing rule).

**Reminders have no scheduler.** Like the lead follow-up alerts, they are generated when notifications are next fetched by any signed-in client (throttled to once a minute). Each is claimed atomically in `remindersSent`, so it is sent once. If nobody has the app open, a reminder is late until someone does. Booking a slot already inside a window does not trigger that window's reminder. There is no native phone alarm for consultations.

---

## 4. Technical reference

### Backend (`nizan_crm_backend`)

| File | Purpose |
|---|---|
| `models/Consultation.js` | Schema, derived `endsAt`, number `CN-YYMMDD-NNNN`, indexes |
| `utils/consultationRules.js` | **Pure** rules: access, validation, overlap, status, reminder tiers, report maths, wording |
| `utils/consultationNotify.js` | Notifications + the reminder sweep |
| `controllers/consultationController.js` | Handlers and the guard / validation middleware |
| `routes/consultationRoutes.js` | Mounted at `/api/consultations` in `server.js` |
| `models/Role.js` | `consultations` added to `PERMISSION_KEYS` |
| `utils/notify.js` | Three new notification types |
| `controllers/notificationController.js` | Runs the reminder sweep on fetch |
| `controllers/leadController.js` | New-enquiry notice to stylist leads; blocks deleting an enquiry that has consultations |
| `controllers/backupController.js` | `consultations` department backup |

**Collection `consultations`** — key fields: `consultationNo` (unique), `leadId`, `stylistId` (User), `scheduledAt`, `durationMins`, `endsAt`, `status`, `mode`, `meetingProvider`, `meetingLink`, `location`, `notes`, `preferences`, `nextSteps`, `completedAt`, `cancelledAt`, `cancelReason`, `rescheduleCount`, `inviteSentAt`, `inviteChannel`, `remindersSent[]`, `history[]`, `createdBy`. Indexes: `{stylistId, scheduledAt}`, `{status, scheduledAt}`, `{leadId, scheduledAt}`, unique `consultationNo`. Free-text limits: notes 5000, preferences/next steps 2000, location 300, reason 500.

**API** (all need login + a consultations permission; admin/manager always allowed)

| Method & path | Purpose |
|---|---|
| `GET /` | List: `from`, `to` (IST days), `status`, `leadId`, `stylistId`, `limit` (≤500). No notes. |
| `POST /` | Book: `leadId`, `scheduledAt` (ISO **with timezone**), `durationMins`, `stylistId?`, `mode`, `meetingLink?`, `location?`, `force?` |
| `GET /:id` | One consultation (notes only if allowed) |
| `PUT /:id` | Meeting details and notes (not time/stylist) |
| `PATCH /:id/reschedule` | Time, duration, stylist, reason, `force?` |
| `PATCH /:id/cancel` · `/no-show` · `/complete` | Final transitions (`complete` takes notes) |
| `PATCH /:id/invite-sent` | Record that the invite was shared |
| `GET /summary` | Dashboard/report for a date range (default: this IST month) |
| `GET /stylists` | Users that can be assigned (stylists get themselves) |
| `GET /leads/search?q=` | Find an enquiry to book (name/phone, 20 results) |
| `GET /lead/:leadId` | A client's consultations + derived status |

Errors: `400` validation, `403` permission, `404` unknown id, `409` clash (`code: SCHEDULE_CONFLICT`, with `conflicts[]`) or wrong state.

### App (`Nizan_crm`)

`lib/features/consultations/` — `data/` (models), `services/consultation_service.dart`, `controllers/consultation_provider.dart` (Riverpod), `presentation/screens/` (calendar, list, form, detail, dashboard) and `presentation/widgets/` (tile, dialogs, lead card, shared helpers). Wiring: `app_permissions.dart`, `access_control.dart`, `app_router.dart` (`/consultations…`), `sidebar.dart`, `sales_menu_sheet.dart`, `lead_details_screen.dart` (card), `data_refresh.dart` (`ref.refreshData.consultations()`), notification screen/watcher (icons, refresh).

---

## 5. Testing

All offline — **no database, no server.**

```bash
# Backend (74 tests: rules, controller behaviour with stubbed models, existing suites)
cd nizan_crm_backend
node --test tests/*.test.js

# App (29 tests: parsing, WhatsApp text, and every screen at phone + desktop width)
cd Nizan_crm
flutter test test/consultation_test.dart test/consultations_dashboard_widget_test.dart test/consultations_screens_widget_test.dart
flutter analyze lib/features/consultations
```

What these do **not** prove: real MongoDB behaviour (indexes, the `$addToSet` reminder claim, populate), the real HTTP/auth stack, real WhatsApp opening, or how it looks and feels in a browser. Cover that with the end-to-end run below.

### End-to-end run (before launch)

> ⚠ The CRM's production database holds live data and **starting the backend writes to it** (index creation, default-role top-up). Run the end-to-end pass against a **separate local database copy** with its own `.env`, never production.

1. Point `.env` at a local MongoDB (a restored backup or an empty database seeded with a few leads and users).
2. Start the backend and the app locally.
3. Create the Stylist and Stylist Lead roles and two stylist users + one lead user (section 2).
4. Work through the UAT checklist below.

---

## 6. Deployment checklist

1. **Back up first** (Backup screen → full backup, or a database snapshot).
2. Deploy the backend. **First start** creates the `consultations` collection and its indexes and does nothing to existing data. No migration, no backfill.
3. Deploy the app build.
4. Create the roles and users (section 2). Check a stylist login lands on the dashboard and sees nothing from other stylists.
5. Smoke test: book, reschedule, cancel one consultation; confirm a notification arrives.
6. **Rollback:** untick *Consultations* on the roles (the server stops serving the module within ~30 seconds; menus disappear at each user's next sign-in) and redeploy the previous builds. The `consultations` collection can stay; it is not referenced by anything else.

Backups: the full backup already includes the collection; a **Consultations** department backup is available to roles with the parent `consultations` key.

---

## 7. User-acceptance checklist (SRS section 11)

Run as a **Stylist**, a **Stylist Lead**, and an **admin** where noted.

| # | SRS acceptance criterion | Steps | Pass |
|---|---|---|---|
| 1 | Create, update, search, assign and track bridal client records | Search an enquiry in *New consultation*; book it; open it from the lead page card; change meeting details | ☐ |
| 2 | Consultations can be scheduled, rescheduled and cancelled, with meeting details visible to the right users | Book with a Meet link; reschedule with a reason; cancel with a reason; confirm history lists all three | ☐ |
| 3 | The bride can receive and use the invitation | *Share invite* opens WhatsApp with date, time, stylist and link; send to a test phone; open the link | ☐ |
| 4 | Consultations appear correctly in the shared calendar | Month and week views show the booking on the right day/time; cancelled hidden unless *Show cancelled* | ☐ |
| 5 | Schedule changes are consistent and clashes are identified | Book the same stylist at an overlapping time → clash dialog. Back-to-back is allowed. As Stylist: no override. As Lead: *Book anyway* works and is flagged in history | ☐ |
| 6 | Reminders and notifications work | Lead books for a stylist → stylist is told; book a slot ~50 min ahead and wait for the 1-hour reminder; reschedule/cancel → stylist told | ☐ |
| 7 | Team members can assign and update follow-up tasks | Complete a consultation with next steps; the lead appears under *Pending follow-ups* when its status is Follow-up; mark one *No-show* | ☐ |
| 8 | Role permissions prevent unauthorised access | Stylist A cannot open Stylist B's consultation (403) or see their notes; a user without the permission has no menu item and `/consultations` redirects; a Stylist cannot reach IT/Settings | ☐ |
| 9 | End-to-end tests pass and the team completes UAT | Run section 5 commands; walk the whole SRS workflow (steps 1–8 of SRS section 6) once with the stylist team | ☐ |

Extra checks worth doing: the dashboard "Outcome to record" list after letting a consultation's time pass; the team table for a Stylist Lead only; deleting an enquiry that has a consultation is refused with a clear message; a department backup of *Consultations*.

---

## 8. Known limitations

- **Double booking race.** The clash check runs before saving and there is no database-level lock. Two people booking the *same stylist and slot at the same instant* could both succeed. Both would then show on the calendar, and the next booking or reschedule would flag the clash. Low likelihood; fix later with a post-save re-check if it ever happens.
- **Clashes only consider consultations**, not a stylist's bookings, trials, leave or shifts.
- **Retention/deletion.** There is no delete endpoint, and an enquiry with any consultation (even a cancelled one) cannot be deleted from the app. Removing records is a deliberate IT task until the retention policy is agreed.
- **Reminders** depend on someone having the app open (section 3). A true scheduler would be a separate decision.
- **Stylists can search all enquiries** by name/phone when booking (name, phone, event type/date, location and status only). Confirm this suits your privacy position.
- **Stylists cannot create a new enquiry** from the consultation screens; they use the Sales → Leads screen if their role allows it.
- **No export** of the report to Excel/PDF.
- **Enquiry-status report** is capped at 3,000 enquiries per period.
- **Time zone.** Everything is IST-based; devices set to another zone will show local times and send local calendar days.
- **WhatsApp** opens click-to-chat; the app cannot tell whether the message was actually sent, only that WhatsApp was opened.

---

## 9. SRS traceability

| Requirement | Where |
|---|---|
| FR-01, FR-02 Client & enquiry records | Existing leads + consultation search/booking |
| FR-03 Scheduling | Booking form, reschedule/cancel dialogs |
| FR-04 Video meeting details | `meetingLink`, `meetingProvider`, Join/Copy, WhatsApp invite |
| FR-05 Consultation notes (role-restricted) | Notes fields + server-side redaction |
| FR-06 Calendar | Calendar screen |
| FR-07 Changes and conflicts | `findConflicts`, 409 + override rule, history |
| FR-08 Notifications | `consultationNotify.js` |
| FR-09 Tasks / follow-ups | Next steps, existing lead follow-ups, dashboard follow-up list |
| FR-10 Communication log | Invite-shared history entry; calls/WhatsApp from the detail screen |
| FR-11 Client status | `deriveClientStatus` (derived) |
| FR-12 Search and views | List screen filters; lead search |
| FR-13 Reporting | Dashboard + `/summary` |
| FR-14 User & permission management | Roles & Permissions (existing) + new permission key |
| NFR Security / Privacy / Auditability | Role-scoped API, notes redaction, input validation, history |
| NFR Reliability | Atomic reminder claim, errors surfaced to the user |
| NFR Backup | Full backup + Consultations department backup |
| NFR Maintainability | This document; pure rules unit-tested |
