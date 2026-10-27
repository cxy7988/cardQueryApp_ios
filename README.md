# CardQuery iOS

SwiftUI client for campus card, water and electricity balances. The client uses the authenticated task API of [cardQuery_linuxServer](https://github.com/cxy7988/cardQuery_linuxServer); the optional campus card query continues to use the campus provider directly.

## Updated server flow

1. Request an email code with `POST /api/send_code` (HTTP 202).
2. Verify it with `POST /api/verify_code`. Store the returned Bearer session in Keychain, with its expiry, server address and email. Returning users use the room returned by the server.
3. First-time users select a room and call `POST /api/verify_code_with_room` using that Bearer session. The consumed code is **not** sent a second time. An unfinished registration can resume after relaunch.
4. Submit `POST /api/tasks` with `{}` and an `Idempotency-Key`. The server returns HTTP 202 and a task ID. The empty body queries only the signed-in user's room.
5. Read task state and stream progress from `/api/tasks/<id>/events`, with `Authorization` and the last processed `Last-Event-ID`.
6. On completion, fetch `/api/query_history/<email>` to display balances. SSE events contain progress, **not balance results**. The main screen labels the most recent record's timestamp so an unsuccessful query does not make old balances look new.
7. Logout calls `/api/logout` to revoke the server session before clearing Keychain. If the server cannot be reached, the UI reports the failure and retains the session for retry. HTTP 401 and `auth_expired` events return the user to login.

Session tokens are never stored in UserDefaults or placed in URLs. Pending task IDs, event cursors and idempotency keys are stored before network operations and scoped by server + account. The idempotency key survives a lost submission response or app restart; reconnection does not submit a new query. A definitive queue failure permits a new submission with a new key.

The app closes its progress connection when inactive. On return it checks the original task and reconnects as needed. The server continues execution while iOS suspends the app; this client does not require background execution privileges to keep the server task alive. Transient failures use four automatic retries (1, 2, 4 and 8 seconds), followed by a manual continuation button. Expired server task records require a new query.

The SSE parser reads bytes directly: `URLSession.AsyncBytes.lines` skips empty lines, but SSE needs them to delimit events. Parsing handles UTF-8 split across chunks, LF/CRLF/CR, comment heartbeats and multiline data. Progress updates merge optional fields without erasing counters or regressing on replay.

## Build and configuration

- Open `QueryApp.xcodeproj` in Xcode 16.4 or newer; the deployment target remains iOS 18.5.
- `ServerAPI.live` in `QueryApp/ServerAPI.swift` retains the original `https://wkuquery.asia:5000` address. Change this constant if the new deployment uses another address. The new backend must be deployed at that address before using this client.
- Remote service access requires HTTPS. Configure the backend's SSE proxy as described in its README.
- For a device build, select your signing team. A compile without signing can be checked with:

```bash
xcodebuild -project QueryApp.xcodeproj -scheme QueryApp \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/cardquery-ios-build \
  CODE_SIGNING_ALLOWED=NO build
```

Water/electricity credentials and room bindings are managed by the server. Settings displays the bound room and allows editing only the optional local campus card ID and device parameter. Logging out and back in does not change an existing server room binding.

## History and upgrade behavior

- The server history tab shows the latest 30 daily water/electricity records; daily upserts can replace the same date's record.
- Local snapshots retain up to 50 records per server/account, including the optional campus card balance. Clearing/deleting local snapshots does not delete server history.
- The old `isLoggedIn` boolean is ignored; an existing install must verify its email once to receive a real session.
- Old local history and card configuration migrate only when their saved legacy email matches the authenticated account. Unattributed legacy data is left untouched and is not shown under another account.
- The original campus tutorials describe the older direct-query implementation; this README defines the current server integration.

## Privacy

Email, bound room information and water/electricity history are stored on the configured query server. Bearer credentials are stored in this device's Keychain (`WhenUnlockedThisDeviceOnly`). Local snapshots and optional card configuration remain on the device and are separated by account. Water/electricity requests go through the configured query server; the optional card request goes to `webapp.xiaofubao.com`.

This change does not add APNs registration or claim that real push delivery has been validated.

## Tests

The Swift package compiles the same network, session, task and history source files as the iOS app. It allows testing on macOS without a simulator or third-party Swift dependencies:

```bash
swift test --scratch-path /tmp/cardquery-client-tests
```

Tests cover one-time-code login, room binding, secure-store failure, session restoration/revocation, expired sessions, account isolation, lost submission responses, durable task recovery, idempotency, byte-level SSE parsing, replay cursors, history decoding and rate-limit errors. The optional backend integration case is skipped unless its isolated fixture is running. These tests exercise shared client logic; they do not replace device UI testing.

To test against the real Flask/Redis/Celery/SQLite services, use the backend's existing Python environment and an installed `redis-server`:

```bash
../cardQuery_linuxServer/.venv/bin/python scripts/test_backend_integration.py \
  --backend ../cardQuery_linuxServer --redis-server /path/to/redis-server
```

The script starts a private Redis process on a random loopback port and a temporary SQLite database, then runs all Swift tests. Campus HTTP calls, email and push are mocked; no real students are contacted and no real campus credentials are required. The integration test verifies login, single-use codes, Bearer room binding, idempotent task submission, SSE disconnection/replay, balance history and server-side logout revocation. Temporary services and data are cleaned up when the run exits.
