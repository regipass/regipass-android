#!/usr/bin/env bash
# Firestore kurallarını ve indekslerini TEK kaynaktan (Regipass-Web) yük testi
# emülatör klasörlerine kopyalar. Bu kopyalar git'e girmez (.gitignore).
# Kullanım: tool/loadtest/kurallari-esitle.sh   (REGIPASS_WEB ile başka yol verilebilir)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WEB="${REGIPASS_WEB:-$HERE/../../../Regipass-Web}"
if [ ! -f "$WEB/firestore.rules" ]; then
  echo "Regipass-Web bulunamadı: $WEB (REGIPASS_WEB ile yol verin)" >&2
  exit 1
fi
for dir in "$HERE" "$HERE/rules-env"; do
  cp "$WEB/firestore.rules" "$dir/firestore.rules"
  cp "$WEB/firestore.indexes.json" "$dir/firestore.indexes.json"
done
echo "Kurallar eşitlendi: $WEB → tool/loadtest, tool/loadtest/rules-env"
