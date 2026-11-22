# API v1

The prefix is `/api/v1/`. JSON fields use camelCase. Authenticated requests carry `Authorization: Bearer <token>`. The OpenAPI schema is available at `schema/`, with an interactive viewer at `docs/`. Lists use `count`, `next`, `previous` and `results`. URLs in deck responses are relative to the backend origin.

Write endpoints marked **key** require `Idempotency-Key` with 1–128 ASCII letters, digits or `_.:-`. Generate a new key for each distinct operation and retain it across network retries. Completed operations replay their original response. A changed payload with the same key returns `409 idempotency_conflict`. For an active Oracle or Vision operation the server may return `409` while it runs. Checkout can return its order with `202 pending`. Fetch that order to see the current status. An Oracle generation that fails has a stored error. After a reported failure, a deliberate new attempt uses a new key.

```json
{
  "code": "reading_incomplete",
  "detail": "Reveal or confirm every base position first.",
  "requestId": "fbd4c698-db47-41a8-bbeb-2d12ec4a4302"
}
```

Validation can include a `fields` object. Use `code` for client behavior and keep `X-Request-ID` for technical troubleshooting. Typical HTTP statuses are 400 for validation, 401 for missing or invalid authentication, 403 for unavailable capabilities or ownership checks, 404 for inaccessible private resources, 409 for conflicts, 413 for large uploads, 429 for quota, 502 for invalid AI output, 503 for unavailable integrations and 504 for upstream timeouts.

## Accounts and system

| Method and path | Contract |
| --- | --- |
| GET `health/` | Database readiness |
| GET `config/public/` | Systems, guest support and availability of email verification |
| POST `auth/guest/` | A server-issued guest identity and bearer token |
| POST `auth/email/start/` | Request a single-use proof with `{"email":"reader@example.org"}` |
| POST `auth/email/verify/` | Submit `{"token":"<one-time code>"}` to obtain a verified identity and bearer token |
| POST `auth/logout/` | Revoke the bearer token |
| GET `account/me/` | Current ID and verified flag |

Token responses include `id`, `verified`, `token`, and `expiresAt`. A guest token is valid for seven days and an account token for 30 days unless revoked. Store the bearer token in the device's secure credential storage. Email verification creates or restores the verified account. Guest history and grants remain tied to the guest identity in v1. Recovering a library on another device means signing into the same verified account.

## Oracle

| Method and path | Contract |
| --- | --- |
| GET `oracle/personalities/` | Bearer-authenticated list of enabled interpreters with `id`, `name` and `description` |
| GET, POST `oracle/sessions/` | List owned sessions or create a session **key** |
| GET, PATCH, DELETE `oracle/sessions/{id}/` | Restore, update pre-reading context or delete an owned session |
| POST `oracle/sessions/{id}/cards/` | Submit one revealed digital card **key** |
| POST `oracle/sessions/{id}/synthesize/` | Start the first synthesis **key** |
| POST `oracle/sessions/{id}/messages/` | Continue with `{"text":"…"}` **key** |
| POST `oracle/sessions/{id}/clarifiers/{position}/` | Interpret a placed clarifier with `{"text":"…"}` **key** |

Create a reading before the initial generation or first physical recognition. For example:

```json
{
  "schemaVersion": 1,
  "clientSessionId": "2026-11-21T15:00:00.000",
  "system": "tarot",
  "source": "digital",
  "mode": "standard",
  "spreadId": "custom",
  "subject": "other",
  "otherContext": "A friend considering a move",
  "question": "What should they consider?",
  "notes": ["Focus on the next month"],
  "positions": [{"position": 0, "role": "What could help?", "note": "Practical resources"}]
}
```

Flutter uses the same `TAROT_BACKEND_URL` build definition as the deck catalogue. Use an HTTPS origin for a deployed backend. The selected catalogue ID goes in the create request as `personality` and is fixed for the life of that server session.

The response includes the server-issued `sessionId`. Use it in API paths. The preceding request can be exercised as follows after issuing a guest token:

```sh
curl -sS -X POST http://127.0.0.1:8000/api/v1/auth/guest/
# Save the returned token as TAROT_TOKEN and the create response sessionId as TAROT_SESSION.
curl -sS -X POST http://127.0.0.1:8000/api/v1/oracle/sessions/ \
  -H "Authorization: Bearer $TAROT_TOKEN" -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: reading-1' \
  -d '{"system":"tarot","spreadId":"one","positions":[{"position":0,"role":"Daily anchor"}]}'
curl -sS -X POST "http://127.0.0.1:8000/api/v1/oracle/sessions/$TAROT_SESSION/cards/" \
  -H "Authorization: Bearer $TAROT_TOKEN" -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: card-1' \
  -d '{"position":0,"cardId":"tarot:13","orientation":"upright"}'
curl -sS -X POST "http://127.0.0.1:8000/api/v1/oracle/sessions/$TAROT_SESSION/synthesize/" \
  -H "Authorization: Bearer $TAROT_TOKEN" -H 'Idempotency-Key: synthesis-1'
```

On success, synthesis returns `narrative`, `elementalAlchemy`, `verdict` and `followUp`. Conversation turns return `text`, `action` and an optional zero-based `position`. Live Oracle actions such as `requestClarifier` are suggestions. The server persists user and oracle messages in order, with an optional `slotIndex`. For additional cards, set `clarifier:true` when placing the card. After the base positions are filled, up to 15 total cards can be registered, including before the initial synthesis. A separate clarification question can be submitted to the clarifier path after the initial synthesis. The position's `note` and `clarifierQuestion` are separate. Late pre-reading question, notes or subject changes can be made with PATCH until synthesis or conversation begins. A subject change clears the previous subject's context unless the matching new context is supplied.

For an Astral session, supply `kind` as `natalChartReading`, `synastryReading`, `horoscopeReading` or `zodiacReading` and `astralContext` as `{"schemaVersion":1,"summary":"…"}`. A future client constructs the minimized summary from `OracleHandoff` and keeps the richer calculation and profile data on device. This API stores the supplied summary for continuity. All readings use the same ownership checks.

A future SSE API may emit `started`, `delta`, then `completed` or `error` with a stable request and session ID. Persist exactly one final result at completion. Current V1 calls return complete JSON responses.

## Vision

| Method and path | Contract |
| --- | --- |
| POST `vision/recognize/` | One extracted image **key** |
| POST `vision/recognize-batch/` | Up to 12 extracted images **key** |
| GET `vision/results/{requestId}/` | Retrieve one's own recognition result |
| POST `vision/confirm/` | Confirm, reject, correct or manually choose a card **key** |

Use multipart with `sessionId`, optional `deckId`, an `items` field containing a JSON array and one repeated `images` field per array item. For a single image the array has one entry, for example `[{"itemId":"crop-1","trackId":"track-1","rotationDegrees":90}]`. Coordinates and live tracking remain client-side. Supported image types are JPEG, PNG and WebP. Each input is limited to 4 MiB and 4096 pixels per side, batched uploads to 20 MiB. Explicit rotation is clockwise and takes precedence over EXIF. With zero rotation the server uses EXIF when present. Metadata is removed when normalizing.

A result reports its request ID, session ID, item ID, optional track ID, candidates, provider, recognition status, decision and `requiresConfirmation`. An optional score has a `type` of `similarity` or `confidence` and its numeric `value`. Confidence must be calibrated before an adapter uses that type. A valid upload can return `200` with unavailable results and a top-level integration error. An unavailable or unknown crop can be handled manually, or corrected with its request ID to preserve tracking identity. Recognition intermediates expire after seven days when pruning is enabled.

```json
{
  "sessionId": "b87fadbd-4167-4715-b4bd-ee28194bf933",
  "requestId": "5bc6e206-d994-430f-8648-1460eb582dd0",
  "action": "correct",
  "position": 0,
  "cardId": "tarot:13",
  "orientation": "reversed"
}
```

`confirm` accepts a recognized candidate and requires explicit orientation when it was unknown. `reject` uses only the session and request IDs. `manual` requires card and orientation and omits the recognition request ID. Reusing the same confirmation key replays the result. Once a position is confirmed, another request cannot replace its identity. A track confirmed in the same reading cannot be inserted into another position.

## Deck Store

| Method and path | Contract |
| --- | --- |
| GET `store/decks/?system=tarot&pricing=free` | Public published catalog with optional filters (includes `promoImageUrl`) |
| GET `store/decks/{slug}/` | Metadata, versions, `promoImageUrl` and preview links |
| GET `store/promos/?system=tarot` | Public backend-managed promo artwork for built-in decks, rune sets and published shop decks |
| GET `store/promos/{system}/{packId}/image/` | Public promo banner image (`JPG`/`PNG`/`WebP`, cached with ETag) |
| GET `store/previews/{assetId}/` | Public cover or preview image |
| GET `store/library/` | Account or guest library |
| GET `store/decks/{deckId}/ownership/` | `{"owned":true}` or false |
| POST `store/decks/{deckId}/acquire-free/` | Acquire a free product **key** |
| GET `store/decks/{deckId}/download/?appVersion=1.2.0` | Resolve the highest compatible authorized version. Optional `version=1.0.0` selects an exact version. |
| GET `store/decks/{deckId}/packages/{version}/` | ZIP response, bearer and ownership required |

After acquisition, Flutter calls the download endpoint with its numeric version, stores the ZIP in private app storage and checks the returned `sizeBytes` and `sha256`. Verify entries and their checksums against the manifest before extracting to an isolated version directory. Activate only after completing validation, and let `DeckPackController` continue to own the active selection for each system. When a deliberately incomplete set lacks art, use the existing procedural or bundled fallback by canonical ID. A refund revokes server downloads where no other grant exists. A previously downloaded file can only be reevaluated after the client comes online.

### Deck package and publishing

Create the draft product in Admin to get its UUID. Prepare a ZIP with the following manifest at its root. Replace the sample checksum tokens with lowercase hexadecimal SHA-256 values. Supported images use `.jpg`, `.png` or `.webp`, with a mandatory WebP cover. `back` is optional. Previews are optional and explicit.

```json
{
  "schemaVersion": 1,
  "deckId": "e5bc21f0-9b83-4410-8caf-49f988f4fc7d",
  "system": "lenormand",
  "version": "1.0.0",
  "minAppVersion": "0.0.0",
  "incomplete": true,
  "cover": {"path":"cover.webp","sha256":"<cover-checksum>"},
  "previews": [],
  "cards": {"lenormand:0":{"path":"cards/rider.webp","sha256":"<card-checksum>"}}
}
```

In Admin, create `Deck version` for the draft, set its version, minimum app version and completeness to match, upload the ZIP and mark the version published. Verify rights and mark the deck published. A complete set includes all canonical IDs for its system, with 78 Tarot, 36 Lenormand or 24 Rune entries. A published version is immutable through Admin. Publish a new version for an update. A product can be delisted while existing owners retain access when distribution is still authorized.

## Payments

| Method and path | Contract |
| --- | --- |
| POST `payments/checkout/` | Create an order for a verified account with `{"deckId":"…","provider":"…"}` **key** |
| GET `payments/orders/{id}/` | Poll the order as its owner |
| POST `payments/webhooks/{provider}/` | Receive a signed and verified payment state from the provider |

Price and currency come from the server product and are fixed on the order. The development adapter is disabled by default and unavailable in production. For a local simulation set `PAYMENTS_ENABLE_DEV=true` and a random `PAYMENTS_DEV_WEBHOOK_SECRET` of at least 32 characters. Use the verified identity flow and checkout with provider `dev`. It returns a reference with prefix `dev-` and a null `checkoutUrl`. Use the order snapshot to simulate a signed `paid` or `refunded` event. Headers are `X-Tarot-Webhook-Timestamp` (Unix seconds, five-minute tolerance) and `X-Tarot-Webhook-Signature` (lowercase hex HMAC-SHA256 of timestamp, a period, and the exact raw body). Body fields are `eventId`, `orderId`, `reference`, `status`, `priceMinor` and `currency`. Only verified server events create or revoke a purchase grant.

To sign a development event using Python, set `TAROT_ORDER_ID`, `TAROT_PRICE_MINOR` and `TAROT_CURRENCY` from the order response. Run this against the local development server with the same webhook secret in the environment.

```python
import hashlib
import hmac
import json
import os
import time
import uuid
from urllib.request import Request, urlopen

order = os.environ["TAROT_ORDER_ID"]
event = {
    "eventId": str(uuid.uuid4()), "orderId": order, "reference": f"dev-{order}",
    "status": "paid", "priceMinor": int(os.environ["TAROT_PRICE_MINOR"]),
    "currency": os.environ["TAROT_CURRENCY"],
}
body = json.dumps(event).encode()
timestamp = str(int(time.time()))
signature = hmac.new(
    os.environ["PAYMENTS_DEV_WEBHOOK_SECRET"].encode(),
    timestamp.encode() + b"." + body, hashlib.sha256,
).hexdigest()
request = Request(
    "http://127.0.0.1:8000/api/v1/payments/webhooks/dev/",
    data=body,
    headers={"Content-Type": "application/json", "X-Tarot-Webhook-Timestamp": timestamp,
             "X-Tarot-Webhook-Signature": signature},
)
with urlopen(request) as response:
    print(response.read().decode())
```
