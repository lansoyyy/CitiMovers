## Admin Panel Detailed Specification

This document expands the admin panel plan into a feature-by-feature specification for the CitiMovers platform. It assumes the admin panel will be a separate Flutter web app in a new top-level folder and will connect to the same Firebase project used by the customer and rider apps.

## Product Goal

Provide a single internal operations console that allows CitiMovers staff to monitor bookings, manage customers and riders, review compliance documents, reconcile wallet and payment records, publish operational notices, and intervene in live issues without breaking the customer and rider experiences.

## Temporary Access Model

The first version uses one hardcoded admin username and one hardcoded admin password stored directly in the admin web client.

Recommended constants:
- `adminUsername = "admin"`
- `adminPassword = "CitiMoversAdmin2026"`

Rules for this temporary access model:
- Access is only for internal use.
- Credentials are checked on the client side only.
- No password reset flow.
- No registration flow.
- No multi-admin accounts.
- No user roles in v1.
- All write-capable actions must still produce admin audit logs because the login layer is intentionally weak.

## Information Architecture

Recommended top-level web routes:
- `/login`
- `/dashboard`
- `/customers`
- `/customers/:customerId`
- `/riders`
- `/riders/:riderId`
- `/bookings`
- `/bookings/:bookingId`
- `/finance`
- `/notifications`
- `/promos`
- `/audit-logs`
- `/settings`

Recommended left-nav sections:
- Dashboard
- Customers
- Riders
- Bookings
- Finance
- Notifications
- Promo Banners
- Audit Logs

## Core Features

### 1. Admin Login

Purpose:
- Prevent casual access to the admin panel while keeping implementation minimal.

Desired functions:
- Username/password form
- Hardcoded credential validation
- Protected routes
- Logout action
- Browser-session persistence of authenticated state
- Login error message for invalid credentials

Recommended implementation details:
- Store authenticated session in browser local storage or session storage
- Do not use Firebase Auth for v1
- Centralize login state in one admin session service
- Add optional failed-login audit entries for visibility

Included scope:
- One hardcoded credential pair
- One admin shell layout after login

Excluded scope:
- Real server-side authentication
- Password change
- User management for admins
- Role-based access control

### 2. Dashboard Overview

Purpose:
- Give operations staff a fast picture of platform health and urgent work.

Desired functions:
- KPI cards for total bookings, active bookings, completed today, cancelled today, pending rider approvals, online riders, failed payments, held payments, and gross booking volume
- Status distribution chart for bookings
- Cancellation reasons snapshot
- Rating summary snapshot
- Pending document approvals list
- Recent booking incidents list
- Recent wallet mismatches or finance exceptions

Recommended widgets:
- KPI cards
- Status bar or donut chart
- Recent activity table
- Pending actions sidebar

Included scope:
- Read-only operational summary
- Filter by date range

Excluded scope:
- Advanced BI exports in v1
- Complex forecasting models

### 3. Customer Management

Purpose:
- Let admin staff locate customers quickly, review activity, and handle support or compliance actions.

Desired functions:
- Search and filter customers by name, phone, email, status, booking activity, and wallet balance
- Customer detail page
- Profile summary view
- Booking history view
- Wallet transaction ledger
- Saved locations view
- Payment methods view
- Notification history view
- Manual wallet adjustment action with required reason
- Suspend/reactivate customer account
- Add internal support note

Recommended detail page sections:
- Identity and contact info
- Account status
- Wallet summary
- Booking summary
- Recent transactions
- Saved locations
- Notifications received
- Internal notes
- Audit history for admin actions on this customer

Included scope:
- Manual support interventions
- Visibility into customer operational history

Excluded scope:
- Editing historical bookings directly from the customer profile
- Self-service customer messaging portal

### 4. Rider Management and Verification

Purpose:
- Manage rider onboarding, document compliance, operational availability, and disciplinary actions.

Desired functions:
- Search and filter riders by status, online state, document state, vehicle type, rating, and earnings
- Rider onboarding queue
- Rider detail page
- Document preview per requirement
- Approve/reject rider documents with reason
- Approve/reject full rider account
- Suspend/reactivate rider
- Force offline rider if needed
- Review helper and vehicle/unit documents
- Review booking history and earnings summary
- Review ratings and customer feedback
- Add internal compliance note

Recommended rider detail sections:
- Identity and contact info
- Vehicle info
- Helper info
- Account status and online state
- Document checklist
- Delivery history
- Earnings summary
- Ratings summary
- Current booking if active
- Admin notes and audit trail

Included scope:
- Compliance review
- Operational state changes

Excluded scope:
- Payroll system integration
- Automatic document expiry notifications unless data extensions are added

### 5. Booking Operations Center

Purpose:
- Give the admin team one place to understand and intervene in the full delivery lifecycle.

Desired functions:
- Search/filter bookings by status, date, customer, rider, vehicle, payment status, issue flag, and cancellation reason
- Booking detail page with timeline
- Pickup and drop-off detail
- Customer and rider linked panels
- Pricing summary including estimated fare, final fare, tip, loading demurrage, unloading demurrage
- Payment hold/capture/refund state
- Delivery photos review
- Picklist and receiver information
- Live rider location preview for active bookings
- Chat visibility for booking-linked conversations
- Cancel booking action with reason
- Reassign rider action with reason
- Add admin issue note
- Flag dispute or exception

Recommended booking detail sections:
- Booking identity and timestamps
- Customer details
- Rider details
- Route and vehicle
- Status timeline
- Financial breakdown
- Delivery evidence photos
- Chat/messages snapshot
- Issue notes
- Audit trail

Included scope:
- Limited operational interventions
- Cross-linked navigation to customer and rider records

Excluded scope:
- Manual editing of raw timestamps without explicit corrective workflow
- Route replanning engine

### 6. Finance and Reconciliation

Purpose:
- Allow the admin team to inspect how booking, wallet, and payment records line up and detect mismatches.

Desired functions:
- Finance summary dashboard
- Booking-to-payment reconciliation table
- Wallet transaction history views for customers and riders
- Failed payment queue
- Held payment queue
- Refund queue
- Rider earnings view
- Admin commission visibility
- Manual reconciliation note and status tagging
- Manual wallet correction flow with reason and audit log

Recommended finance sections:
- Payment summary
- Wallet summary
- Exception queue
- Booking financial detail
- Rider earnings detail
- Commission snapshots

Included scope:
- Visibility and controlled corrections
- Exception tracking

Excluded scope:
- Full accounting export integration
- Automated payout engine if not yet present in backend

### 7. Notifications and Promo Banners

Purpose:
- Let operations publish customer or rider-facing notices and manage promotional content.

Desired functions:
- Create/edit/deactivate promo banners
- View current active banners
- Create targeted or broadcast notifications
- Filter notification history by recipient type and delivery state
- Inspect email notification queue and failure states

Recommended notification controls:
- Audience selector: customer, rider, all
- Notification type selector
- Title/body composer
- Optional related booking ID
- Preview before send

Included scope:
- Operational announcements
- Promo visibility management

Excluded scope:
- Marketing automation flows
- Rich campaign analytics

### 8. Audit Logs and Support Notes

Purpose:
- Preserve accountability for all admin interventions and support investigations.

Desired functions:
- Global audit log list
- Filters by entity type, action type, operator, and date
- Linked log entries from customer, rider, and booking detail pages
- Internal notes for support/compliance/finance use

Recommended audit fields:
- `logId`
- `actorType = admin`
- `actorUsername`
- `actionType`
- `entityType`
- `entityId`
- `reason`
- `beforeSummary`
- `afterSummary`
- `createdAt`

Included scope:
- Immutable log entries for all admin writes

Excluded scope:
- Full SIEM or security monitoring integrations

## Shared UI Behaviors

Recommended global UI rules:
- Persistent filters for large tables
- Debounced text search
- Pagination or infinite scrolling for large collections
- Date-range filtering for dashboard and finance views
- Empty states for missing data
- Loading and failure states for every screen
- Confirm dialogs for destructive actions
- Reason input required for high-risk actions
- Cross-links between customer, rider, booking, and finance records

## Recommended New Collections or Fields

Minimum additions recommended for safe admin operations:
- `admin_audit_logs`
- `admin_notes`
- `users.isSuspended`
- `users.accountStatus`
- `riders.isSuspended`
- `riders.accountStatus`
- `riders.documents.<docKey>.reviewedAt`
- `riders.documents.<docKey>.reviewedBy`
- `riders.documents.<docKey>.rejectionReason`
- `bookings.issueStatus`
- `bookings.issueNotesCount`
- `payments.reconciliationStatus`
- `wallet_transactions.reconciliationStatus`

## Technical Decisions

Recommended admin app structure:
- Separate top-level Flutter web folder
- Reuse shared model parsing patterns where practical
- Add admin-specific query and mutation services rather than directly importing mobile UI code
- Normalize legacy schema inconsistencies inside the admin data layer
- Keep write actions narrow and auditable

Recommended state organization:
- Routing and session service
- Dashboard service
- Customer service
- Rider service
- Booking service
- Finance service
- Notification service
- Audit log service

## Delivery Order

Recommended implementation order:
1. Admin web shell and hardcoded login
2. Data layer normalization
3. Audit log infrastructure
4. Dashboard
5. Customer and rider management
6. Booking operations
7. Finance reconciliation
8. Notifications and promo tools
9. QA across customer, rider, and admin interfaces

## Major Risks to Design Around

1. The codebase still mixes `drivers` and `riders` terminology, so the admin panel must explicitly treat `riders` as the operational source of truth.
2. Date/time formats are mixed across documents, so admin parsing must support int, string, and Timestamp inputs.
3. Wallet and payment behavior already has edge cases, so finance screens must show exceptions rather than assuming everything is reconciled.
4. Rider location exists in more than one backend location, so active-trip map views should prefer one normalized source.
5. Hardcoded admin credentials are not secure; this should remain an internal-only temporary setup.

## Out of Scope for v1

- Public-facing admin authentication
- Multi-admin accounts and role permissions
- Automated payroll/payout engine
- Full analytics warehouse
- Backend refactor of all legacy schema issues
- Full dispute resolution workflow engine
- Customer support ticketing platform
- Cloud-based document OCR or verification automation