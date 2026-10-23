# Al Qulaisi — Production deployment and security gate

This repository contains deployment configuration; it does **not** mean the service has already been deployed. A real production deployment still requires the owner's managed hosting account/domain and secret configuration.

## Required secrets and runtime configuration

Set these as secrets/environment variables in the hosting control plane. Never commit the values:

- `APP_ENV=production`
- `DATABASE_URL=postgresql+psycopg://USER:PASSWORD@HOST:5432/DBNAME?sslmode=require` (use the host provider's exact TLS connection string)
- `JWT_SECRET_KEY`: at least 48 characters from a cryptographically secure random generator. Do not reuse a GitHub Actions test secret or the example value.
- `GOOGLE_CLIENT_ID`: the Google **Web/server OAuth client ID** used as the audience for the Google ID token.
- `CORS_ALLOW_ORIGINS`: comma-separated exact HTTPS origins for the deployed admin dashboard/web app, with no wildcard.
- `ALLOWED_HOSTS`: comma-separated hostnames served by this API, not full URLs and no wildcard.
- `FORWARDED_ALLOW_IPS`: trusted ingress/proxy addresses provided by the host. Do not set `*` unless direct access to the app container is impossible and the provider explicitly recommends it.

Production startup fails closed when these core values are missing or unsafe. API docs are disabled in production. The ingress must terminate TLS, redirect HTTP to HTTPS, apply HSTS, and prevent direct public access to the container port. The app only trusts forwarded headers from configured proxy addresses.

## Nginx TLS and rate-limiting template

The repository includes `backend/deployment/nginx.conf.template`. Replace `api.example.com` with the real API hostname, install certificates, inspect the config with `nginx -t`, and reload Nginx only after that check passes. Start/publish the application so that port 8000 is reachable by Nginx through host loopback only (for Docker, map the port as `127.0.0.1:8000:8000`, not `0.0.0.0:8000:8000`). Set `FORWARDED_ALLOW_IPS=127.0.0.1` only when the local Nginx reverse proxy is the trusted immediate peer. If a managed hosting provider terminates TLS before the container, use that provider's exact trusted proxy configuration instead of copying the local-Nginx value.

The template caps request sizes and timeouts, applies HSTS and security headers, and imposes conservative per-IP limits on sign-in/registration/Google OAuth (5 requests/minute with a burst of 10) and checkout (10/minute with a burst of 5). These are starting limits, not a substitute for monitoring, distributed abuse detection, or a load test; adapt them to your provider and real traffic.

## Release process

1. Create a managed PostgreSQL database, enable TLS, and configure backups/point-in-time recovery.
2. Add the environment variables above through the hosting control plane.
3. Build the root `Dockerfile`; use the container's non-root `app` user.
4. Run the release/migration command **once per release**: `python -m backend.migrate`.
5. Start the web process using the Docker command, ensuring `FORWARDED_ALLOW_IPS` contains only trusted ingress addresses.
6. Provision an administrator with `python -m backend.create_admin --name "Platform Admin" --phone "+967..." --email "admin@example.com"`. The command prompts for the password without echoing it. Do not add a public admin-registration API.
7. Verify HTTPS, the health endpoint, allowed CORS origins, blocked arbitrary Host headers, login throttling at the ingress, logs, database restore, and the security CI workflow.
8. Test Google sign-in on a physical device with the release signing key before enabling public traffic.

## Google OAuth — exact trust relationship

Create the Android OAuth client with the **actual** Android application ID and release-signing SHA-1, and a Web application OAuth client for the server audience. Build Flutter with:

```bash
flutter run --dart-define=API_BASE_URL=https://YOUR_API_HOST/api --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID
```

Set the exact same Web client ID as the server `GOOGLE_CLIENT_ID`. The server validates Google signature, audience and expiry through `google-auth`, requires `email_verified=true`, and stores the stable Google `sub` with a unique index. The web client ID is not a secret; the ID token is an assertion and must never be trusted until the server validates it.

The repository currently contains three distinct Android applications: the customer Flutter app uses the template ID `com.example.alqulaisi_platform` in `android/app/build.gradle.kts`; the seller Flutter app uses `com.alqlaisi.seller`; and the independent Jetpack Compose prototype in `app/` uses `com.alqlaisi.platform`. The customer ID still contains the template namespace and must be finalized before the first production release. Do not create the customer OAuth client using the Compose prototype's ID. After the customer ID is formally selected, create its Android OAuth client with that exact ID and the relevant signing SHA-1; create a separate seller OAuth client for `com.alqlaisi.seller`. Do not change an ID after publishing the app. Both Gradle projects intentionally refuse release packaging without a private release keystore; they do not fall back to the public debug key.

Customer release signing environment variables: `ALQLAISI_ANDROID_KEYSTORE_PATH`, `ALQLAISI_ANDROID_KEYSTORE_PASSWORD`, `ALQLAISI_ANDROID_KEY_ALIAS`, `ALQLAISI_ANDROID_KEY_PASSWORD`. Seller release signing variables: `ALQLAISI_SELLER_KEYSTORE_PATH`, `ALQLAISI_SELLER_KEYSTORE_PASSWORD`, `ALQLAISI_SELLER_KEY_ALIAS`, `ALQLAISI_SELLER_KEY_PASSWORD`. Keep these values and keystore files out of source control.

The root and seller Android projects now include Gradle wrapper launchers and CI builds debug APKs. Debug build success checks native compilation only; it does not prove that Google OAuth credentials work or that a signed release is ready. Genuine Google sign-in still requires real OAuth clients and physical-device validation with the correct signing SHA-1.

## Operational safeguards and known boundaries

- Configure and test edge rate limits for `/auth/login`, `/auth/register`, `/auth/google`, `/checkout` and `/orders/checkout`; the included Nginx template provides a starting configuration. Configure monitoring/alerting and adapt limits to production traffic. Do not rely on in-process memory throttling for a multi-worker service.
- Store logs without passwords, Google ID tokens, bearer tokens, or full payment/delivery details. Restrict log access.
- Confirm the seller suspension workflow, order cancellation policy, internal delivery employee roster/verification, delivery assignment and completion procedures, proof-of-delivery policy, and retention policy before launch. The current internal dispatch workflow stores a staff name and phone entered by an admin; it does not yet provide a dedicated courier login, GPS tracking, or proof-of-delivery capture.
- The sales-insights endpoint returns database-backed rule-based analytics and explicitly indicates that no generative AI model is connected. Do not market this as model-generated AI until a provider is configured and tested. Forgot-password remains disabled until a verified recovery channel with expiry and rate limiting is implemented.
- Current checkout is cash on delivery; there are no online card charges or actual money transfers. Commission percentage remains a business decision, not a hardcoded value.
- Favourites are currently stored securely on the user's device, not synchronised to their account across devices. The order-status screen polls/refreshes the API; push notifications are not wired.
- Review existing store-owner links and duplicate legacy rows before migration. Migration fails rather than weakening unique ownership if legacy data conflicts.

No finite test suite can guarantee 100% security. Treat this checklist as a release gate and run a final penetration test plus real-device/browser acceptance tests before production.
