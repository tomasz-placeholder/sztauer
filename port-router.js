// Global port router for Sztauer (runs in infra alongside Caddy).
// Parses Host header to extract project name and port, then proxies
// to the correct container via Docker DNS.
//
//   {name}-{port}.localhost → sztauer-{name}-workspace:{port}
//   {name}-app.localhost    → sztauer-{name}-workspace:8000

const http = require("http");
const net = require("net");

const DEFAULT_APP_PORT = 8000;

function parseHost(host) {
  if (!host) return null;

  // {name}-{port}.localhost
  const portMatch = host.match(/^(.+)-(\d+)\.localhost/);
  if (portMatch) {
    return { name: portMatch[1], port: parseInt(portMatch[2], 10) };
  }

  // {name}-app.localhost
  const appMatch = host.match(/^(.+)-app\.localhost/);
  if (appMatch) {
    return { name: appMatch[1], port: DEFAULT_APP_PORT };
  }

  return null;
}

function containerHost(name) {
  return `sztauer-${name}-workspace`;
}

// HTTP proxy
const server = http.createServer((req, res) => {
  const target = parseHost(req.headers.host);
  if (!target) {
    res.writeHead(404);
    res.end("Cannot determine target from hostname");
    return;
  }

  const upstream = containerHost(target.name);
  const proxyReq = http.request(
    {
      hostname: upstream,
      port: target.port,
      path: req.url,
      method: req.method,
      headers: { ...req.headers, host: `localhost:${target.port}` },
    },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    }
  );

  proxyReq.on("error", (e) => {
    res.writeHead(502);
    res.end(`Cannot reach ${upstream}:${target.port} — ${e.message}`);
  });

  req.pipe(proxyReq);
});

// WebSocket proxy (upgrade)
server.on("upgrade", (req, socket, head) => {
  const target = parseHost(req.headers.host);
  if (!target) {
    socket.destroy();
    return;
  }

  const upstream = containerHost(target.name);
  const conn = net.connect({ port: target.port, host: upstream }, () => {
    let header = `${req.method} ${req.url} HTTP/${req.httpVersion}\r\n`;
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      header += `${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}\r\n`;
    }
    header += "\r\n";
    conn.write(header);
    if (head.length) conn.write(head);
    socket.pipe(conn).pipe(socket);
  });

  conn.on("error", () => socket.destroy());
  socket.on("error", () => conn.destroy());
});

server.listen(9091, () => {
  console.log("Port router listening on 9091");
});
