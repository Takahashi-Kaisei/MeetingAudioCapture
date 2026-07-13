# MeetingAudioCapture Feature Plan

## 方針

MVPで実機録音が成功したため、次は「名前の統一」「録音中の安心感」「保存まわりの柔軟性」「録音操作の実用性」を順に強化する。

優先順位は以下の通り。

1. `S` アプリ名/package名の正式リネーム
2. `A` 録音中の経過時間表示
3. `M` ファイル名テンプレート
4. `N` 保存先設定
5. `P` 一時停止/再開
6. `G` 録音失敗時の復旧/エラー表示改善
7. `K` WAV/FLAC出力オプション
8. `R` 自動分割ファイルの結合

## S: 正式リネーム

目的:
- ディレクトリ名とGitHubリポジトリ名に合わせて、アプリ名を `MeetingAudioCapture` に統一する。
- 今後の機能追加で古い名前が増えないよう、最初に実施する。

実装方針:
- `Package.swift` の package / product / executable / target 名を `MeetingAudioCapture` 系に変更する。
- `MeetingRecorderCore` は `MeetingAudioCaptureCore` へ、`MeetingRecorderApp` は `MeetingAudioCaptureApp` へ変更する。
- `Resources/Info.plist` の `CFBundleName`, `CFBundleExecutable`, `CFBundleIdentifier` を更新する。
- `Scripts/package-app.sh` の生成先を `.build/release/MeetingAudioCapture.app` に更新する。
- README内の旧名称と起動コマンドを更新する。

検証:
- `CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift build`
- `CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift test`
- `Scripts/package-app.sh`
- `.build/release/MeetingAudioCapture.app` が生成されること。

## A: 録音中の経過時間表示

目的:
- 録音が継続していることをメニューバー上で確認できるようにする。
- 会議中に「録れているか不安」になる問題を減らす。

実装方針:
- メニューバー表示を録音中は `REC 00:12:34` のように更新する。
- メニュー内に開始時刻、経過時間、録音モードを表示する。
- `Timer` を1秒周期で動かし、`RecorderState.recording(startedAt:)` をもとに表示を更新する。
- 経過時間フォーマットはテスト可能な小さな関数に切り出す。

検証:
- 経過時間フォーマッタの単体テスト。
- 録音開始/停止でタイマーが開始/停止することを手動確認。

## M: ファイル名テンプレート

目的:
- 録音ファイルを後から見つけやすくする。
- 任意タイトルや録音モードをファイル名に反映できるようにする。

実装方針:
- デフォルト名を `MeetingAudioCapture_yyyy-MM-dd_HH-mm-ss_<mode>_part001.m4a` にする。
- メニューから「録音タイトル」を設定できるようにする。
- タイトル未設定時は日時とモードのみで保存する。
- `/`, `:`, 改行などファイル名に向かない文字は `_` に置換する。
- `RecordingSettings` に `filenameTemplate` または `sessionTitle` を追加する。
- `SegmentedAudioFileWriter` のファイル名生成を専用型に切り出す。

検証:
- ファイル名サニタイズの単体テスト。
- タイトルあり/なし、オンライン会議/対面、分割番号のテスト。

## N: 保存先設定

目的:
- `~/Downloads` 以外にも保存できるようにする。
- ユーザーの運用に合わせて保存先を固定できるようにする。

実装方針:
- 初期値は現在通り `~/Downloads`。
- メニューに「保存先を選択...」と「保存先を開く」を追加する。
- `NSOpenPanel` でディレクトリを選択する。
- 選択した保存先は `UserDefaults` に保存し、次回起動時に復元する。
- 保存先が存在しない/書き込めない場合は `~/Downloads` にフォールバックし、ユーザーに通知する。

検証:
- UserDefaultsから設定を読み書きする小さな設定ストアの単体テスト。
- 保存先変更後に録音ファイルが指定先へ生成されることを手動確認。

## P: 一時停止/再開

目的:
- 会議中の休憩や不要部分を録音ファイルに含めない。
- 停止せずに同じ録音セッションへ戻れるようにする。

実装方針:
- `RecorderState` に `paused(mode:startedAt:pausedAt:)` を追加する。
- UIに「一時停止」「再開」を追加する。
- 一時停止中は受信サンプルを破棄する。
- 再開後に長い無音が挿入されないよう、ミキサーのタイムライン基準をリセット/再同期する。
- 分割ファイルは同じ録音セッションとして継続する。

検証:
- ミキサーに pause/resume 相当のテストを追加する。
- 一時停止中の音声が出力に含まれないこと。
- 再開後に長い無音区間が入らないこと。

## G: 録音失敗時の復旧/エラー表示改善

目的:
- 失敗理由をユーザーが理解できるようにする。
- 録音失敗後もアプリを再起動せず再試行できるようにする。

実装方針:
- `RecorderError` を権限不足、マイク未検出、画面収録失敗、ファイル書き込み失敗、変換失敗に分類する。
- エラーごとにユーザー向け文言と次の行動を定義する。
- start失敗、録音中失敗、stop失敗のcleanupを明確に分ける。
- 途中まで保存済みの分割ファイルがある場合は破棄せず、保存先を案内する。
- `RecorderState.failed` から安全に `idle` に戻す導線を用意する。

検証:
- 権限不足やwriter失敗をモック/小さい単位でテストする。
- 失敗後に再度録音開始できることを手動確認する。

## K: WAV/FLAC出力オプション

目的:
- ASR向けに非圧縮または高品質な音声形式を選べるようにする。

実装方針:
- まず `M4A` と `WAV` に対応する。
- `FLAC` はmacOS/CoreAudio/AVAudioFileでの安定対応を技術検証してから追加する。
- `AudioOutputFormat` enumを追加し、拡張子と `AVAudioFile` settings を切り替える。
- 初期値はMVPと同じ `M4A`。
- 出力形式はメニューで選択し、`UserDefaults` に保存する。

検証:
- M4A/WAVそれぞれのファイル生成テスト。
- `afinfo` または `AVAudioFile` で読み返せること。
- FLACは別タスクとして対応可否を判断する。

## R: 自動分割ファイルの結合

目的:
- 長時間録音で分割されたファイルを、録音停止後に1本として扱えるようにする。

実装方針:
- 初期設定は「分割ファイルを残す」。
- メニュー設定で「停止後に結合」を有効化できるようにする。
- M4Aは `AVMutableComposition` / `AVAssetExportSession` で結合する。
- WAVはサンプル連結が必要なため、M4A結合とは別実装にする。
- 結合成功後も元の分割ファイルは削除しない。
- 結合失敗時は元ファイルを残し、エラーを表示する。

検証:
- 小さいM4Aファイルを複数生成して結合するテスト。
- 結合後ファイルが再生/読み込み可能であること。
- 元ファイルが残ること。

## 実装単位

推奨コミット単位:

1. Rename app/package to MeetingAudioCapture
2. Add recording elapsed-time display
3. Add filename templates and session titles
4. Add configurable output directory
5. Add pause and resume recording
6. Improve recorder error recovery
7. Add WAV output option
8. Add post-recording segment merge

各コミットで最低限 `swift build` と `swift test` を通す。
実録音確認が必要な変更では、Codex側の自動確認とは別にユーザー実機テストを行う。
