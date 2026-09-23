# Mobile v2 checklist

- Passenger Register exists and does not request national_id.
- Search uses correct RPC params.
- Seats lock uses p_bus_seat_ids.
- Confirm booking returns booking_id and ticket screen loads tickets by booking_id.
- Driver trips are filtered by current driver.
- Wallet shows transactions.
- Notifications screen exists.
- Profile editing + avatar upload works (needs `bolman_profile_avatar_and_password.sql`).
- Forgot password + change password work — see `docs/PROFILE_AND_PASSWORD_SETUP_AR.md`.
- Cubit state management.
- Purple/Mint UI and Light/Dark + Arabic/English.

Run `flutter analyze` after download because this environment cannot compile Flutter.
