const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const platforms = [
  { key: "android", name: "dmsky-client-android", label: "Android", description: "署名済み APK（ZIPを展開してインストール）" },
  { key: "ios", name: "dmsky-client-ios-unsigned", label: "iOS", description: "未署名の Runner.app" },
  { key: "linux", name: "dmsky-client-linux-x64", label: "Linux x64", description: "アプリ・共有ライブラリ・データ一式" },
  { key: "windows", name: "dmsky-client-windows-x64", label: "Windows x64", description: "EXE・DLL・データ一式" },
  { key: "web", name: "dmsky-client-web", label: "Web", description: "Webサーバーへ配置するファイル一式" },
];

function selectArtifacts(artifacts) {
  return platforms.map((platform) => ({
    ...platform,
    artifact: artifacts
      .filter((artifact) => artifact.name === platform.name && !artifact.expired)
      .sort((a, b) => b.created_at.localeCompare(a.created_at) || b.id - a.id)[0],
  }));
}

function stagingDirectory() {
  return path.join(process.env.RUNNER_TEMP, "dmsky-downloads");
}

async function prepare({
  github, context, core, directory = stagingDirectory(),
  attemptNumber = Number(process.env.GITHUB_RUN_ATTEMPT || "1"),
}) {
  const artifacts = await github.paginate(github.rest.actions.listWorkflowRunArtifacts, {
    ...context.repo, run_id: context.runId, per_page: 100,
  });
  const { data: attempt } = await github.rest.actions.getWorkflowRunAttempt({
    ...context.repo, run_id: context.runId,
    attempt_number: attemptNumber,
  });
  const started = Date.parse(attempt.run_started_at);
  if (!Number.isFinite(started)) throw new Error("再実行の開始時刻を取得できませんでした");

  fs.mkdirSync(directory, { recursive: true });
  const rows = selectArtifacts(artifacts);
  for (const row of rows) {
    // Artifacts from an earlier attempt are hidden by the default Actions view.
    row.restore = !!row.artifact && Date.parse(row.artifact.created_at) < started;
    if (row.restore) {
      const download = await github.rest.actions.downloadArtifact({
        ...context.repo, artifact_id: row.artifact.id, archive_format: "zip",
      });
      const archive = path.join(directory, `${row.key}.zip`);
      fs.writeFileSync(archive, Buffer.from(download.data));
      execFileSync("python3", ["-m", "zipfile", "-e", archive, path.join(directory, row.key)]);
      fs.unlinkSync(archive);
    }
    core.setOutput(`restore_${row.key}`, String(row.restore));
  }
  fs.writeFileSync(path.join(directory, "manifest.json"), JSON.stringify(rows));
}

function renderSummary({ rows, serverUrl, repository, runId, needs }) {
  const runUrl = `${serverUrl}/${repository}/actions/runs/${runId}`;
  const status = { success: "成功", failure: "失敗", skipped: "未実施", cancelled: "中止" };
  const startup = status[needs.android_startup?.result] ?? "未実施";
  const lines = [
    "## ダウンロード", "",
    "GitHubにログインしてリンクを開いてください。AndroidはZIPを展開してAPKをインストールできます。", "",
    "| 環境 | ダウンロード | 内容 |", "| --- | --- | --- |",
  ];
  for (const row of rows) {
    const link = row.artifact
      ? `[ダウンロード（ZIP）](${runUrl}/artifacts/${row.artifact.id})`
      : "未作成・期限切れ";
    lines.push(`| ${row.label} | ${link} | ${row.description} |`);
  }
  lines.push("", `Androidの起動・再表示テスト: **${startup}**。`, "",
    "iOSの実機インストールにはAppleの署名が必要です。成果物の保存期間は30日です。", "");
  return lines.join("\n");
}

async function publishSummary({
  context, core, directory = stagingDirectory(),
  steps = JSON.parse(process.env.DMSKY_DOWNLOAD_STEPS || "{}"),
  needs = JSON.parse(process.env.DMSKY_DOWNLOAD_NEEDS || "{}"),
}) {
  const rows = JSON.parse(fs.readFileSync(path.join(directory, "manifest.json"), "utf8"));
  for (const row of rows) {
    if (!row.restore) continue;
    const upload = steps[`restore_${row.key}`];
    const id = Number(upload?.outputs?.["artifact-id"]);
    if (upload?.outcome === "success" && Number.isSafeInteger(id) && id > 0) {
      row.artifact.id = id;
    } else {
      core.setFailed(`${row.label} の成果物を最新画面に再掲できませんでした`);
    }
  }
  const missing = rows.filter((row) => !row.artifact &&
    (row.key === "android" ? needs.android?.result === "success" : needs.build?.result === "success"));
  if (missing.length) {
    core.setFailed(`ビルド成功後の成果物がありません: ${missing.map((row) => row.label).join(", ")}`);
  }
  await core.summary.addRaw(renderSummary({
    rows, needs, serverUrl: process.env.GITHUB_SERVER_URL || "https://github.com",
    repository: `${context.repo.owner}/${context.repo.repo}`, runId: context.runId,
  })).write();
}

module.exports = { platforms, selectArtifacts, renderSummary, prepare, publishSummary };
