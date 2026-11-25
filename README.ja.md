# CodexMeter

[English](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

CodexMeter は、Codex の使用状況を確認できる非公式の macOS メニューバーアプリです。5h/7d のリング弧はリセットまでの残り時間を示します。リセット直後はほぼ一周し、リセット時刻が近づくにつれて短くなります。リング内の短い表示はリセットまでの時間、横のパーセントは残り使用量です。リングをクリックすると、詳しいカウントダウン、利用可能なリセットカード数、各カードの有効期限を確認できます。詳細パネルは簡体字中国語、日本語、英語に対応し、選択した言語はこの Mac に保存されます。

CodexMeter は独立したコミュニティプロジェクトであり、OpenAI とは関係ありません。

## 動作環境

- macOS 14 以降
- Swift 6.1 ツールチェーン（Xcode Command Line Tools または Xcode）
- Codex にサインイン済みで、`~/.codex/auth.json` が存在すること

## ビルドと起動

```zsh
./build-app.sh
open CodexMeter.app
```

使用状況は 10 秒ごと、リセットカードの詳細は 5 分ごとに更新されます。アプリはローカルの Codex アクセストークンを読み取り、以下のエンドポイントへ読み取り専用リクエストを直接送信します。認証情報を第三者サービスへ送信することはありません。

## ダウンロード用 ZIP の作成

`./package-app.sh` を実行してください。アプリをビルドしてアドホック署名し、`dist/CodexMeter-macos.zip` と対応する `dist/CodexMeter-macos.zip.sha256` を作成します。ZIP にはアプリ本体が含まれますが、`.dmg` インストーラーではなく、公証もされていません。生成された `dist/` は Git にコミットしないでください。

## 配布と初回起動

- 現在、リポジトリにはソースコードのみがあり、公開済みの GitHub Release やすぐにインストールできるファイルはありません。ローカルのパッケージスクリプトで作った ZIP は公式リリースではありません。リリース公開までは Swift ツールチェーンを用意して自分でビルドしてください。
- リリースビルドはアドホック署名のみで、Developer ID 署名も Apple の公証もありません。初回起動時に Gatekeeper にブロックされる場合があります。
- アプリと対応する `.sha256` ファイルは、このプロジェクトの公式 GitHub Releases ページからのみダウンロードしてください。第三者ミラーは使用しないでください。
- 起動前にターミナルで `shasum -a 256 -c CodexMeter-macos.zip.sha256` を実行して ZIP を検証してください。`OK` と表示された場合のみ続行してください。
- ハッシュが一致しても、配布元を信頼し、プロジェクトを確認した場合に限り、**システム設定 → プライバシーとセキュリティ → このまま開く**を選んでください。確認前にシステムの警告を読んでください。
- 会社や学校が管理する Mac では、未署名または未公証のアプリが全面的に禁止される場合があります。組織のポリシーに従い、管理者に問い合わせてください。管理制限を回避しないでください。
- このプロジェクトでは Developer ID 署名と Apple の公証を利用していません。ソースからのビルドに有料の開発者メンバーシップは不要です。
- ソフトウェアライセンスはまだ選定されていません。ソースは公開されていますが、複製、改変、再配布の許可は与えられていません。ライセンスが追加されるまでは作者の許可を得てください。

## ChatGPT の起動中だけ実行する

付属の LaunchAgent は ChatGPT デスクトッププロセスを監視し、ChatGPT の起動時に CodexMeter を起動し、終了時に CodexMeter を終了します。アプリは `/Applications/CodexMeter.app` に配置してください。

```zsh
ditto CodexMeter.app /Applications/CodexMeter.app
mkdir -p ~/Library/LaunchAgents
cp com.codexmeter.watcher.plist ~/Library/LaunchAgents/com.codexmeter.watcher.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.codexmeter.watcher.plist
```

監視を停止するには:

```zsh
launchctl bootout gui/$(id -u)/com.codexmeter.watcher
rm ~/Library/LaunchAgents/com.codexmeter.watcher.plist
```

## データと制限事項

- 使用状況: `https://chatgpt.com/backend-api/wham/usage`
- リセットカード: `https://chatgpt.com/backend-api/wham/rate-limit-reset-credits`

これらはサービス側のエンドポイントであり、安定した公開 API として文書化されていません。予告なく変更される場合があります。アプリは `~/.codex/auth.json` のトークンを読み取ります。このファイル、アクセストークン、アカウントデータをコミットしないでください。

CodexMeter は独立したコミュニティプロジェクトです。OpenAI、ChatGPT、Codex は各所有者の商標です。
