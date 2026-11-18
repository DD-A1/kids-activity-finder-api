# README — Kids Activity Finder

Kids Activity Finder helps families discover children's activities, ongoing programs, and public events. Parents search by a child's age, interests, location, schedule, and cost when known.

Parents follow the provider's or organizer's own website or registration link. The app does not process bookings, tickets, or payments.

The product source of truth is Master Project Blueprint Version 2.0. The first market is metro Atlanta, with a statewide Georgia design. The approved database is 51 MVP tables. `market_demographics` is future analytics and is not part of the MVP. The earlier 45-table draft is historical.

## Who uses it

Parents and guardians create an account, manage private child profiles, discover activities and events, save favorites, write reviews, and report listings.

Providers are organizations or independent instructors. They apply, and after approval they manage a profile and submit activities for a separate review.

Moderators handle moderation. Admins manage operations and role assignments. `super_admin` is limited to platform owners. `admin` and `super_admin` are separate roles.

Children do not have accounts.

## What is built

The API is an ES-module Node.js app using Express, PostgreSQL (`pg`), bcryptjs, jsonwebtoken, dotenv, and cors. Run commands from the `server` directory.

```bash
npm install
npm start
```

The API listens on port 3000. Set `DATABASE_URL` and `JWT_SECRET` in `server/.env`. Do not commit `.env` or put secrets in this README.

Working and manually checked:

- `POST /api/auth/register` creates the user, one parent profile, and the parent role. New accounts are `active`. Email is trimmed and lowercased. Passwords are bcrypt hashes with a minimum of 8 characters.
- `POST /api/auth/login` returns a JWT. Email verification is not required to sign in. `email_verified_at` stays null until the user actually verifies.
- `GET /api/auth/me` requires a Bearer token.
- Child profiles: list, create, update, and delete. A child needs a first name or a nickname, a display name, and a date of birth. Profiles belong to the signed-in parent and stay private.
- Household profile: read and update an optional household children count. The count is separate from the child list and can be left blank.
- Parent routes check the parent role.

The React app is a separate repository. It covers register, login, child profiles, and the household count.

## Still planned

Search and filters, separate activity and event discovery, provider applications and approval, activity review, public-event collection and human review, favorites, reviews, reports, moderation, and provider image uploads.

Hosting, media storage, email, and deployment are not final until they are written into the technical plan.

## Rules that stay in force

- The five role codes are `parent`, `provider`, `moderator`, `admin`, and `super_admin`.
- Parent is assigned at registration. Provider is granted only after approval. Moderator and admin are assigned by authorized admins. Users may hold more than one role. Users cannot assign themselves a privileged role. Administrative role changes are audited.
- Provider approval does not approve every activity. Public events are reviewed before publication. Approval is not a guarantee of safety, quality, or suitability.
- Activity approval history lives in `activity_review_records`.
- An activity session requires an activity and one activity location. `schedule_id` may be null. A session has `session_date`, `start_time`, a nullable `end_time`, a nullable inclusive `end_date`, and a required IANA timezone.
- Session changes use `session_id`. A recurring public event uses `external_event_series_id`. A standalone event may have no series.
- Provider memberships keep `revoked_at`. Only one current membership exists for a provider and user.
- Admin task history uses `task_id`. The reminder field is `remind_at`.
- The MVP does not include identifiable photos of children, parent photo uploads, or general scraping of social networks. Public-event images are used only when reuse is allowed.

## Decisions

Keep this README aligned with Blueprint v2.0. Record an open decision instead of guessing. Changes to child privacy, provider verification, public-event collection, media permissions, legal terms, or MVP boundaries need an explicit product decision.
