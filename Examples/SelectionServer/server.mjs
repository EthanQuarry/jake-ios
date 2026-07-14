import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const directory = dirname(fileURLToPath(import.meta.url));
const configPath = process.env.SUPPORT_CONFIG_PATH ?? join(directory, 'support.config.json');

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

export const createSelectionServer = (loadConfig = async () =>
  JSON.parse(await readFile(configPath, 'utf8'))) => createServer(async (request, response) => {
  response.setHeader('Content-Type', 'application/json');
  if (
    request.method !== 'POST' ||
    !['/support/selection', '/support/provider-selection'].includes(request.url)
  ) {
    response.writeHead(404);
    response.end(JSON.stringify({ error: 'not_found' }));
    return;
  }

  try {
    const [config, context] = await Promise.all([loadConfig(), readBody(request)]);
    if (typeof context.userID !== 'string' || !context.userID) {
      response.writeHead(400);
      response.end(JSON.stringify({ error: 'userID_required' }));
      return;
    }
    const selection = chooseExperience(config, context);
    response.writeHead(200);
    response.end(
      JSON.stringify(
        request.url === '/support/provider-selection'
          ? { provider: selection.channel, reason: selection.reason, ttlSeconds: selection.ttlSeconds }
          : selection,
      ),
    );
  } catch (error) {
    response.writeHead(400);
    response.end(JSON.stringify({ error: 'invalid_request', message: error.message }));
  }
});

const isEntrypoint = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isEntrypoint) {
  const host = process.env.HOST ?? '127.0.0.1';
  const port = Number(process.env.PORT ?? 8787);
  createSelectionServer().listen(port, host, () => {
    console.log(`Selection server listening on http://${host}:${port}`);
  });
}
