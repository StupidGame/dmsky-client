const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { test } = require("node:test");
const { platforms, selectArtifacts, renderSummary, prepare, publishSummary } = require("./downloads.cjs");
const { artifactName } = require("./build-artifacts.cjs");

const context = { repo: { owner: "example", repo: "client" }, runId: 293, runNumber: 42 };
const firstStart = "2026-11-13T07:36:00Z";
const retryStart = "2026-11-13T07:56:11Z";
const successfulNeeds = Object.fromEntries(platforms.map(({ key }) => [key, { result: "success" }]));
const identity = { runId: "293", runNumber: "42", attemptNumber: "1" };
const original = platforms.map((platform, i) => ({
  id: i + 1, name: artifactName(platform, identity), created_at: "2026-11-13T07:49:54Z", expired: false,
}));
const payload = Buffer.from("release binary contents\n");
const archive = execFileSync("python3", ["-c", [
  "import io,sys,zipfile", "buffer=io.BytesIO()",
  "with zipfile.ZipFile(buffer,'w') as z:",
  "    z.writestr('app.apk',sys.stdin.buffer.read())",
  "    z.writestr('BUILD_INFO.json','{\"run_attempt\":\"1\"}')",
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
    { ...original[0], id: 21, created_at: "2026-11-13T08:00:00Z" },
    { ...original[0], id: 22, created_at: "2026-11-13T08:01:00Z", expired: true },
    { ...original[0], id: 23, name: "android-startup-results" },
  ];
  assert.equal(selectArtifacts(artifacts)[0].artifact.id, 21);
  assert.equal(artifacts[0].id, 1);
  assert.equal(selectArtifacts(artifacts).length, platforms.length);
});

test("first build uses the original downloads without duplicate uploads", async (t) => {
  const f = fixture(t);
  await prepare(f);
  assert.deepEqual(f.calls, []);
  assert.ok(platforms.every(({ key }) => f.outputs[`restore_${key}`] === "false"));
  await publishSummary({ ...f, needs: successfulNeeds });
  assert.equal(f.failures.length, 0);
  assert.match(f.summaries[0], /runs\/293\/artifacts\/1/);
  assert.match(f.summaries[0], /#42 \/ ID 293 \/ attempt 1/);
});

test("job retry recovers every platform's binary byte for byte", async (t) => {
  const f = fixture(t, original, retryStart);
  await prepare(f);
  assert.deepEqual(f.calls, original.map(({ id }) => id));
  for (const { key } of platforms) {
    assert.equal(f.outputs[`restore_${key}`], "true");
    assert.deepEqual(fs.readFileSync(path.join(f.directory, key, "app.apk")), payload);
    assert.equal(JSON.parse(fs.readFileSync(path.join(f.directory, key, "BUILD_INFO.json"), "utf8")).run_attempt, "1");
  }
  assert.equal(f.outputs.artifact_name_android,
    "dmsky-client-android-release-apk-42-reposted-attempt-2");
});

test("mixed retry only recovers platforms which did not rebuild in this attempt", async (t) => {
  const fresh = { ...original[0], id: 9, name: artifactName(platforms[0], { ...identity, attemptNumber: "2" }), created_at: "2026-11-13T08:00:00Z" };
  const f = fixture(t, [...original, fresh], retryStart);
  await prepare(f);
  assert.equal(f.outputs.restore_android, "false");
  assert.deepEqual(f.calls, original.slice(1).map(({ id }) => id));
  assert.equal(fs.existsSync(path.join(f.directory, "android")), false);
});

test("summary links to the republished artifacts in the latest attempt", async (t) => {
  const f = fixture(t, original, retryStart);
  await prepare(f);
  const steps = Object.fromEntries(platforms.map(({ key }, i) => [
    `restore_${key}`, { outcome: "success", outputs: { "artifact-id": String(101 + i) } },
  ]));
  await publishSummary({ ...f, steps, needs: successfulNeeds });
  for (let id = 101; id < 101 + platforms.length; id++) assert.match(f.summaries[0], new RegExp(`artifacts/${id}\\)`));
  assert.doesNotMatch(f.summaries[0], /artifacts\/[1-6]\)/);
  assert.doesNotMatch(f.summaries[0], /起動・再表示テスト/);
  assert.equal(f.failures.length, 0);
  assert.match(f.summaries[0], /#42 \/ ID 293 \/ attempt 1/);
});

test("missing outputs fail a successful build but keep the available download links", async (t) => {
  const f = fixture(t, original.slice(1));
  await prepare(f);
  await publishSummary({ ...f, needs: successfulNeeds });
  assert.equal(f.failures.length, 1);
  assert.match(f.failures[0], /Android/);
  assert.match(f.summaries[0], /未作成・期限切れ/);
  assert.match(f.summaries[0], /artifacts\/2/);
});

test("skipped Android on a fork does not fail the other platform downloads", async (t) => {
  const f = fixture(t, original.slice(1));
  await prepare(f);
  await publishSummary({ ...f, context: {
    ...context, eventName: "pull_request",
    payload: { pull_request: { head: { repo: { full_name: "fork/client" } } } },
  }, needs: { ...successfulNeeds, android: { result: "skipped" } } });
  assert.equal(f.failures.length, 0);
});

test("failed artifact recovery is reported while the source link stays usable", async (t) => {
  const f = fixture(t, original, retryStart);
  await prepare(f);
  await publishSummary({ ...f, steps: {} });
  assert.equal(f.failures.length, platforms.length);
  assert.match(f.summaries[0], /artifacts\/1/);
});

test("invalid attempt fails before downloading binaries", async (t) => {
  const f = fixture(t);
  await assert.rejects(prepare({ ...f, attemptNumber: NaN }), /実行回数/);
  assert.deepEqual(f.calls, []);
});

test("summary uses direct artifact URLs without removed verification results", () => {
  const markdown = renderSummary({
    rows: selectArtifacts(original), serverUrl: "https://github.example.test",
    repository: "example/client", runId: 293,
  });
  assert.match(markdown, /https:\/\/github.example.test\/example\/client\/actions\/runs\/293\/artifacts\/1/);
  assert.doesNotMatch(markdown, /起動・再表示テスト|検証/);
  assert.match(markdown, /未署名/);
});

test("selects the latest build instead of a later repost and ignores other runs", () => {
  const platform = platforms[0];
  const newer = { ...original[0], id: 10, name: artifactName(platform, { ...identity, attemptNumber: "2" }), created_at: retryStart };
  const laterRepost = { ...original[0], id: 11, name: `${original[0].name}-reposted-attempt-3`, created_at: "2026-11-13T09:00:00Z" };
  const otherRun = { ...original[0], id: 12, name: artifactName(platform, { ...identity, runNumber: "999", runId: "999", attemptNumber: "9" }), created_at: "2026-11-13T10:00:00Z" };
  assert.equal(selectArtifacts([laterRepost, otherRun, newer], context.runNumber)[0].artifact.id, 10);
});

test("reposting twice keeps the original build ID without chaining repost suffixes", async (t) => {
  const f = fixture(t, original.map((artifact) => ({ ...artifact, name: `${artifact.name}-reposted-attempt-2` })), retryStart);
  await prepare({ ...f, attemptNumber: 3 });
  assert.equal(f.outputs.artifact_name_android,
    "dmsky-client-android-release-apk-42-reposted-attempt-3");
});

test("a retry restores older builds even when upload and restart timestamps are identical", async (t) => {
  const f = fixture(t, original.map((artifact) => ({ ...artifact, created_at: retryStart })), retryStart);
  await prepare(f);
  assert.deepEqual(f.calls, original.map(({ id }) => id));
});

test("each platform's download metadata identifies the actual run and source commit", (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "build-info-test-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const env = {
    GITHUB_RUN_ID: "293", GITHUB_RUN_NUMBER: "42", GITHUB_RUN_ATTEMPT: "2",
    GITHUB_ENV: path.join(directory, "github-env"), GITHUB_REPOSITORY: "example/client",
    GITHUB_WORKFLOW: "Build all platforms", GITHUB_SHA: "merge-commit", DMSKY_SOURCE_SHA: "head-commit",
    GITHUB_HEAD_REF: "feature/build-info", GITHUB_REF: "refs/pull/2/merge", DMSKY_ANDROID_VARIANT: "arm64",
  };
  const script = path.resolve(__dirname, "build-artifacts.cjs");
  for (const platform of platforms) {
    const job = path.join(directory, platform.key);
    const output = path.join(job, platform.key === "web" ? "build/web" : platform.key === "windows" ? "build/windows/x64/runner/Release" : "dist");
    fs.mkdirSync(output, { recursive: true });
    fs.writeFileSync(path.join(output, "release.zip"), payload);
    execFileSync(process.execPath, [script, "prepare", platform.key], { cwd: job, env: { ...process.env, ...env } });
    execFileSync(process.execPath, [script, "metadata", platform.key], { cwd: job, env: { ...process.env, ...env } });
    const info = JSON.parse(fs.readFileSync(path.join(output, "BUILD_INFO.json"), "utf8"));
    assert.equal(info.run_id, "293");
    assert.equal(info.run_number, "42");
    assert.equal(info.run_attempt, "2");
    assert.equal(info.platform, platform.key);
    assert.equal(info.source_sha, "head-commit");
    assert.equal(info.commit_sha, "merge-commit");
    assert.equal(info.source_ref, "feature/build-info");
    assert.deepEqual(info.files, ["release.zip"]);
    assert.match(info.artifact_name, /-42-attempt-2$/);
    assert.deepEqual(fs.readFileSync(path.join(output, "release.zip")), payload);
  }
  assert.match(fs.readFileSync(env.GITHUB_ENV, "utf8"), /DMSKY_BUILD_ID=42-attempt-2/);
});
