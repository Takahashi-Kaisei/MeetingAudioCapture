
開発時の受け入れテストの仕方。

1. プロジェクトルートに移動。
```
cd /MeetingAudioCapture
```

2. 起動。メニューバーに `REC` が表示されることを確認。
```
open /Applications/MeetingAudioCapture.app
```

3. 新機能開発後は以下のコマンドでビルドとAppの更新を行う。
```
Scripts/install-app.sh
```

- 権限を何回も求められるが変更できない場合、過去のキャッシュをクリアする。resetできたら3へ。
```bash
tccutil reset Microphone app.codex.meeting-audio-capture
tccutil reset ScreenCapture app.codex.meeting-audio-capture
tccutil reset Microphone app.codex.meeting-recorder
tccutil reset ScreenCapture app.codex.meeting-recorder
```
