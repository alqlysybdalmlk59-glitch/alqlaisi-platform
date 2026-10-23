# Al Qulaisi - Issue Register and Completion Checklist

Updated: 2026-10-22
Working branch: `audit/backend-foundation-fixes`

A green CI run means the checks in that workflow passed; it is not proof that every production integration has been tested.

## Resolved in this branch

- Unauthenticated business routes: orders, vendor management, product management, and support use database-backed authentication and role dependencies.
- Role trust: protected requests reload the account and role from the database; inactive/suspended accounts are denied.
- Google account identity: the backend stores and uniquely indexes the verified Google `sub`. It does not automatically merge an existing password account by email alone; a customer must authenticate to that account and explicitly link Google through `/auth/google/link`. Conflicting subjects, duplicate emails, unverified emails, invalid tokens and non-customer roles are rejected.
- Store ownership: seller permissions require a matching current `owner_user_id`/`store_id` relationship on an active store. Administrative linking requires a verification note; linking, approval, rejection, suspension and restoration are recorded in `vendor_ownership_history`.
- Tenant isolation: sellers may only read/manage their own store products and orders.
- Product publication and prices: a new seller product is pending, zero-priced and unavailable. Admin sets the customer price; seller then manually toggles availability. Reviews are stored by the API and accepted only from the owning customer for products in a delivered order; one review per product per order is enforced.
- Checkout: server derives price, product availability/publication, store, and delivery fee from database data; rejects unsupported payment methods, ignores supplied totals, and splits a mixed cart into per-store orders.
- Order identity/state: user identity comes from the token/database, seller order updates are store-scoped and constrained to allowed transitions. Every creation/status change is recorded in an order-status audit log, and only the customer, owning seller, or admin can read that log.
- Support ticket identity: creator fields are server-supplied; users can query their own tickets.
- Production startup: PostgreSQL, TLS, long JWT secret, Google server client ID, exact HTTPS CORS origins, explicitly configured allowed hosts (no development defaults), required migrated tables/columns, and security headers are enforced as deployment gates.
- Administration: the web dashboard can link a store to an account and activate/suspend users through protected routes; owner reassignment is rejected by default.
- Customer checkout: the confirmation button now submits to the backend, handles failures and displays server-calculated order totals.
- API compatibility: `/api/auth/*` and `/api/checkout` match the customer client's `/api` base URL.
- Added regression tests for store-owner binding, approval, server pricing/delivery totals, and tenant isolation.

## Still open or requiring external configuration

1. Google OAuth must be configured with `GOOGLE_CLIENT_ID`, `GOOGLE_SERVER_CLIENT_ID`, the final Android application ID and signing SHA-1, then tested on a device. Automated tests mock Google verification and cannot prove real credentials work.
2. Forgot-password deliberately returns 501 because there is no verified SMS/email recovery channel with expiry/rate limiting.
3. The customer and seller apps now have checked-in Android Gradle wrappers and CI builds debug APKs; customer phone validation is covered by Flutter tests. The admin web dashboard is syntax-checked. Real browser/device purchase and operations acceptance tests are still required.
4. Internal dispatch is now implemented on the feature branch: admin-only assignment/reassignment of a named courier and phone, a dispatch timestamp, transition to “قيد التوصيل”, and order-history audit events. The admin Orders & Delivery view exposes the assignment action. A separate authenticated courier account/employee directory, route optimization, map tracking, and device push notifications remain out of scope.
5. Version 1 payment remains cash on delivery. No online payments or transfers are implemented.
6. Commission percentage and settlement policy remain undecided. No real financial transfers are implemented.
7. Product ratings are API-backed and gated by delivered order ownership; order status notifications now read persistent history and refresh in-app every 30 seconds. Favourites remain device-local, and a server-side customer address book and OS push notifications still need implementation.
8. SQLite is the default DB. Setting `DATABASE_URL` to PostgreSQL does not migrate SQLite data. Back up and test a data migration, validate row counts and owner mappings before cutover.
9. Before production, set a strong JWT secret, explicit CORS origins and allowed hosts, deploy behind HTTPS ingress/rate limiting (Nginx template added), keep port 8000 private, verify audit logs, and test backup/restore.
10. Reconcile legacy store rows with null `owner_user_id` and resolve duplicated/inaccurate mappings through admin review; each manual link now requires a recorded verification note.
11. `/api/ai/sales-insights` is still a placeholder and is not connected to actual analytics.
12. Current CI compiles Python, runs auth/access-control/production-config tests, tests customer phone validation, analyzes and debug-builds the customer and seller Android apps, and syntax-checks the admin dashboard JavaScript. It does not replace real Google OAuth, release signing, device/browser end-to-end tests, or deployment verification.

## Acceptance gates

- [ ] Latest CI after each new change is green.
- [ ] Google tests cover verified-subject reuse, explicit linking after password authentication, conflicting identities, unverified email, invalid token, duplicate email, and admin-role rejection.
- [ ] Production settings fail closed on SQLite, missing OAuth configuration, missing explicit ALLOWED_HOSTS, wildcard CORS, or wildcard hosts.
- [ ] Seller ownership mismatch, server-calculated checkout, and store-owner audit lifecycle tests pass.
- [ ] Customer checkout passes static analysis and a manual test against a running API.
- [ ] Customer and seller debug APK builds and analysis pass; admin dashboard JavaScript syntax check passes.
- [ ] Google OAuth tested with configured credentials on a real device.
- [ ] Database migration and backup verified before an engine switch.
- [ ] Changes remain on this branch until the owner requests merge.
