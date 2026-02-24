# elm-pocketbase example

A working demo of every major module: init, health check, auth, CRUD, and realtime subscriptions.

## Prerequisites

- [PocketBase](https://pocketbase.io/docs/) (download the binary)
- [Node.js](https://nodejs.org/) >= 18
- [Elm](https://elm-lang.org/) 0.19.1

## 1. Start PocketBase

```sh
cd example/pocketbase-server/
./pocketbase serve
```

Open the admin UI at <http://127.0.0.1:8090/_/> and create an admin account.

## 2. Create collections

In the PocketBase admin UI:

1. The **users** auth collection already exists by default.
2. Create a **messages** collection with one field:
   - `text` — Plain text

Set the **messages** collection API rules to allow authenticated users
(or leave them empty for unrestricted access during testing).

3. Create a test user in the **users** collection.

## 3. Run the example

```sh
cd example/
npm install
npm start
```

Open the URL printed by elm-watch (usually <http://localhost:8001>
or similar). You should see the health check status, a login form,
and after logging in: a message list, a create form, and a realtime
event log.

## What it demonstrates

| Feature | Module used |
|---|---|
| Client init + health check | `PocketBase.init`, `PocketBase.healthCheck` |
| Login / logout | `PocketBase.Auth.authWithPassword`, `PocketBase.Auth.logout` |
| List records (paginated) | `PocketBase.Collection.getList` |
| Create a record | `PocketBase.Collection.create` |
| Realtime events (SSE) | `PocketBase.Realtime.subscribe`, port `onPocketbaseEvent` |
