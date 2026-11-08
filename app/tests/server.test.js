// Boots the browser-mode server and exercises the API without a model (no network).
const assert = require("assert"), fs = require("fs"), os = require("os"), path = require("path"), http = require("http");
process.env.NO_OPEN = "1";
const { server, TOKEN } = require("../src-main/server");
const project = fs.mkdtempSync(path.join(os.tmpdir(), "studio-web-")); fs.writeFileSync(path.join(project, "p.html"), "<p>hi</p>");
const get = (p, h = {}) => new Promise(r => http.get({ host: "127.0.0.1", port: server.address().port, path: p, headers: h }, res => { let b = ""; res.on("data", d => b += d); res.on("end", () => r([res.statusCode, b])); }));
const post = (n, arg) => new Promise(r => { const q = http.request({ host: "127.0.0.1", port: server.address().port, path: "/api/" + n, method: "POST", headers: { "x-token": TOKEN } }, res => { let b = ""; res.on("data", d => b += d); res.on("end", () => r([res.statusCode, b])); }); q.end(JSON.stringify({ arg })); });
server.listen(0, "127.0.0.1", async () => {
  try {
    let [c, b] = await get("/"); assert(c === 200 && b.includes("STUDIO_TOKEN") && b.includes("bridge-web.js"));
    [c] = await get("/renderer.js"); assert(c === 200);
    [c] = await get("/file?p=" + encodeURIComponent(path.join(project, "p.html"))); assert(c === 403, "file needs token");
    [c] = await post("cfg"); assert(c === 200);
    [c, b] = await new Promise(r => { const q = http.request({ host: "127.0.0.1", port: server.address().port, path: "/api/cfg", method: "POST" }, res => r([res.statusCode])); q.end("{}"); }); assert(c === 404 || c === 403, "api needs token");
    [c, b] = await post("pickProject", project); assert(JSON.parse(b) === project);
    [c, b] = await get("/file?k=" + TOKEN + "&p=" + encodeURIComponent(path.join(project, "p.html"))); assert(c === 200 && b === "<p>hi</p>");
    [c] = await get("/file?k=" + TOKEN + "&p=" + encodeURIComponent("/etc/hosts")); assert(c === 403, "outside refused");
    console.log("server test ok");
  } catch (e) { console.error(e); process.exitCode = 1; } finally { server.close(); }
});
