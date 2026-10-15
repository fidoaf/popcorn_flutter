import { test } from "node:test";
import assert from "node:assert/strict";
import { isPushEndpoint, validateMessage } from "./validation.ts";

const appUrl = "https://example.com/popcorn/";

test("validates and trims notifications and resolves app-relative URLs", () => {
  assert.deepEqual(validateMessage({ title: " News ", body: " Hello ", url: "#/home" }, appUrl), {
    title: "News", body: "Hello", url: appUrl + "#/home",
  });
  assert.equal(validateMessage({ title: "News", body: "Hello" }, appUrl).url, appUrl);
});

test("enforces exact title and body length limits", () => {
  assert.doesNotThrow(() => validateMessage({ title: "a".repeat(100), body: "b".repeat(1000) }, appUrl));
  for (const input of [
    null, {}, { title: " ", body: "Hello" }, { title: "News", body: "" },
    { title: "a".repeat(101), body: "Hello" },
    { title: "News", body: "b".repeat(1001) },
    { title: 1, body: "Hello" }, { title: "News", body: 1 },
  ]) assert.throws(() => validateMessage(input, appUrl));
});

test("rejects external, out-of-app, credentialed and non-string URLs", () => {
  for (const url of [
    "https://evil.example/", "//evil.example/", "javascript:alert(1)", "../other/",
    "/popcorn-evil/", "https://user:password@example.com/popcorn/", 1,
  ]) assert.throws(() => validateMessage({ title: "News", body: "Hello", url }, appUrl));
});

test("rejects payloads exceeding the encrypted push byte budget", () => {
  assert.throws(() => validateMessage({ title: "News", body: "😀".repeat(500), url: "?query=" + "x".repeat(1200) }, appUrl), /too large/);
});

test("only accepts known HTTPS push services and blocks spoofed hosts", () => {
  for (const endpoint of [
    "https://fcm.googleapis.com/fcm/send/token",
    "https://updates.push.services.mozilla.com/wpush/v2/token",
    "https://web.push.apple.com/token",
    "https://wns.notify.windows.com/token",
  ]) assert.equal(isPushEndpoint(endpoint), true, endpoint);
  for (const endpoint of [
    "http://fcm.googleapis.com/token", "https://fcm.googleapis.com.evil.example/token",
    "https://localhost/token", "https://127.0.0.1/token",
    "https://user@fcm.googleapis.com/token", "https://fcm.googleapis.com:8443/token", "not a url",
  ]) assert.equal(isPushEndpoint(endpoint), false, endpoint);
});
