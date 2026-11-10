// Local contract stand-in only; no real Cloudinary assets or credentials.
const http = require('http');
http.createServer((req, res) => {
  const path = new URL(req.url, 'http://localhost').pathname;
  const match = /^\/v1_1\/([^/]+)\/raw\/upload$/.exec(path);
  if (req.method !== 'POST' || !match) {
    res.writeHead(501); return res.end('Endpoint not modeled');
  }
  const cloud = match[1];
  const finish = () => {
    if (cloud === 'invalid-json') { res.writeHead(200); return res.end('<html>bad gateway</html>'); }
    const status = { rejected: 400, limited: 429, unavailable: 500 }[cloud] || 200;
    res.writeHead(status, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(status === 200 ? {
      secure_url: `https://res.cloudinary.com/${cloud}/raw/upload/v1/vista-ci/reports/user-a/ci_1_10_2_1.pdf`,
      public_id: 'vista-ci/reports/user-a/ci_1_10_2_1.pdf', resource_type: 'raw', bytes: 100
    } : { error: { message: 'Simulated provider failure' } }));
  };
  if (cloud === 'slow') setTimeout(finish, 1500); else finish();
}).listen(process.env.PORT || 4513);
