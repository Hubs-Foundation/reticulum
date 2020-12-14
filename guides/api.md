# Hubs Server API
Reticulum includes a [GraphQL](https://graphql.org/) API to better allow you to write plugins or customize the app to your needs. 

## Accessing the API
The API can be accessed by sending `GET` or `POST` requests to `/api/v2_alpha/` with a valid GraphQL document in the request body. Note: This path is subject to change as we get out of early testing.

Requests can be sent by a variety of standard tools:
- an `HTTP` client library, 
- a command line tool like `curl`, 
- a GraphQL-specific client library, 
- any other tool that speaks `HTTP`. 

Reticulum ships with [GraphiQL](https://github.com/graphql/graphiql/tree/main/packages/graphiql#graphiql), a graphical interactive in-browser GraphQL IDE that makes it easy to test and learn the API. It can be accessed by navigating to `<your_hubs_cloud_endpoint>/api/v2_alpha/graphiql`. [This example workspace](../test/api/v2/graphiql-workspace-2020-10-28-15-28-39.json) demonstrates several queries and can be loaded into the GraphiQL interface. You will have to generate and supply your own API access tokens.

## Authentication and Authorization
Most requests require an API Access Token for authentication and authorization. 

### API Access Token Types
There are two types of API Access Tokens: 
- `:account` tokens act on behalf of a specific user
- `:app` tokens act on behalf of the hubs cloud itself

### Scopes
When generating API Access Tokens, you specify which `scopes` to grant that token. Scopes allow the token to be used to perform specific actions.

| Scope | API Actions |
| --:            |         --- |      
| `read_rooms` | `myRooms`, `favoriteRooms`, `publicRooms` |
| `write_rooms` | `createRoom`, `updateRoom` |

Scopes, actions, and token types are expected to expand over time.

Tokens can be generated on the command line with `mix generate_api_token`. Soon this method will be replaced with a web API and interface.

### Using API Access Tokens

To attach an API Access Token to a request, add the `HTTP` header `Authorization` with value `Bearer: <your API token>`. 


