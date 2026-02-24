import * as ConcurrentTask from "@andrewmacmurray/elm-concurrent-task";
import { createTasks } from "../../js/src/index.js";

// elm-watch exposes the Elm global via the build/elm.js script tag
const app = Elm.Main.init({ node: document.getElementById("app") });

const pbTasks = createTasks();

pbTasks.setEventCallback((event) => {
  app.ports.onPocketbaseEvent.send(event);
});

ConcurrentTask.register({
  tasks: pbTasks,
  ports: {
    send: app.ports.send,
    receive: app.ports.receive,
  },
});
