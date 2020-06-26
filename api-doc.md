# Rooms
The endpoint `/api/v1/rooms` can be used to retrieve information about rooms.

## Example usage : Hub sids
The following curl request
```sh
curl -s -w "\nStatus Code : %{http_code}\n" -XGET -H "Content-Type: application/json" -k "https://hubs.local:4000/api/v1/rooms?hub_sids[]=bLYUYMN&hub_sids[]=V56MWQC&hub_sids[]=EAtxxgX&hub_sids[]=foo" -o response.json
```
returns status code 207 with response:
```js
[
  {
    "status": 200,
    "body": {
      "data": {
        "hubs": [
          {
            "user_data": null,
            "turn": {
              "username": "1593137503:coturn",
              "transports": [
                {
                  "port": 5349
                }
              ],
              "enabled": true,
              "credential": "nVZLVl2wsOUvFq6AaOJxr6bSqJU="
            },
            "topics": [
              {
                "topic_id": "bLYUYMN/daring-splendid-vacation",
                "janus_room_id": 3270334349666855,
                "assets": [
                  {
                    "src": null,
                    "asset_type": "gltf_bundle"
                  }
                ]
              }
            ],
            "slug": "daring-splendid-vacation",
            "room_size": 24,
            "port": 443,
            "name": "Daring Splendid Vacation",
            "member_permissions": {
              "spawn_emoji": false,
              "spawn_drawing": false,
              "spawn_camera": false,
              "spawn_and_move_media": false,
              "pin_objects": false,
              "fly": false
            },
            "member_count": 0,
            "lobby_count": 0,
            "hub_id": "bLYUYMN",
            "host": "dev-janus.reticulum.io",
            "entry_mode": "allow",
            "entry_code": 330441,
            "description": null,
            "allow_promotion": false
          }
        ]
      }
    }
  },
  {
    "status": 200,
    "body": {
      "data": {
        "hubs": [
          {
            "user_data": null,
            "turn": {
              "username": "1593137503:coturn",
              "transports": [
                {
                  "port": 5349
                }
              ],
              "enabled": true,
              "credential": "nVZLVl2wsOUvFq6AaOJxr6bSqJU="
            },
            "topics": [
              {
                "topic_id": "V56MWQC/plump-perky-commons",
                "janus_room_id": 6087816135761554,
                "assets": [
                  {
                    "src": null,
                    "asset_type": "gltf_bundle"
                  }
                ]
              }
            ],
            "slug": "plump-perky-commons",
            "room_size": 24,
            "port": 443,
            "name": "Plump Perky Commons",
            "member_permissions": {
              "spawn_emoji": false,
              "spawn_drawing": false,
              "spawn_camera": false,
              "spawn_and_move_media": false,
              "pin_objects": false,
              "fly": false
            },
            "member_count": 0,
            "lobby_count": 0,
            "hub_id": "V56MWQC",
            "host": "dev-janus.reticulum.io",
            "entry_mode": "allow",
            "entry_code": 712351,
            "description": null,
            "allow_promotion": false
          }
        ]
      }
    }
  },
  {
    "status": 200,
    "body": {
      "data": {
        "hubs": [
          {
            "user_data": null,
            "turn": {
              "username": "1593137503:coturn",
              "transports": [
                {
                  "port": 5349
                }
              ],
              "enabled": true,
              "credential": "nVZLVl2wsOUvFq6AaOJxr6bSqJU="
            },
            "topics": [
              {
                "topic_id": "EAtxxgX/helpful-youthful-party",
                "janus_room_id": 1234653313104183,
                "assets": [
                  {
                    "src": null,
                    "asset_type": "gltf_bundle"
                  }
                ]
              }
            ],
            "slug": "helpful-youthful-party",
            "room_size": 24,
            "port": 443,
            "name": "Helpful Youthful Party",
            "member_permissions": {
              "spawn_emoji": false,
              "spawn_drawing": false,
              "spawn_camera": false,
              "spawn_and_move_media": false,
              "pin_objects": false,
              "fly": false
            },
            "member_count": 0,
            "lobby_count": 0,
            "hub_id": "EAtxxgX",
            "host": "dev-janus.reticulum.io",
            "entry_mode": "allow",
            "entry_code": 589813,
            "description": null,
            "allow_promotion": false
          }
        ]
      }
    }
  },
  {
    "status": 400,
    "body": {
      "errors": [
        {
          "source": 3,
          "detail": "Hub with sid foo does not exist.",
          "code": "RECORD_DOES_NOT_EXIST"
        }
      ]
    }
  }
]
```

## Example Usage: Creator Email
The curl request
```sh
curl -s -w "\nStatus Code : %{http_code}\n" -XGET -H "Content-Type: application/json" -k https://hubs.local:4000/api/v1/rooms?created_by_account_with_email=foo@example.com -o response.json
```
returns a 200 with response:
```js
[
  {
    "user_data": null,
    "turn": {
      "username": "1593137223:coturn",
      "transports": [
        {
          "port": 5349
        }
      ],
      "enabled": true,
      "credential": "s9nLlxjWCttHzWnk3wZ5tsEsw+o="
    },
    "topics": [
      {
        "topic_id": "T2dPBV9/opulent-exciting-convention",
        "janus_room_id": 7563951183926230,
        "assets": [
          {
            "src": null,
            "asset_type": "gltf_bundle"
          }
        ]
      }
    ],
    "slug": "opulent-exciting-convention",
    "room_size": 24,
    "port": 443,
    "name": "Opulent Exciting Convention",
    "member_permissions": {
      "spawn_emoji": true,
      "spawn_drawing": false,
      "spawn_camera": false,
      "spawn_and_move_media": false,
      "pin_objects": false,
      "fly": true
    },
    "member_count": 0,
    "lobby_count": 0,
    "hub_id": "T2dPBV9",
    "host": "dev-janus.reticulum.io",
    "entry_mode": "allow",
    "entry_code": 699031,
    "description": null,
    "allow_promotion": false
  },
  {
    "user_data": null,
    "turn": {
      "username": "1593137223:coturn",
      "transports": [
        {
          "port": 5349
        }
      ],
      "enabled": true,
      "credential": "s9nLlxjWCttHzWnk3wZ5tsEsw+o="
    },
    "topics": [
      {
        "topic_id": "ZceH2fW/prestigious-modern-exploration",
        "janus_room_id": 3173448429081564,
        "assets": [
          {
            "src": null,
            "asset_type": "gltf_bundle"
          }
        ]
      }
    ],
    "slug": "prestigious-modern-exploration",
    "room_size": 24,
    "port": 443,
    "name": "Prestigious Modern Exploration",
    "member_permissions": {
      "spawn_emoji": true,
      "spawn_drawing": false,
      "spawn_camera": false,
      "spawn_and_move_media": false,
      "pin_objects": false,
      "fly": true
    },
    "member_count": 0,
    "lobby_count": 0,
    "hub_id": "ZceH2fW",
    "host": "dev-janus.reticulum.io",
    "entry_mode": "allow",
    "entry_code": 675980,
    "description": null,
    "allow_promotion": false
  }
  //... etc
]
```
