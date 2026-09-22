# CreditAPI

A simple API written in HolyC to track users and their credit scores.

## HTTP API

`GET /users/get?name=string`

Gets the current value for the supplied user

Example response

```json
{"message": "Got information!", "value": 0}
```

`GET /users/set?name=string&value=int`

Sets the current value for the supplied user

Example response

```json
{"message": "Updated!"}
```

## Setting up

Create a `database.json` file and populate the users you want to track.

```json
{"joe": 0, "jeff": 0, "may": 0}
```

## Building

```bash
hcc main.HC
```
