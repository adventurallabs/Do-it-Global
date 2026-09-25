# PalliCore

School operations app for admins and teachers. Built with Flutter, BLoC, go_router, and Supabase (with a local mock fallback when the remote project is not configured).

## Roles

- **Admin** — classes (LKG–12th with sections), directory, announcements, events, fee management, buses, timetables
- **Teacher** — dashboard, classroom tools, announcements

## Setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (SDK `^3.13.2`).
2. Clone the repo and install packages:

   ```bash
   flutter pub get
   ```

3. Copy environment values:

   ```bash
   cp .env.example .env
   ```

   Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` if you are using a real Supabase project. Placeholder values keep the app on local mock data.

4. Run:

   ```bash
   flutter run
   ```

Login currently uses the in-app Admin / Teacher mock switch.

## Project layout

| Path | Role |
| --- | --- |
| `lib/` | App shell, routing, admin/teacher home, DI |
| `packages/core_models` | Domain models |
| `packages/core_data` | Repositories and Supabase |
| `packages/core_ui` | Theme and shared widgets |
| `packages/feature_*` | Feature screens and BLoCs |

## Notes

- Do not commit `.env` or signing keys.
- Path packages under `packages/` are private to this app (`publish_to: none` is recommended before publishing anything to pub.dev).
