# Al Qulaisi Platform

A multi-vendor commerce platform with three separate user interfaces:

- **Customer app:** Flutter at the repository root.
- **Seller app:** standalone Flutter project in `seller_app/`.
- **Admin dashboard:** Arabic web UI in `admin_dashboard/`.
- **Central API:** FastAPI in `backend/`; SQLite for local development and TLS-enabled PostgreSQL for production.
- **Google sign-in:** Flutter sends an ID token to the API, which verifies signature, audience, expiry, and verified email before creating a platform session.

## Local development

Requirements: Python 3.12+, Flutter stable, Android SDK, and Java supported by the checked-in Android Gradle Plugin.

1. Create a virtual environment and install the backend packages:

   ```powershell
   py -3.12 -m venv .venv
   .venv\Scripts\Activate.ps1
   python -m pip install -r backend/requirements.txt
   Copy-Item .env.example .env
   ```

   Keep `DATABASE_URL` empty for local SQLite. Use a unique local JWT secret. Never copy local values into production secrets.

2. Start the API from the repository root:

   ```powershell
   python -m uvicorn backend.app.main:app --reload --host 127.0.0.1 --port 8000
   ```

   Development docs: `http://127.0.0.1:8000/docs`. API documentation is disabled in production.

3. Run the customer Android app:

   ```powershell
   flutter pub get
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
   ```

   `10.0.2.2` is the Android emulator address for the host computer. For Windows desktop, use `API_BASE_URL=http://127.0.0.1:8000/api`.

4. Run the separate seller app:

   ```powershell
   cd seller_app
   flutter pub get
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
   ```

5. Serve the admin dashboard from the repository root:

   ```powershell
   python -m http.server 5500
   ```

   Open `http://localhost:5500/admin_dashboard/` and sign in with an administrator provisioned by the backend's admin-creation command. The public dashboard does not create administrator accounts.

## Google OAuth

The Android application IDs are `com.alqlaisi.platform` (customer) and `com.alqlaisi.seller` (seller). Create the Android OAuth clients using the exact application IDs and signing SHA-1 values.

Create a Google Web OAuth client for the server audience. Use that same Web client ID in both places:

- Flutter build-time setting: `--dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID`
- Backend runtime setting: `GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID`

Do not use a placeholder ID. Register the debug SHA-1 for local testing and the release certificate SHA-1 for the release app. Real Google sign-in is not certified until the actual OAuth clients are configured and sign-in is tested on a physical device.

## Production and security

Read `backend/deployment/PRODUCTION_CHECKLIST.md`. The server fails closed in production unless TLS-enabled PostgreSQL, a strong JWT secret, Google server client ID, exact HTTPS CORS origins, explicit allowed hosts, and migrated database tables are configured. The Docker image runs as a non-root user; Nginx configuration is a template until a real domain and certificates are installed.

Android release builds now refuse to use the debug signing key. Customer and seller signing keystores/passwords must be provided through private environment variables and must never be committed.

No production hosting account/domain has been provisioned by this repository update; the checklist describes deployment requirements rather than claiming deployment is already live.

## Version-1 scope and boundaries

Cash on delivery, per-store orders, server-calculated product prices and delivery fees, admin publication approval, manual availability without inventory counts, and internal/manual order-status workflow. Real push notifications, online payments/transfers, configured commission settlement, secure password recovery, and AI sales analytics remain incomplete until their actual integrations are configured and tested.

See `backend/ISSUE_REGISTER.md` for remaining release gates.
