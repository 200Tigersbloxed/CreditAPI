#include "./database.HC"
#include "./http.HC"

Json *json = NULL;

U0 HandleUserGet(I32 sockfd, CQueryParams *qp)
{
    U8 *name = GetQueryParam(qp, "name");
    if(!name) {
        HandleHttp(sockfd, "application/json", "400 Bad Request", "{\"error\": \"Invalid name\"}");
        return;
    }
    U8 *js_str = StrMerge(".", name, ":i");
    Json *js = JsonSelect(json, js_str);
    if (!js) {
        HandleHttp(sockfd, "application/json", "404 Not Found", "{\"error\": \"Unknown name\"}");
        Free(js_str);
        return;
    }
    Free(js_str);
    U8 *res = StrPrint(NULL, "{\"message\": \"Got information!\", \"value\": %d}", js->i64);
    HandleHttp(sockfd, "application/json", "200 OK", res);
    Free(res);
}

U0 HandleUserSet(I32 sockfd, CQueryParams *qp)
{
    U8 *name = GetQueryParam(qp, "name");
    if(!name) {
        HandleHttp(sockfd, "application/json", "400 Bad Request", "{\"error\": \"Invalid name\"}");
        return;
    }
    U8 *value_str = GetQueryParam(qp, "value");
    if(!value_str) {
        HandleHttp(sockfd, "application/json", "400 Bad Request", "{\"error\": \"Invalid value\"}");
        return;
    }
    I64 value = strtoll(value_str, NULL, 10);
    U8 *js_str = StrMerge(".", name, ":i");
    Json *js = JsonSelect(json, js_str);
    if (!js) {
        HandleHttp(sockfd, "application/json", "404 Not Found", "{\"error\": \"Unknown name\"}");
        Free(js_str);
        return;
    }
    js->type = JSON_INT;
    js->i64 = value;
    SaveData(json);
    Free(js_str);
    HandleHttp(sockfd, "application/json", "200 OK", "{\"message\": \"Updated!\"}");
}

U0 Main()
{
    "%s\n", "Loading Data";
    json = GetData();
    if (!json) {
        "%s\n", "Failed to load data!";
        return;
    }
    NewRoute("GET", "/user/get", &HandleUserGet);
    NewRoute("GET", "/user/set", &HandleUserSet);
    HttpServer;
    JsonRelease(json);
}