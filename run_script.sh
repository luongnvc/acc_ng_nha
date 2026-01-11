#!/usr/bin/env bash
set -euo pipefail

# Chọn python interpreter có pycryptodome
PY_AGENT_ENV="/opt/homebrew/Caskroom/miniconda/base/envs/agent-env/bin/python"
if [ -x "$PY_AGENT_ENV" ]; then
  PYTHON_BIN="$PY_AGENT_ENV"
else
  PYTHON_BIN="python3"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENC_PY="$SCRIPT_DIR/enc.py"

# Định nghĩa các file key (chứa danh sách key)
KEY_HTML="$SCRIPT_DIR/key.html"
KEY_AHUY_HTML="$SCRIPT_DIR/keyAHuy.html"
KEY_SELL_HTML="$SCRIPT_DIR/keysell.html"
KEY_NEW_HTML="$SCRIPT_DIR/keyNew.html"

# Định nghĩa các file update (chứa thông tin version)
UPDATE_GOC_HTML="$SCRIPT_DIR/update_goc.html"
UPDATE_NEW_HTML="$SCRIPT_DIR/updateNew.html"
UPDATE_AHUY_HTML="$SCRIPT_DIR/updateAHuy.html"
UPDATE_SELL_HTML="$SCRIPT_DIR/updatesell.html"
UPDATE_PACK_HTML="$SCRIPT_DIR/update_pack.html"

if [ ! -f "$ENC_PY" ]; then
  echo "Không tìm thấy $ENC_PY" >&2
  exit 1
fi

# Hiển thị menu chọn file
echo "============================================"
echo "       CHỌN FILE CẦN CẬP NHẬT KEY"
echo "============================================"
echo "--- Các file KEY ---"
echo "1) key.html"
echo "2) keyAHuy.html"
echo "3) keysell.html"
echo "4) keyNew.html"
echo "5) Tất cả file key"
echo ""
echo "--- Các file UPDATE ---"
echo "6) update_goc.html"
echo "7) updateNew.html"
echo "8) updateAHuy.html"
echo "9) updatesell.html"
echo "10) update_pack.html"
echo "11) Tất cả file update"
echo ""
echo "12) Tất cả các file (key + update)"
echo "============================================"
read -r -p "Chọn option (1-12): " FILE_CHOICE

# Xác định file(s) cần cập nhật
declare -a TARGET_FILES
case "$FILE_CHOICE" in
  1)
    TARGET_FILES=("$KEY_HTML")
    ;;
  2)
    TARGET_FILES=("$KEY_AHUY_HTML")
    ;;
  3)
    TARGET_FILES=("$KEY_SELL_HTML")
    ;;
  4)
    TARGET_FILES=("$KEY_NEW_HTML")
    ;;
  5)
    TARGET_FILES=("$KEY_HTML" "$KEY_AHUY_HTML" "$KEY_SELL_HTML" "$KEY_NEW_HTML")
    ;;
  6)
    TARGET_FILES=("$UPDATE_GOC_HTML")
    ;;
  7)
    TARGET_FILES=("$UPDATE_NEW_HTML")
    ;;
  8)
    TARGET_FILES=("$UPDATE_AHUY_HTML")
    ;;
  9)
    TARGET_FILES=("$UPDATE_SELL_HTML")
    ;;
  10)
    TARGET_FILES=("$UPDATE_PACK_HTML")
    ;;
  11)
    TARGET_FILES=("$UPDATE_GOC_HTML" "$UPDATE_NEW_HTML" "$UPDATE_AHUY_HTML" "$UPDATE_SELL_HTML" "$UPDATE_PACK_HTML")
    ;;
  12)
    TARGET_FILES=("$KEY_HTML" "$KEY_AHUY_HTML" "$KEY_SELL_HTML" "$KEY_NEW_HTML" "$UPDATE_GOC_HTML" "$UPDATE_NEW_HTML" "$UPDATE_AHUY_HTML" "$UPDATE_SELL_HTML" "$UPDATE_PACK_HTML")
    ;;
  *)
    echo "Lựa chọn không hợp lệ!" >&2
    exit 1
    ;;
esac

# Kiểm tra các file tồn tại
for file in "${TARGET_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "Không tìm thấy $file" >&2
    exit 1
  fi
done

read -r -p "Nhập MESSAGE: " MESSAGE

# Chạy enc.py với biến môi trường MESSAGE, bắt output
ENC_OUTPUT=$(MESSAGE="$MESSAGE" "$PYTHON_BIN" "$ENC_PY")

echo "$ENC_OUTPUT"

# Trích xuất Encrypt và Decrypt từ output
# Lấy phần sau dấu ":" và trim khoảng trắng hai bên
ENCRYPT_VAL=$(printf "%s\n" "$ENC_OUTPUT" | awk -F":" '/^Encrypt:/ {sub(/^ +| +$/,"",$2); print $2; exit}')
DECRYPT_VAL=$(printf "%s\n" "$ENC_OUTPUT" | awk -F":" '/^Decrypt:/ {sub(/^ +| +$/,"",$2); print $2; exit}')

# Lấy phần bên trong { } của Decrypt
DECRYPT_CORE=$(printf "%s\n" "$DECRYPT_VAL" | sed -n 's/.*{\(.*\)}.*/\1/p')

# Bỏ tất cả khoảng trắng để đảm bảo không có khoảng trắng thừa
ENCRYPT_VAL=$(printf "%s" "$ENCRYPT_VAL" | tr -d '\t\r\n ')
DECRYPT_CORE=$(printf "%s" "$DECRYPT_CORE" | tr -d '\t\r\n ')

if [ -z "${ENCRYPT_VAL:-}" ] || [ -z "${DECRYPT_CORE:-}" ]; then
  echo "Không thể trích xuất Encrypt/DecryptCore từ output." >&2
  exit 1
fi

# Cập nhật từng file đã chọn
for TARGET_FILE in "${TARGET_FILES[@]}"; do
  "$PYTHON_BIN" - "$TARGET_FILE" "$ENCRYPT_VAL" "$DECRYPT_CORE" << 'PYAPPEND'
import json,sys,os
path=sys.argv[1]
enc=sys.argv[2]
dec=sys.argv[3]
filename = os.path.basename(path)

with open(path,'r',encoding='utf-8') as f:
    data=json.load(f)

if not isinstance(data, dict):
    print(f'File {path} không đúng cấu trúc JSON mong đợi.', file=sys.stderr)
    sys.exit(1)

# Trim an toàn trong Python trước khi ghép
enc = enc.strip()
dec = dec.strip()

# Phân biệt file key và file update
if 'key' in data and isinstance(data['key'], list):
    # File key: thêm entry vào danh sách key
    entry=f"{enc}|{dec}"
    data['key'].append(entry)
    with open(path,'w',encoding='utf-8') as f:
        json.dump(data,f,ensure_ascii=False,indent=2)
        f.write('\n')
    print(f'Đã cập nhật {filename} với key mới: {entry[:50]}...')
elif 'update' in data:
    # File update: thêm key mới vào file
    if 'key' not in data:
        data['key'] = []
    entry=f"{enc}|{dec}"
    data['key'].append(entry)
    with open(path,'w',encoding='utf-8') as f:
        json.dump(data,f,ensure_ascii=False,indent=2)
        f.write('\n')
    print(f'Đã cập nhật {filename} với key mới: {entry[:50]}...')
else:
    print(f'File {path} không đúng cấu trúc JSON mong đợi.', file=sys.stderr)
    sys.exit(1)
PYAPPEND
done

echo
echo "Bạn có muốn đẩy code lên GitHub?"
echo "1) Có"
echo "2) Không"
read -r -p "Chọn 1 hoặc 2: " CHOICE

if [ "${CHOICE}" = "1" ]; then
  git add .
  # Thực hiện commit theo yêu cầu (giữ nguyên tham số người dùng cung cấp)
  git commit -m "update-v2" --no-veri || true
  git push origin main
  echo "Đã push lên origin main."
else
  echo "Bỏ qua bước push."
fi


