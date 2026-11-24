# TaskMate

TaskMate is a campus-based job-posting app that helps CMU students find and post side jobs.
It is a Flutter mobile app backed by Supabase (authentication and Postgres).

> Status: early development. Only the account and verification flow is implemented so far.
> The other screens are placeholders.

## Tech stack

| Area | Choice |
|---|---|
| App | Flutter (Dart SDK `^3.13.7`, see `pubspec.yaml`) |
| State management | `flutter_riverpod` |
| Navigation | `go_router` |
| Backend | Supabase (`supabase_flutter`): Auth and Postgres with Row Level Security |
| Media | `image_picker` (added for ID photos; not used by any screen yet) |

## What works now

- **Sign up** with full name, email, password and an account type (student or job poster).
  Students must use an `@cmu.edu.ph` email address; this is checked in the app and again by the database.
- **Email verification** with a one-time code sent to the address used to sign up.
- **Log in** with email and password, and sign out.
- **Profile record per user** in `public.profiles`, created automatically by a database trigger when an
  account is created, with a review status: `pending`, `verified`, `rejected` or `suspended`.
- **Status-based routing**: after login the user is sent to the screen for their status
  (pending, rejected, suspended, home, or admin for verified admins). Only verified users reach the home
  area, and only admins reach `/admin`.

Not built yet: the home, admin, pending, rejected and suspended screens (placeholders), job posting,
applying, ratings and comments, notifications, and the ID-photo upload.

## Project structure

```
lib/
├── main.dart, app.dart          app entry and root widget
├── core/
│   ├── config/env.dart          reads Supabase settings from build-time defines
│   ├── router/                  go_router setup and the redirect rules
│   ├── supabase/                Supabase initialisation
│   ├── validators.dart          form validation (name, email, password, @cmu.edu.ph rule)
│   └── widgets/                 shared widgets (placeholder screen)
└── features/
    └── auth/
        ├── models/              Profile
        ├── data/                AuthRepository, ProfileRepository (Supabase calls)
        ├── controllers/         Riverpod providers and the auth controller
        └── screens/             login, signup, verify
supabase/
└── migrations/                  SQL for the database (apply in order)
```

## Setup

### 1. Prerequisites

- Flutter SDK, with a device, emulator or Chrome available (`flutter doctor` should be clean)
- A Supabase project (the free tier is enough)

### 2. Install packages

```bash
flutter pub get
```

### 3. Create the database tables

In your Supabase project, run the files in `supabase/migrations/` **in order**, using the SQL editor
or the Supabase CLI:

1. `001_profiles.sql` creates the `profiles` table, its status and role checks, and a policy that lets a
   user read only their own profile.
2. `002_new_user_trigger.sql` creates the trigger that validates sign-ups and creates the profile row.

### 4. Add your Supabase settings (do not commit them)

Create `env.json` in the project root. This file is listed in `.gitignore`, so it is not committed:

```json
{
  "SUPABASE_URL": "https://YOUR-PROJECT.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR-ANON-KEY"
}
```

Both values are in the Supabase dashboard under Project Settings → API. The app reads them through
`String.fromEnvironment` in `lib/core/config/env.dart`.

### 5. Run

```bash
flutter run --dart-define-from-file=env.json
```

The `--dart-define-from-file` flag passes the values in `env.json` to the app at build time.
Without it, the Supabase URL and key are empty and sign-in will fail.

## Account and verification rules (as implemented)

- Account types chosen at sign-up: `student` or `poster`. The `admin` role is not self-service.
- New accounts start with status `pending` until reviewed.
- Students must register with an `@cmu.edu.ph` email.
- Users can read only their own profile (Row Level Security).
