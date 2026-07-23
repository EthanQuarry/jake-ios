import assert from 'node:assert/strict';
import test from 'node:test';
import {
  chooseExperience,
  createSelectionServer,
  issueJakeSupportToken,
  ruleMatches,
} from './server.mjs';

const config = {
  defaultChannel: 'supportkit-native',
  channels: { 'supportkit-native': { enabled: true } },
  defaultAgentProvider: 'jake',
  agentProviders: {
    jake: { enabled: true },
    internal: { enabled: true },
  },
  routing: [
    {
      agentProvider: 'internal',
      reason: 'enterprise route',
      match: { attributes: { plan: ['enterprise'] } },
    },
  ],
};

test('matches allowlisted routing attributes', () => {
  assert.equal(
    ruleMatches(config.routing[0], { userID: '42', attributes: { plan: 'enterprise' } }),
    true,
  );
  assert.equal(
    ruleMatches(config.routing[0], { userID: '42', attributes: { plan: 'starter' } }),
    false,
  );
});

test('selects the channel independently from the first matching agent', () => {
  assert.deepEqual(
    chooseExperience(config, { userID: '42', attributes: { plan: 'enterprise' } }),
    {
      channel: 'supportkit-native',
      agentProvider: 'internal',
      reason: 'enterprise route',
      ttlSeconds: 300,
    },
  );
});

test('falls back to the configured default', () => {
  assert.equal(
    chooseExperience(config, { userID: '42', attributes: { plan: 'starter' } }).agentProvider,
    'jake',
  );
});

test('rejects disabled destinations', () => {
  assert.throws(() =>
    chooseExperience(
      {
        ...config,
        agentProviders: { ...config.agentProviders, internal: { enabled: false } },
      },
      { userID: '42', attributes: { plan: 'enterprise' } },
    ),
  );
});

const listen = async (server) => {
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  return `http://127.0.0.1:${port}`;
};

test('issues an authenticated development support token', async (context) => {
  const server = createSelectionServer(async () => config, {
    developmentAppSession: 'test-app-session',
    issueSupportToken: async () => ({
      token: 'short-lived-token',
      workspaceId: 'workspace-1',
      publicKey: 'pk_test',
      expiresIn: 300,
    }),
  });
  context.after(() => server.close());
  const baseURL = await listen(server);

  const response = await fetch(`${baseURL}/mobile/support-token`, {
    method: 'POST',
    headers: { Authorization: 'Bearer test-app-session' },
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    token: 'short-lived-token',
    workspaceId: 'workspace-1',
    publicKey: 'pk_test',
    expiresIn: 300,
  });
});

test('rejects unauthenticated development token requests', async (context) => {
  const server = createSelectionServer(async () => config, {
    developmentAppSession: 'test-app-session',
    issueSupportToken: async () => ({ token: 'short-lived-token' }),
  });
  context.after(() => server.close());
  const baseURL = await listen(server);

  const response = await fetch(`${baseURL}/mobile/support-token`, { method: 'POST' });

  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: 'unauthorized' });
});

test('keeps Jake application secrets on the server', async () => {
  let request;
  const tokenPayload = Buffer.from(
    JSON.stringify({ workspaceId: 'workspace-1' }),
  ).toString('base64url');
  const supportToken = `header.${tokenPayload}.signature`;
  const result = await issueJakeSupportToken({
    environment: {
      JAKE_PUBLIC_KEY: 'pk_test',
      JAKE_APPLICATION_SECRET: 'app_secret',
      JAKE_API_BASE_URL: 'https://app.example.test',
    },
    fetchImpl: async (url, options) => {
      request = { url: url.toString(), options };
      return new Response(
        JSON.stringify({ token: supportToken, expiresIn: 300 }),
        { status: 201, headers: { 'Content-Type': 'application/json' } },
      );
    },
  });

  assert.deepEqual(result, {
    token: supportToken,
    workspaceId: 'workspace-1',
    publicKey: 'pk_test',
    expiresIn: 300,
  });
  assert.equal(request.url, 'https://app.example.test/v1/sdk/sessions');
  assert.equal(request.options.headers.Authorization, 'Bearer app_secret');
  assert.equal(request.options.headers['X-Jake-Public-Key'], 'pk_test');
  assert.equal(request.options.body.includes('app_secret'), false);
});
