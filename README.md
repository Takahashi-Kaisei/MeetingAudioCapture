# Meeting Recorder

Mac向けのメニューバー常駐型ミーティング録音アプリです。Zoom、Discord、Google Meet(Firefox)、Teamsなどのオンライン会議ではシステム音声とマイク音声を1本のM4Aへ保存します。対面モードではマイクのみを保存します。

## 対象環境

- Apple Silicon Mac
- macOS 15以降
- macOS Tahoe 26.4.1での利用を想定

## ビルド

Swiftのモジュールキャッシュをプロジェクト内に置くと、Codex環境でもビルドしやすくなります。

```sh
CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift build
```

通常のMacアプリとして起動する場合は、`.app` を生成します。

```sh
Scripts/package-app.sh
open .build/release/MeetingRecorder.app
```

## 使い方

1. メニューバーの `REC` から録音モードを選びます。
2. 必要に応じてマイクを選びます。
3. `録音開始` を選びます。
4. macOSから求められたマイク権限と画面収録権限を許可します。
5. `録音停止` を選ぶと、`~/Downloads` にM4Aが保存されます。

オンライン会議モードでは通知音やBGMも一緒に録音されます。内蔵スピーカー利用時は相手音声がマイクに回り込み、ASR品質が落ちる可能性があります。文字起こし重視ならイヤホンやヘッドセットの利用を推奨します。

## テスト

```sh
CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift test
```

Codex側ではビルド、単体テスト、M4A分割保存のテストまでを確認します。実際のZoom/Discord/Google Meet/Teamsや対面録音で相手音声と自分の声が保存されるかは、ユーザー実機で確認してください。
