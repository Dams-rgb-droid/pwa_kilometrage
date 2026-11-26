{{flutter_js}}
{{flutter_build_config}}

// Le démarrage de Flutter n'attend plus le service worker (c'était la cause des
// écrans bloqués). offline_worker.js est enregistré en parallèle dans index.html.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
