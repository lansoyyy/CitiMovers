## Plan: Admin Panel Web Integration

Build a separate Flutter web admin app in a new top-level folder so operations UI stays isolated from the public landing page and the mobile customer/rider apps. Reuse the existing Firebase project and shared domain models, but add an admin-specific data layer that normalizes current schema inconsistencies (`drivers` vs `riders`, mixed timestamp formats, Firestore vs Realtime Database location sources). The first release should cover both operational and monitoring use cases, protected by a single hardcoded username/password pair stored in the admin web client as an explicit temporary constraint.

**Steps**
1. Phase 1: Foundation. Create a new top-level Flutter web project folder named `admin_web`; initialize Firebase/web config against the same backend; add route guarding, shell layout, navigation, and a hardcoded login gate with browser-session persistence only. This step blocks all other work.
2. Phase 1: Shared admin data layer. Add repository/query services for users, riders, bookings, wallet transactions, payments, notifications, promo banners, reviews, and chat rooms. Normalize the current schema differences by treating `riders` as the source of truth for drivers, handling string/int/Timestamp date variants, and reading rider location from Firestore summaries with optional Realtime Database drill-down for active trips. This step depends on 1 and blocks steps 4 through 9.
3. Phase 1: Admin safeguards. Add a minimal audit trail collection such as `admin_audit_logs` and standard admin action wrappers so every write from the web panel records actor, target entity, before/after summary, timestamp, and reason. This step depends on 2 and should be completed before any write-capable admin feature is enabled.
4. Phase 2: Dashboard and KPI overview. Build overview cards, tables, and filters for active bookings, pending rider approvals, failed/held/refunded payments, wallet imbalance checks, cancellation trends, and ratings snapshots. This depends on 2 and can run in parallel with 5, 6, 7, 8, and 9.
5. Phase 2: Customer management. Build customer search, profile detail, booking history, wallet history, payment methods view, saved locations view, notifications view, and limited operational actions such as manual wallet adjustment, profile correction, and account suspension flagging with audit logging. This depends on 2 and 3 and can run in parallel with 4, 6, 7, 8, and 9.
6. Phase 2: Rider management and document verification. Build rider onboarding queue, rider profile detail, vehicle/helper document review, approval/rejection actions with reason capture, force-offline/suspend/reactivate controls, earnings snapshot, and delivery history drill-down. This depends on 2 and 3 and can run in parallel with 4, 5, 7, 8, and 9.
7. Phase 2: Booking operations center. Build a booking list/detail workspace with timeline, current status, customer/rider linkage, pickup/drop-off data, photos, demurrage fields, payment hold/capture/refund state, live location preview, chat visibility, and limited actions such as reassign rider, cancel booking, add issue note, and admin override requests for fare/demurrage disputes. This depends on 2 and 3 and can run in parallel with 4, 5, 6, 8, and 9.
8. Phase 2: Finance and reconciliation. Build payment and wallet views for customer charges, payment holds, refunds, rider earnings, admin commission visibility, and booking-to-transaction reconciliation. Add exception views for missing wallet transactions, balance mismatches, failed payment records, and incomplete payout workflows. This depends on 2 and 3 and can run in parallel with 4, 5, 6, 7, and 9.
9. Phase 2: Notifications and promo/content management. Build admin tools for promo banners, in-app notifications, and outbound email queue visibility so operations can publish promotions, send service alerts, and inspect unsent/failed email notifications. This depends on 2 and 3 and can run in parallel with 4, 5, 6, 7, 8, and 9.
10. Phase 3: Data model extensions. Add only the minimum extra fields/collections needed for safe admin work: account suspension flags for users/riders, rider document review metadata (`reviewedAt`, `reviewedBy`, `rejectionReason`), booking issue/admin note records, and reconciliation status metadata for payments or wallet exceptions. This step depends on the design choices made in 5 through 9 and should be finalized before full QA.
11. Phase 3: Cross-interface verification. Validate that admin writes are reflected correctly in the customer and rider apps: rider approval changes rider login and availability behavior, booking changes appear in customer tracking and rider deliveries, wallet/payment actions match balances shown in mobile screens, and promo/notification changes surface in the existing interfaces. This depends on 4 through 10.

**Feature Map**
1. Admin login and session.
Desired functions: single login form, hardcoded username/password constants, route guard, logout, idle-session reset on browser refresh if desired, and optional audit entry on login success/failure.
Data correlation: no business collections are modified directly; this feature gates access to all downstream reads/writes. Because credentials are hardcoded in client code, treat this only as a temporary internal-access mechanism.
2. Dashboard and operations summary.
Desired functions: active booking count, bookings by status, pending rider approvals, online rider count, customer growth, gross booking value, held/refunded payment totals, commission estimate, cancellation heatmap, and recent incidents queue.
Data correlation: reads `bookings`, `users`, `riders`, `payments`, `wallet_transactions`, `reviews`, and `notifications`. Mirrors the same booking and earnings states currently displayed in customer history, rider deliveries, and rider earnings tabs.
3. Customer management.
Desired functions: search/filter customers, inspect full profile, view saved locations and payment methods, see booking history and wallet ledger, send notification, suspend/reactivate customer, and perform manual wallet corrections with reason capture.
Data correlation: uses `users` as the primary customer profile source, plus `saved_locations`, `payment_methods`, `wallet_transactions`, `bookings`, and `notifications`. Changes here affect customer login eligibility, wallet balances seen in the customer app, and booking capability.
4. Rider management and verification.
Desired functions: onboarding queue, document preview, approve/reject per document or whole account, capture rejection reasons, manage helper/unit documents, force online/offline state, suspend/reactivate rider, and inspect ratings/earnings/delivery history.
Data correlation: uses `riders`, `rider_settings`, `wallet_transactions`, `reviews`, and `bookings`. Approval/suspension changes must align with rider signup, rider profile document status, rider availability filtering, and rider earnings screens.
5. Booking operations center.
Desired functions: global booking search and filtering, timeline/status history, pickup/drop-off detail, vehicle and pricing view, photos, receiver name, picklist items, customer/rider linkage, chat visibility, live location, cancel/reassign flows, and incident/admin notes.
Data correlation: uses `bookings` as the operational source of truth and correlates `delivery_requests`, `users`, `riders`, `reviews`, `chatRooms`, `messages`, and payment/wallet records. Any admin change here must appear in customer tracking screens, rider delivery-progress screens, notifications, and rider/customer booking history.
6. Finance and reconciliation.
Desired functions: booking-payment ledger, held/captured/refunded status views, customer wallet debit/refund history, rider earnings history, commission visibility, mismatch detection, failed payment queue, and manual correction workflow with audit logs.
Data correlation: uses `payments`, `wallet_transactions`, `bookings`, `users`, and `riders`. This feature bridges customer wallet deductions at booking creation, refund behavior on cancellation, rider earning accumulation on completion, and the 18% admin share currently surfaced in rider earnings UI.
7. Notifications, announcements, and promo banners.
Desired functions: create/update/deactivate banners, send targeted or broadcast in-app notifications, inspect unread counts and delivery-state notifications, and review queued email notifications with sent/failed status.
Data correlation: uses `promo_banners`, `notifications`, and `email_notifications`. Banner changes should appear in the customer-facing promotional surfaces, while notification sends should land in customer or rider notification screens.
8. Audit trail and support notes.
Desired functions: immutable log of all admin actions, filters by entity type, before/after summaries, operator reason text, and optional issue notes attached to bookings, riders, or customers.
Data correlation: should reference entity IDs from `users`, `riders`, `bookings`, `payments`, and `wallet_transactions`. This is critical because the panel includes operational writes and the login method is intentionally insecure.

**Relevant files**
- `d:\Flutter Projects\citimovers\landing_page\lib\main.dart` - reference for Flutter web bootstrapping and theming patterns already used in the repo.
- `d:\Flutter Projects\citimovers\lib\main.dart` - current app bootstrap; confirms the mobile app is rider-first and does not currently route to an admin experience.
- `d:\Flutter Projects\citimovers\lib\utils\app_constants.dart` - existing user-type constants include `admin`, but collection constants are inconsistent with current Firestore usage.
- `d:\Flutter Projects\citimovers\lib\services\firestore_schema_seeder.dart` - best current snapshot of collection structure and sample data; also shows `riders` as the primary driver collection.
- `d:\Flutter Projects\citimovers\lib\models\user_model.dart` - customer profile shape for admin customer detail views.
- `d:\Flutter Projects\citimovers\lib\rider\models\rider_model.dart` - rider profile, helper data, and document-key taxonomy for verification tools.
- `d:\Flutter Projects\citimovers\lib\models\booking_model.dart` - booking lifecycle, demurrage fields, photos, review, and completion metadata.
- `d:\Flutter Projects\citimovers\lib\services\booking_service.dart` - booking creation, wallet holds/refunds, available-booking queries, review submission, and status-update logic the admin panel must observe.
- `d:\Flutter Projects\citimovers\lib\services\auth_service.dart` - customer session conventions and phone normalization; useful if admin needs customer account lookups.
- `d:\Flutter Projects\citimovers\lib\rider\services\rider_auth_service.dart` - rider document requirements, rider storage conventions, and account state transitions.
- `d:\Flutter Projects\citimovers\lib\services\wallet_service.dart` - rider/customer wallet and earning transaction behavior for reconciliation screens.
- `d:\Flutter Projects\citimovers\lib\services\payment_service.dart` - current payment transaction flow and gaps.
- `d:\Flutter Projects\citimovers\lib\services\notification_service.dart` - current notification write/read behavior for admin broadcast and history views.
- `d:\Flutter Projects\citimovers\docs\BOOKING_INTEGRATION_PLAN.md` - reference for intended end-to-end booking states across customer and rider interfaces.
- `d:\Flutter Projects\citimovers\PRODUCTION_READINESS_REPORT.md` - reference for current risks that the admin panel should expose instead of hiding.

**Verification**
1. Web auth smoke test: confirm the hardcoded admin username/password allows entry, invalid credentials are blocked, protected routes redirect to login, and logout clears the browser session.
2. Data integrity test: verify the admin repositories can read mixed timestamp formats and both current and legacy driver/rider references without crashing list/detail screens.
3. Customer correlation test: change a customer status or wallet balance in admin, then confirm the same values appear in the customer app profile, wallet, and booking flows.
4. Rider correlation test: approve or reject rider documents in admin, then confirm rider profile/document screens and rider availability logic reflect the updated statuses.
5. Booking correlation test: perform an admin booking action such as cancel, reassign, or add an issue note; confirm booking history, delivery-progress views, and notifications update for both customer and rider clients.
6. Finance correlation test: compare one booking across `bookings`, `payments`, and `wallet_transactions` to confirm hold, refund, earning, and commission views reconcile correctly.
7. Promo/notification test: publish a banner and send a notification from admin; confirm banner visibility and notification delivery in the correct mobile interface.
8. Audit test: confirm every admin write produces an audit log entry with target entity, reason, and timestamp.
9. Manual multi-session test: keep one customer app, one rider app, and the admin web panel open simultaneously and verify real-time updates remain coherent under active booking changes.

**Decisions**
- Admin panel location: separate top-level web folder in this repo, not the existing public landing page app.
- Admin scope for v1: both monitoring and operational core workflows.
- Login model: one hardcoded admin username/password pair embedded in the admin web client; no Firebase Auth, password reset, or multi-admin roles in v1.
- Source of truth for driver data: `riders` collection; legacy `drivers` references should be adapted or normalized inside the admin data layer.
- Source of truth for operations: `bookings` plus linked payment/wallet/notification collections.

**Further Considerations**
1. Recommended: keep admin writes limited to reviewed operational actions only. Do not let the panel directly mutate derived totals such as rider rating aggregates or total earnings without an explicit corrective workflow.
2. Recommended: add explicit `isSuspended` or `accountStatus` fields for both users and riders instead of overloading existing fields inconsistently.
3. Recommended: if the admin panel becomes internet-facing later, replace hardcoded credentials with server-side auth before expanding beyond internal use.

**Companion Documents**
- `docs/admin/ADMIN_PANEL_DETAILED_SPEC.md` - full admin feature specification, access model, routes, scope, risks, and recommended data additions.
- `docs/admin/ADMIN_PANEL_DATA_CORRELATION.md` - feature-by-feature mapping of admin capabilities to current Firestore collections and their effects on customer and rider interfaces.