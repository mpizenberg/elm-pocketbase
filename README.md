# elm-pocketbase

An Elm client for [PocketBase](https://pocketbase.io), built on [elm-concurrent-task](https://github.com/andrewMacmurray/elm-concurrent-task).

## What is PocketBase?

PocketBase is an open-source backend consisting of an embedded database (SQLite), built-in auth, file storage, and real-time subscriptions via Server-Sent Events (SSE) — all in a single binary. It exposes a REST API and an admin dashboard out of the box, making it a lightweight alternative to Firebase for small to medium projects.

## How this package works

This package wraps the [PocketBase JavaScript SDK](https://github.com/pocketbase/js-sdk) and exposes it to Elm through **elm-concurrent-task**. This means all PocketBase operations (auth, CRUD, custom requests) are composable `ConcurrentTask` values rather than raw `Cmd` messages — you can chain, map, and sequence them without extra `Msg` boilerplate.

Real-time subscriptions (SSE) use a separate port-based approach, since long-lived event streams don't fit the request-response model of tasks.

### Architecture

```
Elm (ConcurrentTask)  ──JSON──▶  JS companion  ──▶  PocketBase JS SDK  ──▶  PocketBase server
                       ◀─JSON──                 ◀──                     ◀──

Elm (port subscription) ◀─JSON── JS callback ◀── SSE events
```

- **Elm side** defines task-based APIs that encode to JSON messages.
- **JS companion** (`js/src/index.js`) maps those messages to PocketBase SDK calls and returns results.
- **Real-time events** flow from PocketBase SSE through a JS callback into an Elm port.

## Modules

| Module | Purpose |
|---|---|
| `PocketBase` | Client initialization (`init`) and health check |
| `PocketBase.Auth` | Password auth, token refresh, logout, auth state queries (generic decoder) |
| `PocketBase.Collection` | `getOne`, `getList`, `create` on any collection |
| `PocketBase.Custom` | Raw HTTP requests to custom API endpoints |
| `PocketBase.Realtime` | Subscribe/unsubscribe to collection changes via SSE |
| `PocketBase.Encode` | `Bytes` ↔ Base64 conversion utilities |

## Example

A complete working example lives in the [`example/`](example/) directory. See its [README](example/README.md) for setup instructions.

## Setup

### Elm dependency

```
elm install mpizenberg/elm-pocketbase
```

### JavaScript dependency

```
npm install pocketbase
```

The JS companion also requires `@andrewmacmurray/elm-concurrent-task` as a peer dependency.

### Wiring

Import and call `createTasks()` from the JS entry point to get the task runner and event helpers needed by elm-concurrent-task and the real-time port.

## Quick example

```elm
import ConcurrentTask exposing (ConcurrentTask)
import PocketBase
import PocketBase.Auth
import PocketBase.Collection

-- Initialize a client, authenticate, then fetch a record.
loginAndFetch : ConcurrentTask PocketBase.Error MyRecord
loginAndFetch =
    PocketBase.init "http://localhost:8090"
        |> ConcurrentTask.andThen
            (\client ->
                PocketBase.Auth.authWithPassword client
                    { collection = "users"
                    , identity = "user@example.com"
                    , password = "secret"
                    , decoder = userDecoder
                    }
                    |> ConcurrentTask.andThen
                        (\_ ->
                            PocketBase.Collection.getOne client
                                { collection = "posts"
                                , id = "record_id"
                                , decoder = myRecordDecoder
                                }
                        )
            )
```

## License

BSD-3-Clause
