const http = require("http");
const { URL } = require("url");

const PROXY = new URL(process.env.HTTP_PROXY || "http://host.docker.internal:3128");
const TARGET = "localhost:11434";
const LISTEN_HOST = "127.0.0.1";
const LISTEN_PORT = 54321;

http.createServer((req, res) => {
  const proxyReq = http.request({
    hostname: PROXY.hostname,
    port: PROXY.port,
    path: "http://" + TARGET + req.url,
    method: req.method,
    headers: {
      ...req.headers,
      host: TARGET
    }
  }, (proxyRes) => {
    res.writeHead(proxyRes.statusCode || 502, proxyRes.headers);
    proxyRes.pipe(res);
  });

  proxyReq.on("error", (err) => {
    res.writeHead(502, { "content-type": "text/plain" });
    res.end(`bridge error: ${err.message}\n`);
  });

  req.pipe(proxyReq);
}).listen(LISTEN_PORT, LISTEN_HOST, () => {
  console.log(`bridge listening on http://${LISTEN_HOST}:${LISTEN_PORT} -> ${TARGET} via ${PROXY.href}`);
});