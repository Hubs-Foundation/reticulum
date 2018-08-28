cd "$(dirname "$(realpath "$0")")";

base=https://localhost:4000

model_upload_id=$(curl -skX POST -F 'file=@avocado.glb' "$base/api/v1/uploads" | jq -r '.upload_id')
echo "model_upload_id $model_upload_id"

screenshot_upload_id=$(curl -skX POST -F 'file=@screenshot.png' "$base/api/v1/uploads" | jq -r '.upload_id')
echo "screenshot_upload_id $screenshot_upload_id"

json=$(cat <<JSON
{"scene": {
  "name": "test",
  "description": "a test scene",
  "attribution_name": "a guy",
  "attribution_link": "twitter.com/a_guy",
  "author_account_id": 123123,
  "model_upload_id": $model_upload_id,
  "screenshot_upload_id": $screenshot_upload_id
}}
JSON
)

scene_id=$(curl -skX POST -H 'content-type: application/json' "$base/api/v1/scenes" -d "$json" | jq -r '.scene_id')
echo "scene_id $scene_id"

curl -sk "$base/api/v1/scenes/$scene_id" | cut -c -100 | head -10
