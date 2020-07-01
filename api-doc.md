# JSON API

## Rooms
The endpoint `/api/v1/rooms` can be used to retrieve information about rooms.

### Headers:
- (Required) `Content-Type: application/json`
- (Required) `authorization: bearer : <TOKEN>`

### Query String Parameters:
- `created_by_account_email`
- `hub_sids[]`

### Usage : 
```sh
PATH_TOKEN="$HOME/src/shell_scripts/ret-token.txt"
PATH_CREATED_BY_EMAIL="$HOME/src/shell_scripts/personal-email.txt"
PATH_OUTPUT="$HOME/src/shell_scripts/response.json"
API="https://hubs.local:4000/api/v1/";
ENDPOINT="rooms";
CREATED_BY="created_by_account_email=$(cat $PATH_CREATED_BY_EMAIL)";
HUB_SIDS="\
&hub_sids[]=SVnhCWq\
&hub_sids[]=V56MWQC\
&hub_sids[]=blYUYMN\
";
QS="?"
QS="${QS}${CREATED_BY}&"
QS="${QS}${HUB_SIDS}&"
curl -XGET \
    -s \
    -H "Content-Type: application/json" \
    -H "authorization: bearer: $(cat "${PATH_TOKEN}")" \
    -k "${API}${ENDPOINT}${QS}" \
    -w "Response Code : %{response_code}\n" \
    -o $PATH_OUTPUT
```
