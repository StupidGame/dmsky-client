const fs = require("node:fs");
const path = require("node:path");

const platforms = [
  { key: "android", name: "dmsky-client-android-release-apk", label: "Android", description: "署名済み APK（ZIPを展開してインストール）" },
  { key: "ios", name: "dmsky-client-ios-files", label: "iOS", description: "未署名 IPA（実機への導入には署名が必要）" },
  { key: "macos", name: "dmsky-client-macos", label: "macOS（Apple Silicon・Intel）", description: "macOS 12以降用 .app（アドホック署名・未公証）" },
  { key: "linux", name: "dmsky-client-linux-x64", label: "Linux x64", description: "アプリ・共有ライブラリ・データ一式" },
  { key: "windows", name: "dmsky-client-windows-x64", label: "Windows x64", description: "EXE・DLL・データ一式" },
  { key: "web", name: "dmsky-client-web", label: "Web", description: "Webサーバーへ配置するファイル一式" },
];

function positiveInteger(value, label) {
  const text = String(value ?? "");
  if (!/^[1-9][0-9]*$/.test(text)) throw new Error(`${label} must be a positive integer`);
  return text;
}

function buildIdentity(env = process.env) {
  return {
    runId: positiveInteger(env.GITHUB_RUN_ID, "GITHUB_RUN_ID"),
    runNumber: positiveInteger(env.GITHUB_RUN_NUMBER, "GITHUB_RUN_NUMBER"),
    attemptNumber: positiveInteger(env.GITHUB_RUN_ATTEMPT, "GITHUB_RUN_ATTEMPT"),
  };
}

function buildId({ runNumber, attemptNumber }) {
  const number = positiveInteger(runNumber, "runNumber");
  const attempt = positiveInteger(attemptNumber, "attemptNumber");
  return attempt === "1" ? number : `${number}-attempt-${attempt}`;
}

function artifactName(platform, identity) {
  return `${platform.name}-${buildId(identity)}`;
}

function parseArtifactName(platform, name, runNumber) {
  const match = new RegExp(`^${platform.name}-([1-9][0-9]*)(?:-attempt-([1-9][0-9]*))?(?:-reposted-attempt-([1-9][0-9]*))?$`).exec(name);
  if (!match || (runNumber !== undefined && match[1] !== String(runNumber))) return null;
  const attemptNumber = Number(match[2] || "1");
  const publishedAttemptNumber = Number(match[3] || match[2] || "1");
  if (!Number.isSafeInteger(attemptNumber) || !Number.isSafeInteger(publishedAttemptNumber) ||
      publishedAttemptNumber < attemptNumber) return null;
  return { runNumber: match[1], attemptNumber, publishedAttemptNumber };
}

function repostArtifactName(name, attemptNumber) {
  return `${name.replace(/-reposted-attempt-[0-9]+$/, "")}-reposted-attempt-${positiveInteger(attemptNumber, "attemptNumber")}`;
}

function artifactDirectory(platform) {
  if (platform.key === "web") return "build/web";
  if (platform.key === "windows") return "build/windows/x64/runner/Release";
  return "dist";
}

function prepareBuild(platform, env = process.env) {
  const identity = buildIdentity(env);
  fs.appendFileSync(env.GITHUB_ENV,
    `DMSKY_BUILD_ID=${buildId(identity)}\nDMSKY_ARTIFACT_NAME=${artifactName(platform, identity)}\nDMSKY_ARTIFACT_PATH=${artifactDirectory(platform)}\n`);
}

function writeBuildInfo(platform, env = process.env) {
  const identity = buildIdentity(env);
  const directory = artifactDirectory(platform);
  const repository = env.GITHUB_REPOSITORY;
  const runUrl = `${env.GITHUB_SERVER_URL || "https://github.com"}/${repository}/actions/runs/${identity.runId}`;
  const info = {
    schema_version: 1,
    build_id: buildId(identity),
    artifact_name: artifactName(platform, identity),
    run_id: identity.runId,
    run_number: identity.runNumber,
    run_attempt: identity.attemptNumber,
    run_url: runUrl,
    repository,
    workflow: env.GITHUB_WORKFLOW,
    commit_sha: env.GITHUB_SHA,
    source_sha: env.DMSKY_SOURCE_SHA || env.GITHUB_SHA,
    source_ref: env.GITHUB_HEAD_REF || env.GITHUB_REF,
    platform: platform.key,
    ...(platform.key === "android" ? { android_variant: env.DMSKY_ANDROID_VARIANT } : {}),
    packaged_at: new Date().toISOString(),
    files: fs.readdirSync(directory).filter((file) => file !== "BUILD_INFO.json").sort(),
  };
  fs.writeFileSync(path.join(directory, "BUILD_INFO.json"), `${JSON.stringify(info, null, 2)}\n`);
}

if (require.main === module) {
  const [command, target] = process.argv.slice(2);
  const platform = platforms.find((platform) => platform.key === target);
  if (!platform) throw new Error(`Unknown build platform: ${target}`);
  if (command === "prepare") prepareBuild(platform);
  else if (command === "metadata") writeBuildInfo(platform);
  else throw new Error(`Unknown command: ${command}`);
}

module.exports = { platforms, buildIdentity, buildId, artifactName, parseArtifactName, repostArtifactName, prepareBuild, writeBuildInfo };
