# Development Install Notes

ローカルビルドを `/Applications` 配下のアプリとして動かし、macOS のプライバシー権限まわりを安定させるためのメモです。実機受け入れテストは完了済みのため、このファイルではインストールとTCCリセット手順だけを残します。

## 現在のビルドをインストールする

プロジェクトルートで実行します。

```sh
Scripts/install-app.sh
```

このスクリプトは `.app` を作成し、`/Applications/MeetingAudioCapture.app` にコピーして起動します。

## macOS権限をリセットする

権限を許可しても反映されない、または何度も権限要求が出る場合は、関連するTCCエントリをリセットしてから再インストールします。

```sh
tccutil reset Microphone app.codex.meeting-audio-capture
tccutil reset ScreenCapture app.codex.meeting-audio-capture
tccutil reset Microphone app.codex.meeting-recorder
tccutil reset ScreenCapture app.codex.meeting-recorder
Scripts/install-app.sh
```

`meeting-recorder` のエントリは、MVP開発中に使っていた古いBundle IDの後片付け用に残しています。
