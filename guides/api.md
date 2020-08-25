# Overview
Reticulum includes a [GraphQL](https://graphql.org/) API to better allow you to customize the app to your specific needs. 

## Accessing the API
The API can be accessed by sending `GET` or `POST` requests to `/api/v2/`.
Requests can be sent in code with an `HTTP` client library, on the command line with a tool like `curl`, with a GraphQL-specific client library, or any other tool that speaks `HTTP`. There is also an interactive GUI for accessing the API available at `/api/v2/graphiql`. 

## Authenticating requests
Most requests sent to the API need to be authenticated. To authenticate a request, add the http header `Authorization` with value `Bearer: <your API token>`. Currently, your API token is the same as your account token, which you can find with the following steps:
- Navigate to the homepage
- Sign in
- Open the developer console of your browser. (
Instructions for opening the console in firefox: https://developer.mozilla.org/en-US/docs/Tools/Web_Console#Opening_the_Web_Console
Instructions for chrome: https://developers.google.com/web/tools/chrome-devtools/open)
- Type `window.APP.store.state.credentials.token` into the console and press enter.
- Your token should be returned surrounded by quotations marks (`"<your API token here>"`)

It is likely that the authentication method will change in future releases of the API to include something like API tokens whose permissions can be limited to specific scopes, so that people are not encouraged to share admin account tokens. Sharing account tokens is dangerous - don't do it.

## Passing arguments
We use a library called [`absinthe`](http://absinthe-graphql.org/) to power the `GraphQL` API. This library automatically converts between `camelCase` (a typical convention in `javascript`) and `snake_case` (a typical convention in `elixir`). For this reason, you will send and receive arguments and values in `camelCase`, but will see the corresponding values in `elixir` code as `snake_case`.

## Rooms
The following examples show the capabilities of creating, querying, and modifying rooms. The code for these commands and object types can be found in [`/lib/ret_web/schema/room_types.ex`](../lib/ret_web/schema/room_types.ex)

### Create a room
Request:
```
mutation {
  createRoom(name:"My Fun Get-Together"){
    id
  }
}
```
Response:
```js
{
  "data": {
    "createRoom": {
      "id": "3FqxixG"
    }
  }
}
```

### Querying Rooms
Room queries return a `RoomList` object, which paginates responses. For a specific page or page size, pass the `page` or `pageSize` arguments along with  the request. 

#### My rooms
Request:
```
query {
  myRooms(page: 1, pageSize: 10) {
    entries {
      name,
      id,
      scene {
        ... on Scene {
          id,
          name
        }
        ... on SceneListing{
          id,
          name
        }
      }
    }
  }
}
```
Response:
```js
{
  "data": {
    "myRooms": {
      "entries": [
        {
          "id": "3FqxixG",
          "name": "My Fun Get-Together",
          "scene": null
        },
        {
          "id": "FmNKVjL",
          "name": "Foo",
          "scene": {
            "id": "tXkCgJw",
            "name": "Crater 2"
          }
        },
        "scene": {
          "id": "74VD2Et",
          "name": "Crater"
        }
      ]
    }
  }
}
```

#### Query my favorite rooms
Request:
```
query {
  myFavorites {
    entries {
      name,
      id
    }
  }
}
```
Response:
```js
{
  "data": {
    "favoriteRooms": {
      "entries": [
        {
          "id": "4jByd2w",
          "name": "Uniform Ready Social"
        },
        {
          "id": "5wQhhbG",
          "name": "Angelic Vibrant Spot"
        },
        {
          "id": "RmNv2k2",
          "name": "Golden Perfect Volume"
        },
      ]
    }
  }
}
```


#### Query public rooms
Request:
```
query {
  publicRooms {
    entries {
      name,
      id
    }
  }
}
```
Response:
```js
{
  "data": {
    "publicRooms": {
      "entries": [
        {
          "id": "z7LQiNi",
          "name": "Big Time Room"
        },
        {
          "id": "SVnhCWq",
          "name": "sdafasdf"
        }
      ]
    }
  }
}
```

### Updating rooms
#### Set room properties like `name`, `description`, and `roomSize`
```
mutation {
  updateRoom(
    id:"FmNKVjL", 
    name:"Foo bar baz", 
    description:"Some description", 
    roomSize:15,
  ) {
    id
  }
}
```
#### Change the scene of a given room:
```
mutation {
  updateRoom(
    id:"FmNKVjL", 
    sceneId: "74VD2Et",
  ) {
    id
  }
}
```

#### Change member permissions in the room:
```
mutation {
  updateRoom(
    id:"FmNKVjL", 
    memberPermissions: {
      fly: true,
      spawnEmoji: true,
      spawnDrawing: true,
      pinObjects: false,
      spawnCamera: false,
      spawnAndMoveMedia: true
    }
  ) {
    id
  }
}
```
### Change everything all in one go:

```
mutation {
  updateRoom(
    id:"FmNKVjL", 
    name:"Foo bar baz", 
    description:"Some description", 
    roomSize:15,
    sceneId: "74VD2Et",
    memberPermissions: {
      fly: true,
      spawnEmoji: true,
      spawnDrawing: true,
      pinObjects: false,
      spawnCamera: false,
      spawnAndMoveMedia: true
    }
  ) {
    id
  }
}
```


