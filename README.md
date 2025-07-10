# 動画ファイル安全リネームスクリプト

複数の動画・画像・音声ファイルを安全にリネームする Bash スクリプトです。EXIF データから作成日時を取得してファイル名を生成し、フォールバック機能として今日の日付+UUID を使用します。

## 特徴

- 📸 **EXIF データ優先**: 可能な限りファイルの作成日時を使用
- 🔒 **安全なリネーム**: ファイルの削除や上書きを防止
- 🎯 **柔軟な対象指定**: 拡張子またはファイル名で対象を指定
- 🔄 **重複回避**: 自動的に連番を追加して重複を防止
- 🧪 **ドライランモード**: 実行前に変更内容を確認可能
- 📊 **詳細なログ**: 処理の詳細を追跡可能

## 対応ファイル形式

### 動画ファイル

`mp4`, `mkv`, `avi`, `mov`, `wmv`, `flv`, `m4v`, `webm`, `mpg`, `mpeg`, `3gp`

### 画像ファイル

`jpg`, `jpeg`, `png`, `gif`, `bmp`, `tiff`, `webp`, `heic`, `raw`, `cr2`, `nef`

### 音声ファイル

`mp3`, `wav`, `flac`, `aac`, `m4a`, `ogg`, `wma`

## インストール

### 必要な依存関係

```bash
# Ubuntu/Debian
sudo apt-get install exiftool

# macOS
brew install exiftool

# CentOS/RHEL
sudo yum install perl-Image-ExifTool
```

### スクリプトのインストール

```bash
# スクリプトをダウンロード
curl -O https://example.com/rename.sh

# 実行権限を付与
chmod +x rename.sh

# パスの通った場所に配置（オプション）
sudo mv rename.sh /usr/local/bin/rename-media
```

## 使用方法

### 基本的な使用法

```bash
# ヘルプを表示
./rename.sh

# MP4ファイルをリネーム
./rename.sh -r -e mp4

# 複数の拡張子を指定
./rename.sh -r -e mp4 -e mkv -e avi

# 特定のファイルを指定
./rename.sh -r -f video1.mp4 -f video2.mkv

# ドライランで実行前確認
./rename.sh -n -e mp4
```

### コマンドラインオプション

#### 基本オプション

- `-r, --run`: 通常実行（実際にリネームを行う）
- `-h, --help`: ヘルプを表示
- `-v, --verbose`: 詳細なログを出力
- `-n, --dry-run`: ドライランモード（実行前確認）

#### 対象ファイル指定（必須）

- `-e, --extension EXT`: 指定した拡張子のファイルを対象
- `-f, --file FILE`: 特定のファイルを対象

### 実行例

```bash
# 動画ファイルをまとめてリネーム
./rename.sh -r -e mp4 -e mkv -e avi

# 写真ファイルをリネーム（詳細ログ付き）
./rename.sh -rv -e jpg -e png -e heic

# 特定のファイルのみリネーム
./rename.sh -r -f "重要な動画.mp4" -f "思い出の写真.jpg"

# ドライランで確認してから実行
./rename.sh -n -e mp4
./rename.sh -r -e mp4
```

## ファイル名形式

### EXIF データがある場合

```txt
YYYY-MM-DD_HHMMSS.拡張子
例: 2024-03-15_143022.mp4
```

### EXIF データがない場合

```txt
YYYY-MM-DD_UUID.拡張子
例: 2024-03-15_a1b2c3d4-e5f6-7890-abcd-ef1234567890.mp4
```

### 重複がある場合

```txt
YYYY-MM-DD_HHMMSS-N.拡張子
例: 2024-03-15_143022-1.mp4
```

## 安全機能

### ファイル保護

- ファイルの削除は絶対に行いません
- 既存ファイルの上書きを防止
- 同名ファイルがある場合は自動的に連番を追加

### 入力検証

- 危険な文字を含むファイル名を検出
- ファイル名の長さ制限（255 文字）
- 不正なファイル名パターンを拒否

### エラーハンドリング

- 処理の各段階でエラーチェック
- 中断時の安全な終了処理
- 詳細なエラーメッセージ

## トラブルシューティング

### よくある問題

#### exiftool が見つからない

```bash
# エラーメッセージ
[WARNING] exiftoolがインストールされていません。EXIFデータを読み取れません。

# 解決方法
# Ubuntu/Debian
sudo apt-get install exiftool

# macOS
brew install exiftool
```

#### 対象ファイルが見つからない

```bash
# エラーメッセージ
[WARNING] 対象ファイルが見つかりません。

# 解決方法
# 1. 現在のディレクトリを確認
ls -la *.mp4

# 2. 正しい拡張子を指定
./rename.sh -r -e MP4  # 大文字の場合

# 3. 特定のファイルを指定
./rename.sh -r -f "ファイル名.mp4"
```

#### 権限エラー

```bash
# エラーメッセージ
[ERROR] リネーム失敗: 'old.mp4' → 'new.mp4'

# 解決方法
# ファイルの権限を確認
ls -la *.mp4

# 書き込み権限を付与
chmod 644 *.mp4
```

### デバッグ方法

```bash
# 詳細ログを有効にして実行
./rename.sh -rv -e mp4

# ドライランで問題を特定
./rename.sh -nv -e mp4
```

## 高度な使用例

### バッチ処理

```bash
#!/bin/bash
# 複数のディレクトリを処理
for dir in /path/to/videos/*; do
    if [ -d "$dir" ]; then
        cd "$dir"
        /path/to/rename.sh -r -e mp4 -e mkv
    fi
done
```

### Cron で定期実行

```bash
# crontabに追加
0 2 * * * cd /path/to/videos && /path/to/rename.sh -r -e mp4 -e mkv
```

### 複数形式の一括処理

```bash
# 動画、画像、音声をまとめて処理
./rename.sh -r \
    -e mp4 -e mkv -e avi \
    -e jpg -e png -e heic \
    -e mp3 -e wav -e flac
```

## 仕様

### システム要件

- Bash 4.0 以上
- GNU coreutils
- exiftool（推奨）

### 制限事項

- 最大ファイル名長: 255 文字
- 重複回避の最大試行回数: 999 回
- UUID 生成の最大試行回数: 10 回

### パフォーマンス

- 処理速度: 約 100 ファイル/秒（EXIF なし）
- 処理速度: 約 10 ファイル/秒（EXIF 使用）
- メモリ使用量: 最小限

## ライセンス

このスクリプトは MIT ライセンスの下で公開されています。

## 貢献

バグ報告や機能追加の提案は、GitHub の Issues までお願いします。

## 更新履歴

- **v1.0**: 初回リリース
- **v1.1**: 複数拡張子対応
- **v1.2**: 特定ファイル指定機能追加
- **v1.3**: 安全性向上とエラーハンドリング強化

## 関連情報

- [ExifTool 公式サイト](https://exiftool.org/)
- [Bash Script Best Practices](https://google.github.io/styleguide/shellguide.html)
- [UUID 仕様](https://tools.ietf.org/html/rfc4122)
