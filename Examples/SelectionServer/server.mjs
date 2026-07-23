import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const directory = dirname(fileURLToPath(import.meta.url));
const configPath = process.env.SUPPORT_CONFIG_PATH ?? join(directory, 'support.config.json');
const defaultDevelopmentAppSession = 'local-development-session';

const scalarEquals = (left, right) =>
  left === right || (typeof left === 'number' && typeof right === 'number' && Number(left) === Number(right));

export const ruleMatches = (rule, context) => {
  const match = rule.match ?? {};
  if (match.userIDs && !match.userIDs.includes(context.userID)) return false;
  if (match.locales && !match.locales.includes(context.locale)) return false;
  for (const [key, allowed] of Object.entries(match.attributes ?? {})) {
    if (!allowed.some((candidate) => scalarEquals(context.attributes?.[key], candidate))) return false;
  }
  return true;
};

export const chooseExperience = (config, context) => {
  const rule = config.routing.find((candidate) => ruleMatches(candidate, context));
  const channel = rule?.channel ?? config.defaultChannel;
  const agentProvider = rule?.agentProvider ?? config.defaultAgentProvider;
  if (!config.channels[channel]?.enabled) {
    throw new Error(`Selected channel '${channel}' is not enabled`);
  }
  if (!config.agentProviders[agentProvider]?.enabled) {
    throw new Error(`Selected agent provider '${agentProvider}' is not enabled`);
  }
  return {
    channel,
    agentProvider,
    ...(config.humanHandoffAdapter ? { humanHandoffAdapter: config.humanHandoffAdapter } : {}),
    reason: rule?.reason ?? 'workspace default',
    ttlSeconds: 300,
  };
};

const readBody = async (request) => {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 64 * 1024) throw new Error('Request body exceeds 64 KB');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
};

const sendJSON = (response, statusCode, body) => {
  response.writeHead(statusCode);
  response.end(JSON.stringify(body));
};

const workspaceIDFromToken = (token) => {
  try {
    const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
    return typeof payload.workspaceId === 'string' && payload.workspaceId
      ? payload.workspaceId
      : undefined;
  } catch {
    return undefined;
  }
};

export const issueJakeSupportToken = async ({
  fetchImpl = fetch,
  environment = process.env,
} = {}) => {
  const publicKey = environment.JAKE_PUBLIC_KEY?.trim();
  const applicationSecret = environment.JAKE_APPLICATION_SECRET?.trim();
  if (!publicKey || !applicationSecret) {
    const error = new Error(
      'Set JAKE_PUBLIC_KEY and JAKE_APPLICATION_SECRET on the local token server.',
    );
    error.code = 'token_server_not_configured';
    throw error;
  }

  const baseURL = environment.JAKE_API_BASE_URL?.trim() || 'https://app.tryjake.ai';
  const sessionURL = new URL('/v1/sdk/sessions', baseURL);
  const upstream = await fetchImpl(sessionURL, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${applicationSecret}`,
      'Content-Type': 'application/json',
      'X-Jake-Public-Key': publicKey,
    },
    body: JSON.stringify({
      externalId: 'local-ios-test-user',
      displayName: 'Local Test User',
      attributes: {
        environment: 'development',
        platform: 'ios',
      },
    }),
  });

  const rawBody = await upstream.text();
  let payload;
  try {
    payload = rawBody ? JSON.parse(rawBody) : {};
  } catch {
    payload = {};
  }

  if (!upstream.ok) {
    const error = new Error(
      payload.message || payload.error || `Jake session request failed with ${upstream.status}.`,
    );
    error.code = 'jake_session_failed';
    error.statusCode = upstream.status;
    throw error;
  }
  if (typeof payload.token !== 'string' || !payload.token) {
    const error = new Error('Jake returned an empty support token.');
    error.code = 'empty_support_token';
    throw error;
  }
  const workspaceId = workspaceIDFromToken(payload.token);
  if (!workspaceId) {
    const error = new Error('Jake returned a support token without a workspace.');
    error.code = 'invalid_support_token';
    throw error;
  }

  return {
    token: payload.token,
    workspaceId,
    publicKey,
    ...(typeof payload.expiresIn === 'number' ? { expiresIn: payload.expiresIn } : {}),
  };
};

export const createSelectionServer = (
  loadConfig = async () => JSON.parse(await readFile(configPath, 'utf8')),
  {
    issueSupportToken = issueJakeSupportToken,
    developmentAppSession =
      process.env.DEVELOPMENT_APP_SESSION ?? defaultDevelopmentAppSession,
  } = {},
) => createServer(async (request, response) => {
  response.setHeader('Content-Type', 'application/json');
  if (request.method === 'POST' && request.url === '/mobile/support-token') {
    if (request.headers.authorization !== `Bearer ${developmentAppSession}`) {
      sendJSON(response, 401, { error: 'unauthorized' });
      return;
    }

    try {
      sendJSON(response, 200, await issueSupportToken());
    } catch (error) {
      const statusCode =
        error.code === 'token_server_not_configured'
          ? 503
          : Number.isInteger(error.statusCode)
            ? 502
            : 500;
      sendJSON(response, statusCode, {
        error: error.code ?? 'support_token_failed',
        message: error.message,
      });
    }
    return;
  }

  if (
    request.method !== 'POST' ||
    !['/support/selection', '/support/provider-selection'].includes(request.url)
  ) {
    sendJSON(response, 404, { error: 'not_found' });
    return;
  }

  try {
    const [config, context] = await Promise.all([loadConfig(), readBody(request)]);
    if (typeof context.userID !== 'string' || !context.userID) {
      sendJSON(response, 400, { error: 'userID_required' });
      return;
    }
    const selection = chooseExperience(config, context);
    sendJSON(
      response,
      200,
      request.url === '/support/provider-selection'
        ? { provider: selection.channel, reason: selection.reason, ttlSeconds: selection.ttlSeconds }
        : selection,
    );
  } catch (error) {
    sendJSON(response, 400, { error: 'invalid_request', message: error.message });
  }
});

const isEntrypoint = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isEntrypoint) {
  const host = process.env.HOST ?? '127.0.0.1';
  const port = Number(process.env.PORT ?? 8787);
  createSelectionServer().listen(port, host, () => {
    console.log(`Support development server listening on http://${host}:${port}`);
  });
}
