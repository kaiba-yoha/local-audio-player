# Local Audio Player — Design Document

## Product Intent

- **Audience**: iPhoneユーザーで、端末内の音声ファイル（ポッドキャスト、語学教材、オーディオブック等）をシンプルに再生したい人
- **Core job**: ローカル音声ファイルをプレイリスト形式で再生・管理する
- **First-screen promise**: ファイルを選ぶだけですぐ再生開始
- **Primary workflow**: ファイル選択 → プレイリスト表示 → 再生 → スピード/ループ/タイマー調整

## Brand Idea

ダークを基調とした落ち着いたオーディオプレイヤー。Indigo (#6366F1) をアクセントに、ミニマルで直感的。

## Design Principles

1. **即座に使える** — チュートリアルやアカウント不要。開いてファイルを選ぶだけ
2. **ローカル完結** — サーバー通信なし。プライバシー安全
3. **最小限のUI** — 再生に必要な操作だけを表示
4. **iOS標準を活用** — Document Picker, Now Playing, Background Audio など OS機能をフル活用

## Color Tokens

| Token | Light | Dark |
|-------|-------|------|
| background | #F5F5FA | #0F0F1A |
| card | #FFFFFF | #1A1A2E |
| accent | #6366F1 | #6366F1 |
| accentGradEnd | #A78BFA | #A78BFA |
| textPrimary | #1A1A2E | #E8E8F0 |
| textSecondary | #666666 | #AAAAAA |
| textTertiary | #999999 | #555555 |
| controlBg | #E8E8F0 | #2A2A40 |
| destructive | #F87171 | #F87171 |

Dark mode がデフォルト。Light mode は将来対応。

## Typography

- System font (SF Pro) — Dynamic Type対応
- Title: 18pt bold
- Track name: 13pt regular
- Time display: 12pt tabular-nums
- Labels: 11pt

## Shape / Layout / Density

- Card radius: 20pt
- Button radius: pill (50%)
- Track row: 10pt padding, 12pt horizontal
- Play button: 60×60pt circle
- Playlist max height: 220pt scrollable
- Tap targets: minimum 44×44pt

## Components

### FilePickerArea
- タップで UIDocumentPickerViewController を表示
- 対応形式: mp3, m4a, wav, aac, flac, caf

### PlaylistView
- トラック一覧 (番号, 名前, 時間, 削除ボタン)
- ドラッグで並べ替え
- アクティブトラックにインジケータドット表示

### PlayerControls
- Now Playing タイトル
- プログレスバー (シーク対応)
- 現在時間 / 総時間
- 前曲 | -15秒 | 再生/一時停止 | +15秒 | 次曲

### OptionsRow
- Loop (1曲) / Loop All ボタン
- Speed: 0.75x, 1x, 1.25x, 1.5x, 2x
- Sleep Timer: 15分, 30分, 60分, OFF

## Accessibility

- VoiceOver labels on all controls
- Dynamic Type support
- Minimum 44pt touch targets
- High contrast accent color

## Implementation Mapping

- `project.yml` — XcodeGen config
- `LocalAudioPlayer/` — Swift source
- `LocalAudioPlayer/Assets.xcassets/` — Asset catalog
- `docs/design.md` — This file

## Verification Notes

- (pending) Initial build verification
