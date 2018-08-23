base=https://localhost:4000

curl -k -X POST -F 'file=@avocado.glb' "$base/api/v1/uploads"

# model_upload_id=$(curl -k -X POST -F 'file=@avocado.gltf' "$base/api/v1/uploads")

# screenshot_upload_id=$(curl -k -X POST -F 'file=@screenshot.png' "$base/api/v1/uploads")
# 
# result=$(
#   curl -k -X POST -H 'content-type: application/json' "$base/api/v1/scenes" -d "$(
# <<JSON
#     {"scene": {
#       "name": "test",
#       "description": "a test scene",
#       "attribution_name": "a guy",
#       "attribution_link": "twitter.com/a_guy",
#       "author_account_id": "123123",
#       "model_upload_id": $model_upload_id
#       "screenshot_upload_id": $screenshot_upload_id
#     }}
# JSON
#   )"
# )
# echo "$result"
# 
# scene_id=$(echo "result" | jq -r '.scene_id')
# echo "$scene_id"
# 
# curl -k "https://localhost:4000/api/v1/scenes/$scene_id"
