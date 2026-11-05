# Garmin Connect sync

The Profile tab connects to Garmin Connect. Once connected, new body-composition
readings upload automatically, and the Profile tab's Sync button sends any that
are still waiting. This is the mobile equivalent of WebBodyComposition's "Send
to Garmin Connect" form, implemented directly in Dart without a third-party
proxy.

## Automatic upload

When a Garmin account is connected, each new reading uploads as soon as it is
saved:

- **Scale readings** get a fourth step in the measuring card: Looking,
  Connecting, Reading, Syncing. Without a connected account the card keeps its
  three steps and nothing is uploaded.
- **Manually added weights** upload in the background with no step card. A notice
  reports the result.

Only the new reading is sent. Older unsent readings wait for Sync on the Profile
tab, so connecting an account never uploads a history unprompted.

The reading is saved before the upload starts, so a failed upload never loses it.
You can also start another measurement during the Syncing step. Garmin work runs
one task at a time, so a second reading waits for the first upload, and a
disconnect waits for any upload already in flight.

If an upload fails, the notice says the reading was saved but not sent, and
offers **Try again**. If the Garmin session has expired it offers **Reconnect**
instead, which sends the reading after you sign in. Failed uploads are not
retried on their own; they stay pending until you tap Try again or Sync.

Uploads only run while the app is open. If the system suspends the app during an
upload, it can report a failure when you return. Trying again is safe because
duplicates are treated as success.

A reading that uploads before a measurement profile exists stays weight-only in
Garmin, because it is marked as sent and adding a profile later does not resend
it.

## What is uploaded

Each reading becomes a FIT `weight` file containing:

| Message        | Values                                                                 |
| -------------- | ---------------------------------------------------------------------- |
| `file_id`      | weight file, Garmin manufacturer, Index scale product, serial, created |
| `user_profile` | sex, age, height, weight, activity class (when a profile exists)       |
| `weight_scale` | timestamp, weight, body fat, hydration, bone mass, muscle mass,        |
|                | visceral fat rating, physique rating, metabolic age, user index, BMI   |

Body composition is estimated from impedance and the measurement profile with
the same formulas as the upstream project. If no profile exists, the file
contains weight and BMI only. Raw impedance is not sent because Garmin's FIT
weight message has no field for it.

The BMI field is FIT profile field 13 (`weight_scale`), added in recent FIT SDK
releases. `python-fitparse`'s older bundled profile may display it as
`unknown_13`; the FIT SDK 21.115 profile names it `bmi`.

## Sign-in and tokens

1. Load Garmin's mobile sign-in page, keeping its cookies.
2. POST credentials to `sso.garmin.com/mobile/api/login`.
3. If Garmin asks for MFA, POST the code to
   `sso.garmin.com/mobile/api/mfa/verifyCode`.
4. Exchange the service ticket for a DI OAuth2 bearer token at
   `diauth.garmin.com`.
5. Upload to `connectapi.garmin.com/upload-service/upload/.fit` with the bearer
   token.

Only the OAuth access/refresh tokens and the account email are persisted, using
`flutter_secure_storage` (Android Keystore, iOS Keychain). The Garmin password is
held in memory for the sign-in request and is not written to disk.

Access tokens are refreshed automatically. If the refresh token is rejected,
the UI asks you to reconnect.

## Duplicate handling

The app stores the timestamps of successfully uploaded readings per Garmin
account. Automatic uploads and Sync only build FIT files for readings that are
not in that set. Garmin's duplicate response (import message code 202) is also
treated as success. Failed readings stay unsynced until you tap Try again or
Sync.

## Troubleshooting

| Message                             | Meaning / action                                                        |
| ----------------------------------- | ----------------------------------------------------------------------- |
| "Garmin didn't accept that email or password." | Check the credentials. Garmin may also lock accounts after repeated failures. |
| "Garmin wants a browser verification…" | Garmin's bot protection requires a CAPTCHA; wait and try again later. |
| "Garmin is limiting requests…"      | HTTP 429. Wait several minutes before retrying.                         |
| "Garmin blocked the request."       | HTTP 403 from Cloudflare/Garmin. Wait, then retry; a VPN or different network may help. |
| "Garmin session expired. Reconnect…" | The refresh token was rejected. Tap Reconnect and sign in again.       |
| "Garmin rejected a reading."        | The FIT import returned an error message; the message is displayed.     |

Garmin's anti-bot rules can change without notice. The app deliberately uses
Garmin's mobile sign-in path (rather than the older embed-widget form) because
it is the flow used by current community clients and supports MFA. A short
random delay before submitting credentials mirrors the mobile app and reduces
automated-traffic flags.

## Testing

Unit tests cover FIT encoding (including header/file CRCs and scaled values),
the mobile sign-in and MFA flow with a mocked HTTP client, token refresh,
multipart upload parsing, duplicate handling, per-account sync tracking and the
body-composition formulas. `test/main_test.dart` drives the automatic upload
through the real dashboard with the scale and Garmin network faked. A live
sign-in requires a real Garmin account and a physical device/emulator with
network access.

Generate a FIT file for inspection with:

```dart
final bytes = encodeGarminWeightFit(reading);
File('reading.fit').writeAsBytesSync(bytes);
```

Then import it at <https://connect.garmin.com/modern/import-data> or parse it with
the FIT SDK or `python-fitparse`.
