## Admin Panel Data Correlation Map

This document maps each planned admin panel feature to the current CitiMovers data model and explains how changes made in the admin web interface relate to the existing customer and rider interfaces.

## Source of Truth Summary

Primary operational collections:
- `users`
- `riders`
- `bookings`
- `delivery_requests`
- `wallet_transactions`
- `payments`
- `reviews`
- `notifications`
- `promo_banners`
- `email_notifications`
- `saved_locations`
- `payment_methods`
- `rider_settings`
- `chatRooms`
- `chatRooms/{chatRoomId}/messages`

Supporting system concerns:
- Rider live location may be read from `riders` summary fields and possibly Realtime Database-based rider location storage depending on current implementation.
- Legacy code still references `drivers` in some places, but the active rider account model is centered on `riders`.

## 1. Admin Login

Collections read:
- None required for the first version if the credential pair is hardcoded.

Collections written:
- Optional `admin_audit_logs` for login success/failure.

Customer interface correlation:
- None directly.

Rider interface correlation:
- None directly.

Notes:
- This feature is only an access gate for the admin app.
- It does not replace or alter customer or rider authentication.

## 2. Dashboard

Collections read:
- `bookings`
- `users`
- `riders`
- `payments`
- `wallet_transactions`
- `reviews`
- `notifications`

Primary metrics and their sources:
- Active bookings: `bookings.status`
- Completed and cancelled totals: `bookings.status`
- Pending rider approvals: `riders.status`, document statuses inside `riders.documents`
- Online riders: `riders.isOnline`
- Gross booking value: `bookings.estimatedFare`, `bookings.finalFare`
- Held/refunded payment totals: `bookings.paymentStatus`, `payments.status`, `wallet_transactions.type`
- Rating snapshot: `reviews.rating`, `riders.rating`
- Cancellation patterns: `bookings.cancellationReason`

Customer interface correlation:
- Dashboard booking counts must line up with customer booking history and delivery-tracking states.
- Wallet summaries should correlate to wallet balances visible in the customer profile or payment flow.

Rider interface correlation:
- Online rider counts, active delivery counts, and earnings snapshots must correlate to rider availability and rider earnings tabs.

## 3. Customer Management

Primary collection:
- `users`

Related collections:
- `bookings`
- `wallet_transactions`
- `saved_locations`
- `payment_methods`
- `notifications`
- `reviews`

Important fields from `users`:
- `userId`
- `name`
- `phoneNumber`
- `email`
- `photoUrl`
- `userType`
- `walletBalance`
- `favoriteLocations`
- `emailVerified`
- `createdAt`
- `updatedAt`

Suggested admin actions:
- Suspend/reactivate customer account
- Manual wallet adjustment
- Add internal support note
- Send targeted notification

Recommended extra fields for admin safety:
- `users.isSuspended`
- `users.accountStatus`
- `users.lastSuspendedAt`
- `users.lastSuspendedReason`

Customer interface correlation:
- Suspending a customer should block or restrict future booking actions in the customer app.
- Wallet adjustments must match wallet balance and wallet history visible to the customer.
- Notifications sent from admin must appear in the customer notification screens.

Rider interface correlation:
- Indirect only through shared bookings if the customer has active or historical trips.

## 4. Rider Management and Verification

Primary collection:
- `riders`

Related collections:
- `bookings`
- `wallet_transactions`
- `reviews`
- `rider_settings`
- `notifications`

Important fields from `riders`:
- `riderId`
- `name`
- `phoneNumber`
- `email`
- `photoUrl`
- `vehicleType`
- `vehiclePlateNumber`
- `vehicleModel`
- `vehicleColor`
- `vehiclePhotoUrl`
- `status`
- `isOnline`
- `rating`
- `totalDeliveries`
- `totalEarnings`
- `currentLatitude`
- `currentLongitude`
- `helper1`
- `helper2`
- `documents`
- `createdAt`
- `updatedAt`

Document review data model already implied by current app:
- Each `documents.<docKey>` item stores at least `name`, `url`, `status`, and `uploadedAt`

Recommended extra document review fields:
- `reviewedAt`
- `reviewedBy`
- `rejectionReason`

Suggested admin actions:
- Approve/reject rider document
- Approve/reject rider account
- Suspend/reactivate rider
- Force rider offline
- Add compliance note

Customer interface correlation:
- Customer driver assignment should only pull riders who remain approved and active.
- Suspended or rejected riders should not appear as available for new bookings.

Rider interface correlation:
- Document status changes must appear in rider profile and onboarding flows.
- Suspension should restrict rider acceptance of bookings.
- Force-offline changes should affect rider availability behavior.
- Earnings summary must match what riders see in their earnings tabs.

## 5. Booking Operations Center

Primary collection:
- `bookings`

Related collections:
- `delivery_requests`
- `users`
- `riders`
- `wallet_transactions`
- `payments`
- `reviews`
- `chatRooms`
- `chatRooms/{chatRoomId}/messages`
- `notifications`

Important booking fields:
- `bookingId`
- `customerId`
- `customerName`
- `customerPhone`
- `driverId`
- `pickupLocation`
- `dropoffLocation`
- `vehicle`
- `bookingType`
- `scheduledDateTime`
- `estimatedDuration`
- `distance`
- `estimatedFare`
- `finalFare`
- `status`
- `paymentMethod`
- `paymentStatus`
- `notes`
- `createdAt`
- `updatedAt`
- `acceptedAt`
- `loadingStartedAt`
- `loadingCompletedAt`
- `unloadingStartedAt`
- `unloadingCompletedAt`
- `loadingDemurrageFee`
- `unloadingDemurrageFee`
- `deliveryPhotos`
- `receiverName`
- `picklistItems`
- `completedAt`
- `cancellationReason`
- `reviewId`
- `rating`
- `tipAmount`
- `reviewedAt`

Suggested admin actions:
- Cancel booking with reason
- Reassign rider with reason
- Add issue note
- Mark booking for dispute review
- View linked chat and photo evidence

Recommended extra booking fields:
- `issueStatus`
- `issueNotesCount`
- `lastAdminActionAt`
- `lastAdminActionBy`

Customer interface correlation:
- Booking status, rider assignment, fare, and photo evidence must stay consistent with customer booking history and delivery tracking.
- Cancel actions must reflect immediately in customer notifications and booking lists.
- Reassignment should update the rider shown to the customer.

Rider interface correlation:
- Booking changes must update rider deliveries lists, active delivery progress, and rider notifications.
- Reassignment must remove the booking from the old rider and attach it to the new rider consistently.

## 6. Finance and Reconciliation

Primary collections:
- `payments`
- `wallet_transactions`

Related collections:
- `bookings`
- `users`
- `riders`

Important `wallet_transactions` fields already implied in code and schema:
- `transactionId` or document ID
- `userId`
- `type`
- `amount`
- `previousBalance`
- `newBalance`
- `balance`
- `description`
- `referenceId`
- `createdAt`

Important `payments` fields:
- `paymentId`
- `bookingId`
- `payerId`
- `payeeId`
- `amount`
- `method`
- `status`
- `createdAt`
- `updatedAt`
- `metadata`

Important booking-side finance fields:
- `paymentStatus`
- `paymentHeldAt`
- `paymentCapturedAmount`
- `paymentCapturedFromBalance`
- `paymentCapturedToBalance`
- `estimatedFare`
- `finalFare`
- `loadingDemurrageFee`
- `unloadingDemurrageFee`
- `tipAmount`

Suggested admin actions:
- Review finance exception
- Mark reconciliation status
- Add reconciliation note
- Perform manual wallet correction with reason

Recommended extra fields:
- `payments.reconciliationStatus`
- `payments.reconciliationNote`
- `wallet_transactions.reconciliationStatus`
- `wallet_transactions.reconciliationNote`

Customer interface correlation:
- Customer wallet deductions at booking time should match admin ledger views.
- Refunds after rider cancellation must appear in customer wallet balance and transaction history.

Rider interface correlation:
- Rider earnings should align with completed-booking outcomes and any earning ledger entries.
- Admin commission visibility should reflect the same revenue split logic already shown in rider earnings UI.

## 7. Notifications and Promo Banners

Primary collections:
- `notifications`
- `promo_banners`
- `email_notifications`

Important `notifications` fields:
- `notificationId`
- `recipientId`
- `recipientType`
- `title`
- `message`
- `type`
- `isUnread`
- `bookingId`
- `amount`
- `createdAt`
- `data`

Important `promo_banners` fields:
- `bannerId`
- `title`
- `description`
- `imageUrl`
- `actionUrl`
- `isActive`
- `startDate`
- `endDate`
- `displayOrder`
- `createdAt`
- `updatedAt`

Important `email_notifications` fields:
- `to`
- `subject`
- `htmlBody`
- `textBody`
- `templateId`
- `templateData`
- `type`
- `referenceId`
- `isSent`
- `sentAt`
- `errorMessage`
- `createdAt`

Suggested admin actions:
- Send targeted notification
- Send broadcast notification
- Create or update promo banner
- Activate/deactivate promo banner
- Review email queue failures

Customer interface correlation:
- Customer-targeted notifications must appear in customer notification screens.
- Promo banners should align with customer home promotional areas if those surfaces consume `promo_banners`.

Rider interface correlation:
- Rider-targeted notifications must appear in rider notifications screens.
- Service advisories for riders should be filterable by recipient type.

## 8. Audit Logs and Support Notes

Recommended new collections:
- `admin_audit_logs`
- `admin_notes`

Suggested `admin_audit_logs` fields:
- `logId`
- `actorUsername`
- `actionType`
- `entityType`
- `entityId`
- `reason`
- `beforeSummary`
- `afterSummary`
- `createdAt`

Suggested `admin_notes` fields:
- `noteId`
- `entityType`
- `entityId`
- `noteType`
- `body`
- `createdBy`
- `createdAt`

Customer interface correlation:
- No direct customer-facing display in v1.
- Logs and notes help support staff understand prior interventions affecting customer records.

Rider interface correlation:
- No direct rider-facing display in v1.
- Logs and notes support compliance and operations reviews affecting rider accounts or bookings.

## Data Normalization Requirements for the Admin App

1. Treat `riders` as the driver source of truth.
2. Support mixed timestamp formats across collections:
- Firestore `Timestamp`
- epoch milliseconds as `int`
- ISO strings
3. Treat booking-linked `driverId` as a rider ID in operational screens.
4. Do not assume `wallet_transactions` uses one stable schema; support both `balance` and `previousBalance/newBalance` patterns where present.
5. Handle missing optional fields safely, especially for helper documents, rider emails, booking review data, and payment metadata.

## Recommended Cross-Link Rules

1. Customer detail page should link to all bookings for that customer.
2. Rider detail page should link to all bookings for that rider.
3. Booking detail page should link back to the related customer and rider records.
4. Finance detail records should deep-link to the related booking, customer, or rider where possible.
5. Notifications with booking IDs should link to the related booking detail page.
6. Reviews should link both to the booking and the rider profile.

## Write Safety Rules

1. Every admin write must create an audit log entry.
2. High-risk writes must require a reason:
- wallet adjustments
- rider suspension/reactivation
- customer suspension/reactivation
- booking cancel/reassign
- document rejection
3. The admin panel should avoid editing derived aggregate fields directly where possible:
- `riders.rating`
- `riders.totalDeliveries`
- `riders.totalEarnings`
4. Prefer writing corrective records or status flags instead of silently overwriting historical operational data.

## Validation Checklist for Correlation

1. A rider approval or suspension change must alter rider availability in the rider flow and affect future customer-driver matching.
2. A booking cancel or reassignment must update both customer and rider booking views and notifications.
3. A wallet adjustment must be visible in both admin finance views and the customer or rider wallet-facing screens, depending on the target.
4. A promo banner change must appear in the correct surface that consumes `promo_banners`.
5. An admin note or audit log entry must be traceable from the affected record even if it is not shown to customers or riders.