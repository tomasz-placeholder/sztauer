// Dynamic port router for Sztauer.
// Parses the Host header to extract a target port and proxies to localhost.
//   {name}-{port}.localhost → localhost:{port}
//   {name}-app.localhost    → localhost:APP_PORT (default 8000)

const http = require("http");
const net = require("net");

const APP_PORT = parseInt(process.env.APP_PORT || "8000", 10);

function extractPort(host) {
  if (!host) return null;
  const portMatch = host.match(/-(\d+)\.localhost/);
  if (portMatch) return parseInt(portMatch[1], 10);
  if (/-app\.localhost/.test(host)) return APP_PORT;
  return null;
}

// HTTP proxy
const server = http.createServer((req, res) => {
  const port = extractPort(req.headers.host);
  if (!port) {
    res.writeHead(404);
    res.end("Cannot determine target port from hostname");
    return;
  }

  const proxyReq = http.request(
    {
      hostname: "127.0.0.1",
      port,
      path: req.url,
      method: req.method,
      headers: { ...req.headers, host: `localhost:${port}` },
    },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    }
  );

  proxyReq.on("error", () => {
    res.writeHead(502);
    res.end(`No service on port ${port}`);
  });

  req.pipe(proxyReq);
});

// WebSocket proxy (upgrade)
server.on("upgrade", (req, socket, head) => {
  const port = extractPort(req.headers.host);
  if (!port) {
    socket.destroy();
    return;
  }

  const conn = net.connect({ port, host: "127.0.0.1" }, () => {
    // Reconstruct the raw HTTP upgrade request
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
