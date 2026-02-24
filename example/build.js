import esbuild from "esbuild";

await esbuild.build({
  entryPoints: ["src/interop.js"],
  bundle: true,
  format: "esm",
  outfile: "public/build/interop.js",
  external: [],
});
