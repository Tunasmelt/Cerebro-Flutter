// Local, one-use credential handoff for sealed_security_check.dart.
// Set CEREBRO_TEST_USER_B_EMAIL/PASSWORD in this process's environment.
// Nothing is written to disk; keep this port bound to loopback.
import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';

let email = process.env.CEREBRO_TEST_USER_B_EMAIL;
let password = process.env.CEREBRO_TEST_USER_B_PASSWORD;
delete process.env.CEREBRO_TEST_USER_B_EMAIL;
delete process.env.CEREBRO_TEST_USER_B_PASSWORD;
if (!email || !password) throw new Error('Provide test-user credentials');
const config = readFileSync('lib/core/config/supabase_config.dart', 'utf8');
const url = config.match(/url\s*=\s*'([^']+)'/)[1];
const key = config.match(/anonKey\s*=\s*'([^']+)'/)[1];
const result = await fetch(`${url}/auth/v1/token?grant_type=password`, {
  method: 'POST',
  headers: { apikey: key, 'content-type': 'application/json' },
  body: JSON.stringify({ email, password }),
  signal: AbortSignal.timeout(30000),
});
if (!result.ok) {
  console.log(`MILESTONE_5_4_SECOND_ACCOUNT_LOGIN_HTTP_${result.status}`);
  process.exit(1);
}
const session = await result.json();
if (!session.user?.email_confirmed_at || !session.access_token) {
  throw new Error('Second account is not confirmed');
}
console.log('MILESTONE_5_4_SECOND_ACCOUNT_CONFIRMED');
let used = false;
const server = createServer((request, response) => {
  if (used || request.method !== 'GET' || request.url !== '/credentials') {
    response.writeHead(404).end();
    return;
  }
  used = true;
  response.writeHead(200, {
    'content-type': 'application/json',
    'cache-control': 'no-store',
  });
  response.end(JSON.stringify({ email, password }));
  email = password = undefined;
  clearTimeout(expiry);
  server.close();
});
const expiry = setTimeout(() => {
  email = password = undefined;
  server.close();
}, 15 * 60 * 1000);
server.listen(47854, '127.0.0.1', () => {
  console.log('MILESTONE_5_4_CREDENTIAL_HANDOFF_READY');
});
