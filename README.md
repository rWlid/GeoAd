# GeoAd (learning version)

A tiny Flutter + Supabase app with three screens:

1. **Sign in**: type a phone number.
2. **Fake OTP**: type `1234`. No SMS is sent.
3. **Map**: shows a pin for every ad in the `ads` table.

## Files

| File | What it does |
|---|---|
| `lib/main.dart` | Starts Supabase, shows sign in or map based on auth state |
| `lib/sign_in_screen.dart` | Phone field, goes to the code screen |
| `lib/otp_screen.dart` | Checks `1234`, signs in (or signs up) with a hidden email/password |
| `lib/map_screen.dart` | Loads all ads with `from('ads').select()` and puts them on a Google Map |
| `supabase/migrations/20260930200000_ads.sql` | The `ads` table, its read policy, and 5 sample ads |

## Setup

1. In your Supabase project, run `supabase/migrations/20260930200000_ads.sql` in the SQL editor.
2. In Supabase **Authentication → Providers → Email**, turn **Confirm email** off (the fake OTP signs up with a made-up email).
3. Copy `env/dev.example.json` to `env/dev.json` and fill in your project URL and anon key.
4. Put your Google Maps key in `android/local.properties` as `MAPS_API_KEY=...`.
5. Run:

```sh
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```
