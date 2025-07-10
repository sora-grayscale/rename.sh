#!/bin/bash

# 動画ファイル安全リネームスクリプト（拡張対応版）
# EXIFデータ優先で作成日時を使用、フォールバックで今日の日付+UUID
# 複数の拡張子とファイル指定に対応

set -euo pipefail  # エラー時に即座に終了

# 今日の日付を取得 (YYYY-MM-DD形式)
readonly TODAY=$(date +"%Y-%m-%d")
readonly SCRIPT_NAME=$(basename "$0")

# 色付きメッセージ用関数
print_info() {
    echo -e "\033[32m[INFO]\033[0m $1" >&2
}

print_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1" >&2
}

print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1" >&2
}

# 使用方法表示
show_usage() {
    cat << EOF
使用方法: $SCRIPT_NAME [オプション] -e 拡張子 または -f ファイル名

このスクリプトは、指定されたファイルを安全にリネームします。
- EXIFデータがある場合: YYYY-MM-DD_HHMMSS.拡張子
- EXIFデータがない場合: YYYY-MM-DD_UUID.拡張子

基本オプション:
  -r, --run         通常実行（実際にリネームを行う）
  -h, --help        このヘルプを表示
  -v, --verbose     詳細なログを出力
  -n, --dry-run     実際のリネームを行わず、実行予定を表示

対象ファイル指定オプション（必須）:
  -e, --extension EXT        指定した拡張子のファイルを対象にする
                             複数指定可能（例：-e mp4 -e mkv -e avi）
  -f, --file FILE           特定のファイルを対象にする
                             複数指定可能（例：-f video1.mp4 -f video2.mkv）
  
  ※ 拡張子とファイル指定は併用可能
  ※ -e または -f のいずれか（または両方）の指定が必要

実行例:
  $SCRIPT_NAME                          # このヘルプを表示
  $SCRIPT_NAME -r -e mp4                # *.mp4ファイルを通常実行
  $SCRIPT_NAME -r -e mp4 -e mkv         # *.mp4と*.mkvファイルを実行
  $SCRIPT_NAME -r -e avi -e mov -e wmv  # 複数の拡張子を指定
  $SCRIPT_NAME -r -f video1.mp4         # 特定のファイルを指定
  $SCRIPT_NAME -r -f video1.mp4 -f video2.mkv  # 複数のファイルを指定
  $SCRIPT_NAME -n -e mp4 -e mkv         # ドライラン（実行前確認）
  $SCRIPT_NAME -rv -e mp4               # 通常実行+詳細ログ

サポート拡張子例:
  動画: mp4, mkv, avi, mov, wmv, flv, m4v, webm, mpg, mpeg, 3gp
  画像: jpg, jpeg, png, gif, bmp, tiff, webp, heic, raw, cr2, nef
  音声: mp3, wav, flac, aac, m4a, ogg, wma

重要：
- ファイルは絶対に削除されません
- 重複するファイル名は自動的に回避されます
- 既に正しい形式のファイルはスキップされます
- exiftoolがインストールされている場合、EXIFデータから撮影日時を取得します
- 拡張子またはファイル名の指定が必要です

EOF
}

# グローバル変数
DRY_RUN=false
VERBOSE=false
EXTENSIONS=()
TARGET_FILES=()

# コマンドライン引数解析
parse_arguments() {
    # 引数がない場合はヘルプを表示
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--run)
                # 通常実行フラグ（デフォルト動作なので何もしない）
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -e|--extension)
                if [[ $# -lt 2 ]]; then
                    print_error "-e/--extension オプションには拡張子が必要です"
                    exit 1
                fi
                # 拡張子から先頭のドットを削除
                local ext="${2#.}"
                EXTENSIONS+=("$ext")
                shift 2
                ;;
            -f|--file)
                if [[ $# -lt 2 ]]; then
                    print_error "-f/--file オプションにはファイル名が必要です"
                    exit 1
                fi
                TARGET_FILES+=("$2")
                shift 2
                ;;
            *)
                print_error "不明なオプション: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 拡張子またはファイル指定が必要
    if [ ${#EXTENSIONS[@]} -eq 0 ] && [ ${#TARGET_FILES[@]} -eq 0 ]; then
        print_error "拡張子（-e/--extension）またはファイル（-f/--file）の指定が必要です"
        show_usage
        exit 1
    fi
}

# 詳細ログ出力
verbose_log() {
    if [ "$VERBOSE" = true ]; then
        print_info "[VERBOSE] $1"
    fi
}

# UUIDを生成する関数（改良版）
generate_uuid() {
    local uuid=""
    
    # 複数の方法を試行
    if command -v uuidgen >/dev/null 2>&1; then
        uuid=$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]')
    elif command -v python3 >/dev/null 2>&1; then
        uuid=$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null)
    elif [ -f /proc/sys/kernel/random/uuid ]; then
        uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    else
        # 最後の手段：より安全なランダム生成
        if command -v openssl >/dev/null 2>&1; then
            uuid=$(openssl rand -hex 16 | sed 's/\(..\)/\1-/g' | sed 's/-$//')
        else
            uuid=$(head -c 16 /dev/urandom 2>/dev/null | xxd -p | fold -w 8 | paste -sd '-' || echo "")
        fi
    fi
    
    # UUID検証
    if [[ "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        echo "$uuid"
        return 0
    else
        return 1
    fi
}

# exiftoolの存在確認
check_exiftool() {
    if ! command -v exiftool >/dev/null 2>&1; then
        print_warning "exiftoolがインストールされていません。EXIFデータを読み取れません。"
        print_info "インストール方法:"
        print_info "  Ubuntu/Debian: sudo apt-get install exiftool"
        print_info "  macOS: brew install exiftool"
        return 1
    fi
    return 0
}

# ファイル名の安全性チェック
validate_filename() {
    local filename="$1"
    
    # 危険な文字をチェック（bash互換の書き方）
    if [[ "$filename" =~ [[:cntrl:]] ]]; then
        return 1
    fi
    
    # 個別に危険な文字をチェック
    if [[ "$filename" == *"/"* ]] || [[ "$filename" == *"\\"* ]] || \
       [[ "$filename" == *":"* ]] || [[ "$filename" == *"*"* ]] || \
       [[ "$filename" == *"?"* ]] || [[ "$filename" == *"\""* ]] || \
       [[ "$filename" == *"<"* ]] || [[ "$filename" == *">"* ]] || \
       [[ "$filename" == *"|"* ]]; then
        return 1
    fi
    
    # 長さチェック（255文字制限）
    if [ ${#filename} -gt 255 ]; then
        return 1
    fi
    
    return 0
}

# ファイルの拡張子を取得
get_file_extension() {
    local filename="$1"
    echo "${filename##*.}"
}

# EXIFから作成日時を取得してファイル名を生成（改良版）
get_filename_from_exif() {
    local file="$1"
    local extension=$(get_file_extension "$file")
    local create_date=""
    
    verbose_log "EXIFデータを読み取り中: $file"
    
    # 複数の日時フィールドを順次試行
    local date_fields=("CreateDate" "DateTimeOriginal" "MediaCreateDate" "ModifyDate")
    
    for field in "${date_fields[@]}"; do
        verbose_log "フィールド $field を確認中..."
        
        # exiftoolを安全に実行
        if create_date=$(timeout 10 exiftool -"$field" -d "%Y-%m-%d_%H%M%S" -S -s "$file" 2>/dev/null); then
            # 空でない場合
            if [ -n "$create_date" ] && [[ "$create_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}$ ]]; then
                verbose_log "日時取得成功: $create_date (フィールド: $field)"
                echo "${create_date}.${extension}"
                return 0
            fi
        fi
    done
    
    verbose_log "EXIFから有効な日時が取得できませんでした"
    return 1
}

# 重複回避のため連番を追加（改良版）
add_counter_to_filename() {
    local base_name="$1"
    local max_attempts=999
    local counter=1
    local extension=$(get_file_extension "$base_name")
    local name_without_ext="${base_name%.*}"
    
    # 元のファイル名が使用可能かチェック
    if ! check_duplicate "$base_name"; then
        echo "$base_name"
        return 0
    fi
    
    verbose_log "重複検出、連番を追加中: $base_name"
    
    # 連番を追加して重複を回避
    while [ $counter -le $max_attempts ]; do
        local new_name="${name_without_ext}-${counter}.${extension}"
        
        if ! check_duplicate "$new_name"; then
            verbose_log "重複回避成功: $new_name"
            echo "$new_name"
            return 0
        fi
        ((counter++))
    done
    
    print_error "連番による重複回避に失敗しました（最大試行回数: $max_attempts）"
    return 1
}

# ファイル名の重複チェック関数
check_duplicate() {
    local new_name="$1"
    [ -f "$new_name" ] || [ -L "$new_name" ]
}

# 安全なリネーム関数（改良版）
safe_rename() {
    local old_name="$1"
    local new_name="$2"
    
    # 入力検証
    if [ -z "$old_name" ] || [ -z "$new_name" ]; then
        print_error "リネーム: 空のファイル名が指定されました"
        return 1
    fi
    
    # ファイル名の安全性チェック
    if ! validate_filename "$new_name"; then
        print_error "リネーム: 無効なファイル名です: $new_name"
        return 1
    fi
    
    # 重複チェック
    if check_duplicate "$new_name"; then
        print_error "リネーム: 新しいファイル名 '$new_name' は既に存在します"
        return 1
    fi
    
    # 元ファイルの存在確認
    if [ ! -f "$old_name" ]; then
        print_error "リネーム: 元ファイル '$old_name' が見つかりません"
        return 1
    fi
    
    # 同じファイル名の場合はスキップ
    if [ "$old_name" = "$new_name" ]; then
        print_info "リネーム: 同じファイル名のためスキップします"
        return 0
    fi
    
    # ドライランモード
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] リネーム予定: '$old_name' → '$new_name'"
        return 0
    fi
    
    # リネーム実行
    if mv "$old_name" "$new_name" 2>/dev/null; then
        print_info "リネーム成功: '$old_name' → '$new_name'"
        return 0
    else
        print_error "リネーム失敗: '$old_name' → '$new_name'"
        return 1
    fi
}

# 既存の正しい形式かチェック（改良版）
is_correct_format() {
    local basename="$1"
    local extension=$(get_file_extension "$basename")
    local name_without_ext="${basename%.*}"
    
    # UUID形式: YYYY-MM-DD_UUID.拡張子
    if [[ "$name_without_ext" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        return 0
    fi
    
    # 日時形式: YYYY-MM-DD_HHMMSS.拡張子 または YYYY-MM-DD_HHMMSS-N.拡張子
    if [[ "$name_without_ext" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}(-[0-9]+)?$ ]]; then
        return 0
    fi
    
    return 1
}

# 対象ファイルリストを構築
build_target_files() {
    local target_files=()
    
    # 特定のファイルが指定されている場合
    if [ ${#TARGET_FILES[@]} -gt 0 ]; then
        verbose_log "指定されたファイルを追加中..."
        for file in "${TARGET_FILES[@]}"; do
            if [ -f "$file" ]; then
                target_files+=("$file")
                verbose_log "追加: $file"
            else
                print_warning "ファイルが見つかりません: $file"
            fi
        done
    fi
    
    # 拡張子が指定されている場合
    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        verbose_log "指定された拡張子のファイルを検索中..."
        shopt -s nullglob
        for ext in "${EXTENSIONS[@]}"; do
            verbose_log "拡張子 $ext のファイルを検索中..."
            for file in *."$ext"; do
                if [ -f "$file" ]; then
                    target_files+=("$file")
                    verbose_log "追加: $file"
                fi
            done
        done
        shopt -u nullglob
    fi
    
    # 何も指定されていない場合は*.mp4をデフォルト
    if [ ${#TARGET_FILES[@]} -eq 0 ] && [ ${#EXTENSIONS[@]} -eq 0 ]; then
        verbose_log "デフォルト: *.mp4ファイルを検索中..."
        shopt -s nullglob
        for file in *.mp4; do
            if [ -f "$file" ]; then
                target_files+=("$file")
                verbose_log "追加: $file"
            fi
        done
        shopt -u nullglob
    fi
    
    # 重複を削除
    local unique_files=()
    for file in "${target_files[@]}"; do
        local found=false
        for unique_file in "${unique_files[@]}"; do
            if [ "$file" = "$unique_file" ]; then
                found=true
                break
            fi
        done
        if [ "$found" = false ]; then
            unique_files+=("$file")
        fi
    done
    
    # グローバル変数に設定
    TARGET_FILES=("${unique_files[@]}")
}

# メイン処理（改良版）
main() {
    local start_time=$(date +%s)
    
    print_info "ファイルリネーム処理を開始します..."
    print_info "日付: $TODAY"
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "ドライランモード: 実際のリネームは行いません"
    fi
    
    # 対象ファイルを構築
    build_target_files
    
    # exiftoolの存在確認
    local use_exif=false
    if check_exiftool; then
        use_exif=true
        print_info "exiftoolが利用可能です。EXIFデータから作成日時を取得します。"
    else
        print_info "exiftoolが利用できません。今日の日付+UUIDを使用します。"
    fi
    
    # ファイルが見つからない場合
    if [ ${#TARGET_FILES[@]} -eq 0 ]; then
        print_warning "対象ファイルが見つかりません。"
        if [ ${#EXTENSIONS[@]} -gt 0 ]; then
            print_info "指定された拡張子: ${EXTENSIONS[*]}"
        fi
        exit 0
    fi
    
    print_info "対象ファイル数: ${#TARGET_FILES[@]}"
    
    # 指定された拡張子と特定ファイルの情報を表示
    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        print_info "指定された拡張子: ${EXTENSIONS[*]}"
    fi
    if [ ${#TARGET_FILES[@]} -gt 0 ] && [ ${#EXTENSIONS[@]} -eq 0 ]; then
        print_info "指定されたファイル: ${TARGET_FILES[*]}"
    fi
    
    # 各ファイルを処理
    local success_count=0
    local skip_count=0
    local error_count=0
    local exif_count=0
    local uuid_count=0
    
    for file in "${TARGET_FILES[@]}"; do
        verbose_log "処理中: $file"
        
        # 既に指定された形式の場合はスキップ
        if is_correct_format "$file"; then
            print_info "既に正しい形式: $file (スキップ)"
            ((skip_count++))
            continue
        fi
        
        local new_name=""
        local used_method=""
        local extension=$(get_file_extension "$file")
        
        # EXIFデータから作成日時を取得してファイル名を生成
        if [ "$use_exif" = true ]; then
            if exif_name=$(get_filename_from_exif "$file"); then
                # 重複チェックと連番追加
                if new_name=$(add_counter_to_filename "$exif_name"); then
                    used_method="EXIF"
                    ((exif_count++))
                else
                    print_error "EXIFベースのファイル名で重複回避できませんでした: $file"
                fi
            fi
        fi
        
        # EXIFが使用できない場合は今日の日付+UUIDを使用
        if [ -z "$new_name" ]; then
            verbose_log "UUIDベースのファイル名を生成中: $file"
            
            # UUIDを生成（最大10回試行）
            local max_uuid_attempts=10
            for attempt in $(seq 1 $max_uuid_attempts); do
                if uuid=$(generate_uuid); then
                    local candidate="${TODAY}_${uuid}.${extension}"
                    
                    if ! check_duplicate "$candidate"; then
                        new_name="$candidate"
                        used_method="UUID"
                        ((uuid_count++))
                        break
                    fi
                    
                    verbose_log "UUID重複、再試行中... ($attempt/$max_uuid_attempts)"
                else
                    print_error "UUID生成に失敗しました (試行 $attempt/$max_uuid_attempts)"
                fi
                
                if [ $attempt -eq $max_uuid_attempts ]; then
                    print_error "UUID生成の最大試行回数に達しました: $file"
                    ((error_count++))
                    continue 2
                fi
            done
        fi
        
        # リネーム実行
        if [ -n "$new_name" ]; then
            if safe_rename "$file" "$new_name"; then
                verbose_log "使用方法: $used_method"
                ((success_count++))
            else
                ((error_count++))
            fi
        else
            print_error "新しいファイル名を生成できませんでした: $file"
            ((error_count++))
        fi
    done
    
    # 処理時間計算
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 結果サマリー
    echo
    print_info "処理完了サマリー:"
    print_info "  成功: $success_count ファイル"
    if [ $exif_count -gt 0 ]; then
        print_info "    - EXIF使用: $exif_count ファイル"
    fi
    if [ $uuid_count -gt 0 ]; then
        print_info "    - UUID使用: $uuid_count ファイル"
    fi
    print_info "  スキップ: $skip_count ファイル"
    if [ $error_count -gt 0 ]; then
        print_warning "  エラー: $error_count ファイル"
    fi
    print_info "  処理時間: ${duration}秒"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "ドライランモードで実行されました。実際のリネームは行われていません。"
    fi
    
    print_info "すべての処理が完了しました。"
    
    # エラーがあった場合は非ゼロで終了
    if [ $error_count -gt 0 ]; then
        exit 1
    fi
}

# 割り込み処理
cleanup() {
    print_warning "処理が中断されました。"
    exit 130
}

# シグナルハンドラ設定
trap cleanup SIGINT SIGTERM

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi