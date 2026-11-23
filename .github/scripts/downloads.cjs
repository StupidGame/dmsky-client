const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const { platforms, parseArtifactName, repostArtifactName } = require("./build-artifacts.cjs");

function selectArtifacts(artifacts, runNumber) {
  return platforms.map((platform) => {
    const candidates = artifacts
      .filter((artifact) => !artifact.expired)
      .map((artifact) => ({ artifact, identity: parseArtifactName(platform, artifact.name, runNumber) }))
      .filter(({ identity }) => identity)
      // Reposting an old binary must not take precedence over a newer build.
      .sort((a, b) => b.identity.attemptNumber - a.identity.attemptNumber ||
        b.artifact.created_at.localeCompare(a.artifact.created_at) || b.artifact.id - a.artifact.id);
    return { ...platform, ...candidates[0] };
  });
}

function stagingDirectory() {
  return path.join(process.env.RUNNER_TEMP, "dmsky-downloads");
}

async function prepare({
  github, context, core, directory = stagingDirectory(),
  attemptNumber = Number(process.env.GITHUB_RUN_ATTEMPT || "1"),
}) {
  if (!Number.isSafeInteger(attemptNumber) || attemptNumber < 1) {
    throw new Error("実行回数を取得できませんでした");
  }
  const artifacts = await github.paginate(github.rest.actions.listWorkflowRunArtifacts, {
    ...context.repo, run_id: context.runId, per_page: 100,
  });
  fs.mkdirSync(directory, { recursive: true });
  const rows = selectArtifacts(artifacts, context.runNumber);
  for (const row of rows) {
    // Artifacts from an earlier attempt are hidden by the default Actions view.
    row.restore = !!row.artifact && row.identity.publishedAttemptNumber < attemptNumber;
    row.restoreName = row.restore ? repostArtifactName(row.artifact.name, attemptNumber) : null;
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
    core.setOutput(`artifact_name_${row.key}`, row.restoreName || "");
  }
  fs.writeFileSync(path.join(directory, "manifest.json"), JSON.stringify(rows));
}

function renderSummary({ rows, serverUrl, repository, runId }) {
  const runUrl = `${serverUrl}/${repository}/actions/runs/${runId}`;
  const lines = [
    "## ダウンロード", "",
    "GitHubにログインしてリンクを開いてください。AndroidはZIPを展開してAPKをインストールできます。", "",
    "ZIP名・パッケージ名の末尾はActionsの実行番号です。再ビルド時は実行回数も付きます。同梱の `BUILD_INFO.json` に詳細な実行ID・実行URL・コミットを記録しています。", "",
    "| 環境 | ダウンロード | ビルド | 内容 |", "| --- | --- | --- | --- |",
  ];
  for (const row of rows) {
    const link = row.artifact
      ? `[ダウンロード（ZIP）](${runUrl}/artifacts/${row.artifact.id})`
      : "未作成・期限切れ";
    const identity = row.identity;
    const build = identity ? `#${identity.runNumber} / ID ${runId} / attempt ${identity.attemptNumber}` : "—";
    lines.push(`| ${row.label} | ${link} | ${build} | ${row.description} |`);
  }
  lines.push("",
    `iOSの実機インストールにはAppleの署名が必要です。macOS版はDeveloper ID署名・公証を行っていません。成果物の保存期間は${process.env.DMSKY_RETENTION_DAYS || "14"}日です。`, "");
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
      row.artifact.name = row.restoreName;
    } else {
      core.setFailed(`${row.label} の成果物を最新画面に再掲できませんでした`);
    }
  }
  const missing = rows.filter((row) => !row.artifact && needs[row.key]?.result === "success");
  if (missing.length) {
    core.setFailed(`ビルド成功後の成果物がありません: ${missing.map((row) => row.label).join(", ")}`);
  }
  await core.summary.addRaw(renderSummary({
    rows, serverUrl: process.env.GITHUB_SERVER_URL || "https://github.com",
    repository: `${context.repo.owner}/${context.repo.repo}`, runId: context.runId,
  })).write();
}

module.exports = { platforms, selectArtifacts, renderSummary, prepare, publishSummary };
