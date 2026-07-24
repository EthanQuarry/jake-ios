import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const methods = [
  "configure",
  "authenticate",
  "present",
  "dismiss",
  "logout",
  "track",
  "setUserAttributes",
  "setPushToken",
  "getUnreadCount",
];
const events = [
  "unreadCountChanged",
  "authenticationExpired",
  "error",
];

const files = {
  reactNativeJavaScript: await read("packages/react-native-jake/src/index.js"),
  reactNativeIos: await read("packages/react-native-jake/ios/JakeReactNative.swift"),
  reactNativeAndroid: await read(
    "packages/react-native-jake/android/src/main/java/ai/tryjake/reactnative/JakeReactNativeModule.kt",
  ),
  flutterDart: await read("packages/jake_flutter/lib/jake_flutter.dart"),
  flutterIos: await read("packages/jake_flutter/ios/Classes/JakeFlutterPlugin.swift"),
  flutterAndroid: await read(
    "packages/jake_flutter/android/src/main/kotlin/ai/tryjake/flutter/JakeFlutterPlugin.kt",
  ),
};

for (const method of methods) {
  for (const [target, source] of Object.entries(files)) {
    assert.match(source, new RegExp(`\\b${method}\\b`), `${target} is missing ${method}`);
  }
}

for (const event of events) {
  for (const [target, source] of Object.entries(files)) {
    assert.match(
      source.toLowerCase(),
      new RegExp(event.toLowerCase()),
      `${target} is missing ${event}`,
    );
  }
}

const pubspec = await read("packages/jake_flutter/pubspec.yaml");
assert.match(pubspec, /platforms:\s*\n\s+android:/);
assert.match(pubspec, /\n\s+ios:/);

const reactNativePackage = JSON.parse(
  await read("packages/react-native-jake/package.json"),
);
assert.equal(reactNativePackage["react-native"], "src/index.js");
assert.ok(reactNativePackage.files.includes("ios"));
assert.ok(reactNativePackage.files.includes("android"));

console.log(
  `Validated ${methods.length} methods and ${events.length} events across Flutter and React Native on iOS and Android.`,
);

async function read(relativePath) {
  return readFile(path.join(root, relativePath), "utf8");
}
