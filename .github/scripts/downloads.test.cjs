const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { test } = require("node:test");
const { platforms, selectArtifacts, renderSummary, prepare, publishSummary } = require("./downloads.cjs");

const context = { repo: { owner: "example", repo: "client" }, runId: 293 };
const firstStart = "2026-11-13T07:36:00Z";
const retryStart = "2026-11-13T07:56:11Z";
const original = platforms.map((platform, i) => ({
  id: i + 1, name: platform.name, created_at: "2026-11-13T07:49:54Z", expired: false,
}));
const payload = Buffer.from("release binary contents\n");
const archive = execFileSync("python3", ["-c", [
  "import io,sys,zipfile", "buffer=io.BytesIO()",
  "with zipfile.ZipFile(buffer,'w') as z: z.writestr('app.apk',sys.stdin.buffer.read())",
  "sys.stdout.buffer.write(buffer.getvalue())",
].join("\n")], { input: payload });

function fixture(t, artifacts = original, started = firstStart) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "downloads-test-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const calls = [], outputs = {}, failures = [], summaries = [];
  const core = {
    setOutput: (key, value) => { outputs[key] = value; },
    setFailed: (message) => failures.push(message),
    summary: { addRaw(value) { summaries.push(value); return this; }, async write() {} },
  };
  const list = () => {};
  const github = {
    async paginate(method, args) {
      assert.equal(method, list);
      assert.deepEqual(args, { ...context.repo, run_id: 293, per_page: 100 });
      return artifacts;
    },
    rest: { actions: {
      listWorkflowRunArtifacts: list,
      async getWorkflowRunAttempt(args) {
        assert.equal(args.run_id, 293);
        assert.equal(args.attempt_number, started === retryStart ? 2 : 1);
        return { data: { run_started_at: started } };
      },
      async downloadArtifact(args) {
        assert.equal(args.archive_format, "zip");
        calls.push(args.artifact_id);
        return { data: archive };
      },
    } },
  };
  return {
    github, core, context, directory, calls, outputs, failures, summaries,
    attemptNumber: started === retryStart ? 2 : 1,
  };
}

test("chooses the newest usable artifact and ignores diagnostics and expired copies", () => {
  const artifacts = [
    ...original,
    { ...original[0], id: 6, created_at: "2026-11-13T08:00:00Z" },
    { ...original[0], id: 7, created_at: "2026-11-13T08:01:00Z", expired: true },
    { ...original[0], id: 8, name: "android-startup-results" },
  ];
  assert.equal(selectArtifacts(artifacts)[0].artifact.id, 6);
  assert.equal(artifacts[0].id, 1);
  assert.equal(selectArtifacts(artifacts).length, 5);
});

test("first build uses the original downloads without duplicate uploads", async (t) => {
  const f = fixture(t);
  await prepare(f);
  assert.deepEqual(f.calls, []);
  assert.ok(Object.values(f.outputs).every((value) => value === "false"));
  await publishSummary({ ...f, needs: { android: { result: "success" }, build: { result: "success" } } });
  assert.equal(f.failures.length, 0);
  assert.match(f.summaries[0], /runs\/293\/artifacts\/1/);
});

test("test-only retry recovers every platform's binary byte for byte", async (t) => {
  const f = fixture(t, original, retryStart);
  await prepare(f);
  assert.deepEqual(f.calls, [1, 2, 3, 4, 5]);
  for (const { key } of platforms) {
    assert.equal(f.outputs[`restore_${key}`], "true");
    assert.deepEqual(fs.readFileSync(path.join(f.directory, key, "app.apk")), payload);
  }
});

test("mixed retry only recovers platforms which did not rebuild in this attempt", async (t) => {
  const fresh = { ...original[0], id: 9, created_at: "2026-11-13T08:00:00Z" };
  const f = fixture(t, [...original, fresh], retryStart);
  await prepare(f);
  assert.equal(f.outputs.restore_android, "false");
  assert.deepEqual(f.calls, [2, 3, 4, 5]);
  assert.equal(fs.existsSync(path.join(f.directory, "android")), false);
});

test("summary links to the republished artifacts in the latest attempt", async (t) => {
  const f = fixture(t, original, retryStart);
  await prepare(f);
  const steps = Object.fromEntries(platforms.map(({ key }, i) => [
    `restore_${key}`, { outcome: "success", outputs: { "artifact-id": String(101 + i) } },
  ]));
  await publishSummary({ ...f, steps, needs: { android_startup: { result: "success" } } });
  for (let id = 101; id <= 105; id++) assert.match(f.summaries[0], new RegExp(`artifacts/${id}\\)`));
  assert.doesNotMatch(f.summaries[0], /artifacts\/[1-5]\)/);
  assert.match(f.summaries[0], /起動・再表示テスト: \*\*成功\*\*/);
  assert.equal(f.failures.length, 0);
});

test("missing outputs fail a successful build but keep the available download links", async (t) => {
  const f = fixture(t, original.slice(1));
  await prepare(f);
  await publishSummary({ ...f, needs: { android: { result: "success" }, build: { result: "success" } } });
  assert.equal(f.failures.length, 1);
  assert.match(f.failures[0], /Android/);
  assert.match(f.summaries[0], /未作成・期限切れ/);
  assert.match(f.summaries[0], /artifacts\/2/);
});

test("skipped Android on a fork does not fail the other platform downloads", async (t) => {
  const f = fixture(t, original.slice(1));
  await prepare(f);
  await publishSummary({ ...f, needs: { android: { result: "skipped" }, build: { result: "success" } } });
  assert.equal(f.failures.length, 0);
});

test("failed artifact recovery is reported while the source link stays usable", async (t) => {
  const f = fixture(t, original, retryStart);
  await prepare(f);
  await publishSummary({ ...f, steps: {} });
  assert.equal(f.failures.length, 5);
  assert.match(f.summaries[0], /artifacts\/1/);
});

test("invalid retry metadata fails before downloading binaries", async (t) => {
  const f = fixture(t, original, "invalid");
  await assert.rejects(prepare(f), /開始時刻/);
  assert.deepEqual(f.calls, []);
});

test("summary uses direct artifact URLs and distinguishes failed startup checks", () => {
  const markdown = renderSummary({
    rows: selectArtifacts(original), serverUrl: "https://github.example.test",
    repository: "example/client", runId: 293, needs: { android_startup: { result: "failure" } },
  });
  assert.match(markdown, /https:\/\/github.example.test\/example\/client\/actions\/runs\/293\/artifacts\/1/);
  assert.match(markdown, /起動・再表示テスト: \*\*失敗\*\*/);
  assert.match(markdown, /未署名/);
});
