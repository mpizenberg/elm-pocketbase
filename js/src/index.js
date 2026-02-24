import PocketBase from "pocketbase";

let globalEventCallback = null;

export function createTasks() {
  const clients = new Map();
  let nextId = 0;

  function getClient(id) {
    const pb = clients.get(id);
    if (!pb) throw new Error(`PocketBase client "${id}" not found`);
    return pb;
  }

  const tasks = {
    "pocketbase:init": ({ url }) => {
      const id = String(nextId++);
      const pb = new PocketBase(url);
      pb.autoCancellation(false);
      clients.set(id, pb);
      return id;
    },

    "pocketbase:healthCheck": ({ clientId }) => {
      const pb = getClient(clientId);
      return pb.health
        .check()
        .then(() => true)
        .catch(() => false);
    },

    "pocketbase:authWithPassword": async ({
      clientId,
      collection,
      identity,
      password,
    }) => {
      const pb = getClient(clientId);
      try {
        const result = await pb
          .collection(collection)
          .authWithPassword(identity, password);
        return result.record;
      } catch (e) {
        return normalizeError(e);
      }
    },

    "pocketbase:refreshAuth": async ({ clientId, collection }) => {
      const pb = getClient(clientId);
      try {
        const result = await pb.collection(collection).authRefresh();
        return result.record;
      } catch (e) {
        pb.authStore.clear();
        return normalizeError(e);
      }
    },

    "pocketbase:isAuthenticated": ({ clientId }) => {
      const pb = getClient(clientId);
      return pb.authStore.isValid;
    },

    "pocketbase:getAuthRecord": ({ clientId }) => {
      const pb = getClient(clientId);
      if (!pb.authStore.isValid || !pb.authStore.record) return null;
      return pb.authStore.record;
    },

    "pocketbase:logout": ({ clientId }) => {
      getClient(clientId).authStore.clear();
    },

    "pocketbase:getOne": async ({ clientId, collection, id }) => {
      const pb = getClient(clientId);
      try {
        return await pb.collection(collection).getOne(id);
      } catch (e) {
        return normalizeError(e);
      }
    },

    "pocketbase:getList": async ({
      clientId,
      collection,
      page,
      perPage,
      filter,
      sort,
    }) => {
      const pb = getClient(clientId);
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
      const pb = getClient(clientId);
      try {
        return await pb.collection(collection).create(body);
      } catch (e) {
        return normalizeError(e);
      }
    },

    "pocketbase:customFetch": async ({ clientId, method, path, body }) => {
      const pb = getClient(clientId);
      const url = pb.baseUrl + path;
      try {
        const opts = {
          method,
          headers: { "Content-Type": "application/json" },
        };
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

    "pocketbase:subscribe": async ({ clientId, collection }) => {
      const pb = getClient(clientId);
      await pb.collection(collection).subscribe("*", (e) => {
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
      const pb = getClient(clientId);
      await pb.collection(collection).unsubscribe("*");
    },

    "pocketbase:unsubscribeAll": async ({ clientId }) => {
      const pb = getClient(clientId);
      await pb.collection("*").unsubscribe("*");
    },
  };

  tasks.setEventCallback = (callback) => {
    globalEventCallback = callback;
  };

  return tasks;
}

function normalizeError(e) {
  const status = e?.status || e?.response?.status || 0;
  const message = e?.data?.message || e?.message || String(e);
  return { error: statusToCode(status) + ":" + message };
}

function statusToCode(status) {
  switch (status) {
    case 400:
      return "BAD_REQUEST";
    case 401:
      return "UNAUTHORIZED";
    case 403:
      return "FORBIDDEN";
    case 404:
      return "NOT_FOUND";
    case 409:
      return "CONFLICT";
    case 429:
      return "TOO_MANY_REQUESTS";
    default:
      return "SERVER_ERROR";
  }
}
