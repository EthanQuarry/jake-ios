'use strict';

const assert = require('node:assert/strict');
const Module = require('node:module');
const test = require('node:test');

function loadWithNative(nativeModule) {
  const originalLoad = Module._load;
  const calls = [];
  const emitter = {
    addListener(event, listener) {
      calls.push(['addListener', event, listener]);
      return { remove() {} };
    },
  };
  Module._load = function load(request, parent, isMain) {
    if (request === 'react-native') {
      return {
        NativeModules: { JakeSdk: nativeModule },
        NativeEventEmitter: function NativeEventEmitter() {
          return emitter;
        },
        Platform: { OS: 'test' },
      };
    }
    return originalLoad(request, parent, isMain);
  };
  const modulePath = require.resolve('../src/index.js');
  delete require.cache[modulePath];
  const result = require(modulePath);
  Module._load = originalLoad;
  return { ...result, calls };
}

test('forwards the complete public API to the native module', async () => {
  const calls = [];
  const native = new Proxy(
    {},
    {
      get: (_, method) => (...args) => {
        calls.push([method, ...args]);
        return Promise.resolve(method === 'getUnreadCount' ? 4 : undefined);
      },
    },
  );
  const { Jake } = loadWithNative(native);

  await Jake.configure({ workspaceId: 'w', publicKey: 'pk' });
  await Jake.authenticate('user', 'token');
  await Jake.present();
  await Jake.track('opened', { source: 'test' });
  await Jake.setUserAttributes({ plan: 'pro' });
  await Jake.setPushToken('push-token');
  assert.equal(await Jake.getUnreadCount(), 4);
  await Jake.dismiss();
  await Jake.logout();

  assert.deepEqual(
    calls.map(([name]) => name),
    [
      'configure',
      'authenticate',
      'present',
      'track',
      'setUserAttributes',
      'setPushToken',
      'getUnreadCount',
      'dismiss',
      'logout',
    ],
  );
});

test('uses stable cross-platform event names', () => {
  const { Jake, JakeEvent, calls } = loadWithNative({});
  const subscription = Jake.addEventListener(JakeEvent.unreadCountChanged, () => {});
  assert.equal(calls[0][1], 'jakeUnreadCountChanged');
  assert.equal(typeof subscription.remove, 'function');
});
