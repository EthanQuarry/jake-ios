'use strict';

const { NativeEventEmitter, NativeModules, Platform } = require('react-native');

const LINKING_ERROR =
  "The Jake native module isn't linked. Rebuild the app after installing @tryjakeai/react-native.";
const nativeModule = NativeModules.JakeSdk;

function native() {
  if (!nativeModule) {
    throw new Error(`${LINKING_ERROR} (platform: ${Platform.OS})`);
  }
  return nativeModule;
}

const JakeEvent = Object.freeze({
  unreadCountChanged: 'jakeUnreadCountChanged',
  authenticationExpired: 'jakeAuthenticationExpired',
  error: 'jakeError',
});

const Jake = {
  configure(options) {
    return native().configure(options);
  },
  authenticate(userId, token) {
    return native().authenticate(userId, token);
  },
  present() {
    return native().present();
  },
  dismiss() {
    return native().dismiss();
  },
  logout() {
    return native().logout();
  },
  track(event, properties = {}) {
    return native().track(event, properties);
  },
  setUserAttributes(attributes) {
    return native().setUserAttributes(attributes);
  },
  setPushToken(token) {
    return native().setPushToken(token);
  },
  getUnreadCount() {
    return native().getUnreadCount();
  },
  addEventListener(event, listener) {
    const emitter = new NativeEventEmitter(native());
    return emitter.addListener(event, listener);
  },
};

module.exports = { Jake, JakeEvent };
