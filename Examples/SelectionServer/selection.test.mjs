import assert from 'node:assert/strict';
import test from 'node:test';
import { chooseExperience, ruleMatches } from './server.mjs';

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
