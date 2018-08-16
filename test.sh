result=$(curl -X POST -H 'content-type: application/json' localhost:4000/api/v1/scenes -d '
{"scene": {
	"name": "test",
	"description": "a test scene",
	"attribution_name": "a guy",
	"attribution_link": "twitter.com/a_guy",
	"author_account_id": "123123",
	"upload_id": "234234"
}}')
echo "$result"
scene_id=$(echo $result | jq -r '.scene_id')
echo "$scene_id"
curl "localhost:4000/api/v1/scenes/$scene_id"
