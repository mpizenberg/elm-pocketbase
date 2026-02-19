# elm-pocketbase: PocketBase Client for Elm via elm-concurrent-task

## Purpose

An Elm package wrapping the [PocketBase JS SDK](https://github.com/pocketbase/js-sdk) as composable `ConcurrentTask` values. Covers authentication, CRUD on collections, real-time SSE subscriptions, and custom endpoints -- everything needed by the partage application, designed to be reusable for any PocketBase-backed Elm app.

## Scope

**In scope (elm-concurrent-task based):**
- Client initialization and health check
- Collection CRUD: `getOne`, `getList`, `create`
- Auth: `authWithPassword`, `authRefresh`, `authStore` state queries, `logout`
- Password derivation helper (SHA-256 of key bytes -> base64url)
- Custom endpoint calls (raw fetch for non-SDK routes like `/api/pow/challenge`)
- Binary data encoding/decoding (Base64 <-> Uint8Array for Loro update blobs)

**In scope (port-based subscriptions):**
- Real-time SSE subscriptions (`subscribe` / `unsubscribe` on collections)
- Auth store change notifications

**Out of scope:**
- Server-side hooks (PocketBase's Goja runtime) -- those stay in JS/Go
- Admin API (collection schema management) -- setup scripts only
- File uploads -- not used by partage

---

## Elm API Design

### Module: `PocketBase`

```elm
module PocketBase exposing
    ( Client, init
    , healthCheck
    , Error(..)
    )
```

#### Types

```elm
{-| Opaque handle to a PocketBase client instance.
Created by `init`, threaded through all operations.
-}
type Client
    = Client String  -- wraps the client ID assigned by JS


{-| Errors that PocketBase operations can produce. -}
type Error
    = NotFound
    | Unauthorized
    | Forbidden
    | BadRequest String
    | Conflict
    | TooManyRequests
    | ServerError String
    | NetworkError String
```

#### Functions

```elm
{-| Initialize a PocketBase client pointing at the given base URL.
The JS companion creates the `new PocketBase(url)` instance and returns an ID.
-}
init : String -> ConcurrentTask Error Client


{-| Health check. Returns True if the server is reachable. -}
healthCheck : Client -> ConcurrentTask Never Bool
```

### Module: `PocketBase.Auth`

```elm
module PocketBase.Auth exposing
    ( AuthRecord
    , authWithPassword
    , refreshAuth
    , isAuthenticated
    , getAuthRecord
    , logout
    , derivePasswordFromKey
    )
```

#### Types

```elm
type alias AuthRecord =
    { id : String
    , username : String
    , groupId : String
    }
```

#### Functions

```elm
{-| Authenticate with username + password.
PocketBase stores the JWT token internally in the JS SDK's authStore.
-}
authWithPassword :
    Client
    -> { collection : String, identity : String, password : String }
    -> ConcurrentTask Error AuthRecord


{-| Refresh the current auth token. Fails if not currently authenticated. -}
refreshAuth : Client -> ConcurrentTask Error AuthRecord


{-| Check if the client has a valid auth token. Synchronous JS check. -}
isAuthenticated : Client -> ConcurrentTask Never Bool


{-| Get the current auth record, if authenticated. -}
getAuthRecord : Client -> ConcurrentTask Never (Maybe AuthRecord)


{-| Clear the auth store. -}
logout : Client -> ConcurrentTask Never ()


{-| Derive a deterministic password from a Base64 key string.
Computes: base64url(SHA-256(base64decode(keyString)))
This is the auth mechanism used by partage: the group's symmetric key
is hashed to produce a per-group password.
-}
derivePasswordFromKey : String -> ConcurrentTask Never String
```

### Module: `PocketBase.Collection`

```elm
module PocketBase.Collection exposing
    ( getOne
    , getList
    , create
    , ListResult
    )
```

#### Types

```elm
type alias ListResult a =
    { page : Int
    , perPage : Int
    , totalItems : Int
    , totalPages : Int
    , items : List a
    }
```

#### Functions

```elm
{-| Fetch a single record by ID.

    PocketBase.Collection.getOne client
        { collection = "groups"
        , id = groupId
        , decoder = groupDecoder
        }

-}
getOne :
    Client
    -> { collection : String, id : String, decoder : Decode.Decoder a }
    -> ConcurrentTask Error a


{-| Fetch a paginated list of records with optional filter and sort.

    PocketBase.Collection.getList client
        { collection = "loro_updates"
        , page = 1
        , perPage = 1000
        , filter = Just ("groupId=\"" ++ groupId ++ "\" && timestamp > " ++ String.fromInt since)
        , sort = Just "+timestamp"
        , decoder = loroUpdateDecoder
        }

-}
getList :
    Client
    ->  { collection : String
        , page : Int
        , perPage : Int
        , filter : Maybe String
        , sort : Maybe String
        , decoder : Decode.Decoder a
        }
    -> ConcurrentTask Error (ListResult a)


{-| Create a new record.

    PocketBase.Collection.create client
        { collection = "loro_updates"
        , body = encodeLoroUpdate update
        , decoder = loroUpdateDecoder
        }

-}
create :
    Client
    -> { collection : String, body : Encode.Value, decoder : Decode.Decoder a }
    -> ConcurrentTask Error a
```

### Module: `PocketBase.Custom`

For endpoints not covered by the SDK (e.g. the PoW challenge route).

```elm
module PocketBase.Custom exposing (fetch)


{-| Make a raw HTTP request to a custom PocketBase endpoint.
The URL is resolved relative to the client's base URL.

    PocketBase.Custom.fetch client
        { method = "GET"
        , path = "/api/pow/challenge"
        , body = Nothing
        , decoder = powChallengeDecoder
        }

-}
fetch :
    Client
    -> { method : String, path : String, body : Maybe Encode.Value, decoder : Decode.Decoder a }
    -> ConcurrentTask Error a
```

### Module: `PocketBase.Realtime`

Real-time subscriptions use **ports** (not tasks) because they are long-lived event streams.

```elm
module PocketBase.Realtime exposing
    ( subscribe, unsubscribe, unsubscribeAll
    , SubscriptionEvent(..)
    , decodeEvent
    )
```

#### Types

```elm
type SubscriptionEvent
    = Created Decode.Value
    | Updated Decode.Value
    | Deleted Decode.Value
```

#### Port Commands (Elm -> JS)

```elm
{-| Subscribe to all changes on a collection.
The JS companion calls `pb.collection(name).subscribe('*', callback)`.
Events arrive through the `onPocketbaseEvent` subscription port.
-}
subscribe : Client -> String -> ConcurrentTask Never ()


{-| Unsubscribe from a collection. -}
unsubscribe : Client -> String -> ConcurrentTask Never ()


{-| Unsubscribe from all collections. -}
unsubscribeAll : Client -> ConcurrentTask Never ()
```

#### Port Subscription (JS -> Elm)

The app wires a port for incoming events:

```elm
port onPocketbaseEvent : (Decode.Value -> msg) -> Sub msg


{-| Decode an incoming real-time event. -}
decodeEvent : Decode.Decoder ( String, SubscriptionEvent )
decodeEvent =
    Decode.map2 Tuple.pair
        (Decode.field "collection" Decode.string)
        (Decode.field "action" Decode.string
            |> Decode.andThen
                (\action ->
                    let
                        record = Decode.field "record" Decode.value
                    in
                    case action of
                        "create" -> Decode.map Created record
                        "update" -> Decode.map Updated record
                        "delete" -> Decode.map Deleted record
                        _ -> Decode.fail ("Unknown action: " ++ action)
                )
        )
```

### Module: `PocketBase.Encode`

Binary encoding utilities used by partage for Loro update blobs.

```elm
module PocketBase.Encode exposing
    ( bytesToBase64
    , base64ToBytes
    )


{-| Encode raw bytes to Base64 string (chunked to avoid stack overflow).
Used for Loro CRDT update blobs before pushing to PocketBase.
-}
bytesToBase64 : Bytes -> ConcurrentTask Never String


{-| Decode a Base64 string to raw bytes.
Used when fetching Loro CRDT updates from PocketBase.
-}
base64ToBytes : String -> ConcurrentTask Never Bytes
```

---

## JS Companion Design

### Factory Function

```javascript
// js/src/index.js
import PocketBase from "pocketbase";

export function createTasks() {
  const clients = new Map(); // clientId -> PocketBase instance
  let nextId = 0;

  return {
    "pocketbase:init": ({ url }) => {
      const id = String(nextId++);
      const pb = new PocketBase(url);
      pb.autoCancellation(false);
      clients.set(id, pb);
      return id;
    },

    "pocketbase:healthCheck": ({ clientId }) => {
      const pb = getClient(clients, clientId);
      return pb.health.check().then(() => true).catch(() => false);
    },

    "pocketbase:authWithPassword": async ({ clientId, collection, identity, password }) => {
      const pb = getClient(clients, clientId);
      try {
        const result = await pb.collection(collection).authWithPassword(identity, password);
        return {
          id: result.record.id,
          username: result.record.username,
          groupId: result.record.groupId,
        };
      } catch (e) {
        return normalizeError(e);
      }
    },

    "pocketbase:refreshAuth": async ({ clientId }) => {
      const pb = getClient(clients, clientId);
      try {
        const result = await pb.collection("users").authRefresh();
        return {
          id: result.record.id,
          username: result.record.username,
          groupId: result.record.groupId,
        };
      } catch (e) {
        pb.authStore.clear();
        return normalizeError(e);
      }
    },

    "pocketbase:isAuthenticated": ({ clientId }) => {
      const pb = getClient(clients, clientId);
      return pb.authStore.isValid;
    },

    "pocketbase:getAuthRecord": ({ clientId }) => {
      const pb = getClient(clients, clientId);
      if (!pb.authStore.isValid || !pb.authStore.record) return null;
      return {
        id: pb.authStore.record.id,
        username: pb.authStore.record.username,
        groupId: pb.authStore.record.groupId,
      };
    },

    "pocketbase:logout": ({ clientId }) => {
      getClient(clients, clientId).authStore.clear();
    },

    "pocketbase:getOne": async ({ clientId, collection, id }) => {
      const pb = getClient(clients, clientId);
      try {
        return await pb.collection(collection).getOne(id);
      } catch (e) {
        return normalizeError(e);
      }
    },

    "pocketbase:getList": async ({ clientId, collection, page, perPage, filter, sort }) => {
      const pb = getClient(clients, clientId);
      try {
        const opts = {};
        if (filter) opts.filter = filter;
        if (sort) opts.sort = sort;
        return await pb.collection(collection).getList(page, perPage, opts);
      } catch (e) {
        return normalizeError(e);
      }
    },

    "pocketbase:create": async ({ clientId, collection, body }) => {
      const pb = getClient(clients, clientId);
      try {
        return await pb.collection(collection).create(body);
      } catch (e) {
        return normalizeError(e);
      }
    },

    "pocketbase:customFetch": async ({ clientId, method, path, body }) => {
      const pb = getClient(clients, clientId);
      const url = pb.baseUrl + path;
      try {
        const opts = { method, headers: { "Content-Type": "application/json" } };
        if (body) opts.body = JSON.stringify(body);
        const response = await fetch(url, opts);
        if (!response.ok) {
          const text = await response.text();
          return { error: statusToCode(response.status) + ":" + text };
        }
        return await response.json();
      } catch (e) {
        return { error: "NETWORK_ERROR:" + e.message };
      }
    },

    "pocketbase:subscribe": async ({ clientId, collection }, { ports }) => {
      const pb = getClient(clients, clientId);
      await pb.collection(collection).subscribe("*", (e) => {
        // Send through the port defined at registration time
        // The caller must set up the onPocketbaseEvent port externally
        if (globalEventCallback) {
          globalEventCallback({
            collection,
            action: e.action,
            record: e.record,
          });
        }
      });
    },

    "pocketbase:unsubscribe": async ({ clientId, collection }) => {
      const pb = getClient(clients, clientId);
      await pb.collection(collection).unsubscribe("*");
    },

    "pocketbase:unsubscribeAll": async ({ clientId }) => {
      const pb = getClient(clients, clientId);
      await pb.collection("*").unsubscribe("*");
    },

    "pocketbase:derivePassword": async ({ keyBase64 }) => {
      const keyBytes = Uint8Array.from(atob(keyBase64), (c) => c.charCodeAt(0));
      const hashBuffer = await crypto.subtle.digest("SHA-256", keyBytes);
      const hashArray = new Uint8Array(hashBuffer);
      const base64 = btoa(String.fromCharCode(...hashArray));
      return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
    },

    "pocketbase:bytesToBase64": ({ bytes }) => {
      // bytes comes as an array of numbers from Elm
      const arr = new Uint8Array(bytes);
      let binary = "";
      const chunkSize = 8192;
      for (let i = 0; i < arr.length; i += chunkSize) {
        binary += String.fromCharCode(...arr.slice(i, i + chunkSize));
      }
      return btoa(binary);
    },

    "pocketbase:base64ToBytes": ({ base64 }) => {
      const binary = atob(base64);
      return Array.from(binary, (c) => c.charCodeAt(0));
    },
  };
}

// --- Helpers ---

function getClient(clients, id) {
  const pb = clients.get(id);
  if (!pb) throw new Error(`PocketBase client "${id}" not found`);
  return pb;
}

function normalizeError(e) {
  const status = e?.status || e?.response?.status || 0;
  const message = e?.data?.message || e?.message || String(e);
  return { error: statusToCode(status) + ":" + message };
}

function statusToCode(status) {
  switch (status) {
    case 400: return "BAD_REQUEST";
    case 401: return "UNAUTHORIZED";
    case 403: return "FORBIDDEN";
    case 404: return "NOT_FOUND";
    case 409: return "CONFLICT";
    case 429: return "TOO_MANY_REQUESTS";
    default:  return "SERVER_ERROR";
  }
}
```

### Realtime Event Port Wiring

Since SSE subscriptions are long-lived, the consumer wires a dedicated port callback at app init:

```javascript
import * as ConcurrentTask from "@andrewmacmurray/elm-concurrent-task";
import { createTasks } from "elm-pocketbase";

const app = window.Elm.Main.init({ node: document.getElementById("app") });

// Set the global callback so subscribe tasks can route events to Elm
const pbTasks = createTasks();
pbTasks.setEventCallback((event) => {
  app.ports.onPocketbaseEvent.send(event);
});

ConcurrentTask.register({
  tasks: pbTasks,
  ports: { send: app.ports.send, receive: app.ports.receive },
});
```

---

## Error Protocol

### Wire Format (JS -> Elm)

| JS returns | Elm sees |
|---|---|
| `{ id, username, ... }` | `Success record` |
| `{ error: "NOT_FOUND:Record not found" }` | `Error NotFound` |
| `{ error: "UNAUTHORIZED:Invalid token" }` | `Error Unauthorized` |
| `{ error: "BAD_REQUEST:validation error" }` | `Error (BadRequest "validation error")` |
| thrown exception | `UnexpectedError (UnhandledJsException ...)` |

### Elm Error Decoder

```elm
errorDecoder : Decode.Decoder Error
errorDecoder =
    Decode.string
        |> Decode.andThen
            (\err ->
                case splitOnce ":" err of
                    Just ( "NOT_FOUND", _ ) -> Decode.succeed NotFound
                    Just ( "UNAUTHORIZED", _ ) -> Decode.succeed Unauthorized
                    Just ( "FORBIDDEN", _ ) -> Decode.succeed Forbidden
                    Just ( "BAD_REQUEST", msg ) -> Decode.succeed (BadRequest msg)
                    Just ( "CONFLICT", _ ) -> Decode.succeed Conflict
                    Just ( "TOO_MANY_REQUESTS", _ ) -> Decode.succeed TooManyRequests
                    Just ( "SERVER_ERROR", msg ) -> Decode.succeed (ServerError msg)
                    Just ( "NETWORK_ERROR", msg ) -> Decode.succeed (NetworkError msg)
                    _ -> Decode.fail ("Unknown PocketBase error: " ++ err)
            )


splitOnce : String -> String -> Maybe ( String, String )
splitOnce sep str =
    case String.indices sep str of
        i :: _ ->
            Just ( String.left i str, String.dropLeft (i + String.length sep) str )

        [] ->
            Nothing
```

---

## Usage Example: Partage Group Creation Flow

```elm
import ConcurrentTask exposing (ConcurrentTask)
import PocketBase
import PocketBase.Auth
import PocketBase.Collection
import PocketBase.Custom


type alias PoWSolution =
    { challenge : String
    , timestamp : Int
    , difficulty : Int
    , signature : String
    , solution : String
    }


createGroup :
    PocketBase.Client
    -> { createdAt : Int, createdBy : String }
    -> PoWSolution
    -> String  -- groupKeyBase64
    -> ConcurrentTask PocketBase.Error GroupRecord
createGroup client groupData pow groupKeyBase64 =
    -- Step 1: Create group with PoW (custom endpoint because of extra PoW fields)
    PocketBase.Custom.fetch client
        { method = "POST"
        , path = "/api/collections/groups/records"
        , body =
            Just
                (Encode.object
                    [ ( "createdAt", Encode.int groupData.createdAt )
                    , ( "createdBy", Encode.string groupData.createdBy )
                    , ( "pow_challenge", Encode.string pow.challenge )
                    , ( "pow_timestamp", Encode.int pow.timestamp )
                    , ( "pow_difficulty", Encode.int pow.difficulty )
                    , ( "pow_signature", Encode.string pow.signature )
                    , ( "pow_solution", Encode.string pow.solution )
                    ]
                )
        , decoder = groupRecordDecoder
        }
        |> ConcurrentTask.andThen
            (\group ->
                -- Step 2: Derive password and create user account
                PocketBase.Auth.derivePasswordFromKey groupKeyBase64
                    |> ConcurrentTask.andThen
                        (\password ->
                            PocketBase.Collection.create client
                                { collection = "users"
                                , body =
                                    Encode.object
                                        [ ( "username", Encode.string ("group_" ++ group.id) )
                                        , ( "password", Encode.string password )
                                        , ( "passwordConfirm", Encode.string password )
                                        , ( "groupId", Encode.string group.id )
                                        ]
                                , decoder = Decode.succeed ()
                                }
                                |> ConcurrentTask.andThen
                                    (\_ ->
                                        -- Step 3: Authenticate
                                        PocketBase.Auth.authWithPassword client
                                            { collection = "users"
                                            , identity = "group_" ++ group.id
                                            , password = password
                                            }
                                            |> ConcurrentTask.map (\_ -> group)
                                    )
                        )
            )
```

---

## PocketBase Collections Reference (from partage)

### `groups`

| Field | Type | Required | Notes |
|---|---|---|---|
| `createdAt` | number | yes | Unix timestamp (ms) |
| `createdBy` | text | yes | Public key hash |
| `powChallenge` | text | yes | Unique index prevents reuse |

Rules: public create (PoW validated by hook), view/list requires `@request.auth.groupId = id`.

### `users` (auth collection)

| Field | Type | Required | Notes |
|---|---|---|---|
| `username` | text | yes | Format: `group_{groupId}` |
| `email` | email | no | Unused |
| `groupId` | text | yes | Unique index, one user per group |

Rules: public create (hook validates groupId exists), auth via username + password.

### `loro_updates`

| Field | Type | Required | Notes |
|---|---|---|---|
| `groupId` | text | yes | Links to group |
| `timestamp` | number | yes | Client-provided (ms) |
| `actorId` | text | yes | Public key hash of author |
| `updateData` | text | yes | Base64-encoded Loro bytes, max 1MB |
| `version` | json | no | Loro version vector (debugging) |

Rules: create/view/list require `@request.auth.groupId = groupId`. No updates or deletes.

---

## Paginated Fetch Pattern

For fetching all Loro updates (initial sync), use a recursive task:

```elm
fetchAllUpdates :
    PocketBase.Client
    -> String
    -> ConcurrentTask PocketBase.Error (List LoroUpdateRecord)
fetchAllUpdates client groupId =
    fetchPage client groupId 1 []


fetchPage :
    PocketBase.Client
    -> String
    -> Int
    -> List LoroUpdateRecord
    -> ConcurrentTask PocketBase.Error (List LoroUpdateRecord)
fetchPage client groupId page accumulated =
    PocketBase.Collection.getList client
        { collection = "loro_updates"
        , page = page
        , perPage = 500
        , filter = Just ("groupId=\"" ++ groupId ++ "\"")
        , sort = Just "+timestamp"
        , decoder = loroUpdateDecoder
        }
        |> ConcurrentTask.andThen
            (\result ->
                let
                    all = accumulated ++ result.items
                in
                if List.length result.items < 500 then
                    ConcurrentTask.succeed all
                else
                    fetchPage client groupId (page + 1) all
            )
```
