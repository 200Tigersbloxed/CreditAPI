#define PORT 8080
#define BUFFER_SIZE 4096
#define MAX_PARAMS 16

class CQueryParam
{
    U8 key[64];
    U8 value[128];
};

class CQueryParams
{
    CQueryParam params[MAX_PARAMS];
    I64 count;
};

class CRoute
{
    U8 *method;
    U8 *path;
    U0 (*handler)(I32, CQueryParams *);
};

CRoute *routes = NULL;
I64 num_routes = 0;
I64 routes_capacity = 0;

U0 NewRoute(U8 *method, U8 *path, U0 (*handler)(I32 sockfd, CQueryParams *qp))
{
    if (num_routes >= routes_capacity) {
        I64 new_capacity;
        if (routes_capacity) {
            new_capacity = routes_capacity * 2;
        }
        else {
            new_capacity = 8;
        }
        CRoute *new_routes = MAlloc(new_capacity * sizeof(CRoute));
        if (routes) {
            MemCpy(new_routes, routes, num_routes * sizeof(CRoute));
            Free(routes);
        }
        routes = new_routes;
        routes_capacity = new_capacity;
    }
    routes[num_routes].method = method;
    routes[num_routes].path = path;
    routes[num_routes].handler = handler;
    num_routes++;
}

U0 HandleHttp(I32 sockfd, U8 *contentType, U8 *status, U8 *body)
{
    U8 *raw = StrPrint(NULL, "%s", body);
    I64 len = StrLen(raw);
    U8 *body_len = StrPrint(NULL, "Content-Length: %d\r\n", len);
    U8 *response = StrMerge("HTTP/1.1 ", status, "\r\nContent-Type: ", contentType, "; charset=utf-8\r\n", body_len, "Connection: close\r\n\r\n", raw);
    I64 res_len = StrLen(response);
    write(sockfd, response, res_len);
    Free(raw);
    Free(body_len);
    Free(response);
    close(sockfd);
}

U0 ParseQueryString(U8 *query, CQueryParams *qp)
{
    qp->count = 0;
    if (!query) return;
    if (!*query) return;
    U8 *p = query;
    while(*p && qp->count < MAX_PARAMS) {
        U8 *keyStart = p;
        while(*p && *p != '=' && *p != '&') p++;
        I64 keyLen = p - keyStart;
        U8 *valStart = NULL;
        I64 valLen = 0;
        if(*p == '=') {
            p++;
            valStart = p;
            while(*p && *p != '&') p++;
            valLen = p - valStart;
        }
        if (keyLen > 0) {
            if (keyLen >= sizeof(qp->params[0].key)) keyLen = sizeof(qp->params[0].key) - 1;
            MemCpy(qp->params[qp->count].key, keyStart, keyLen);
            qp->params[qp->count].key[keyLen] = 0;
            if (valLen >= sizeof(qp->params[0].value)) valLen = sizeof(qp->params[0].value) - 1;
            if (valStart) {
                MemCpy(qp->params[qp->count].value, valStart, valLen);
            }
            qp->params[qp->count].value[valLen] = 0;
            qp->count++;
        }
        if (*p == '&') {
            p++;
        }
    }
}

U8 *GetQueryParam(CQueryParams *qp, U8 *key)
{
    I64 i;
    for (i = 0; i < qp->count; i++) {
        if (!StrCmp(qp->params[i].key, key)) {
            return qp->params[i].value;
        }
    }
    return NULL;
}

U0 ReadRequest(I32 sockfd)
{
    U8 reqBuf[BUFFER_SIZE];
    I64 n = read(sockfd, reqBuf, BUFFER_SIZE - 1);
    if (n <= 0) {
        close(sockfd);
        return;
    }
    reqBuf[n] = 0;
    // parse method
    I64 i = 0;
    I64 methodStart = i;
    while (reqBuf[i] && reqBuf[i] != ' ') i++;
    I64 methodLen = i - methodStart;
    U8 method[16];
    if (methodLen >= sizeof(method)) methodLen = sizeof(method) - 1;
    MemCpy(method, reqBuf + methodStart, methodLen);
    method[methodLen] = 0;
    if (reqBuf[i] == ' ') i++;
    // parse request (i.e. GET /)
    I64 pathStart = i;
    while (reqBuf[i] && reqBuf[i] != ' ' && reqBuf[i] != '\r' && reqBuf[i] != '\n') i++;
    I64 pathLen = i - pathStart;
    U8 path[256];
    if (pathLen >= sizeof(path)) pathLen = sizeof(path) - 1;
    MemCpy(path, reqBuf + pathStart, pathLen);
    path[pathLen] = 0;
    // parse query
    U8 fullPath[256];
    StrCpy(fullPath, path);
    U8 *query = NULL;
    I64 j = 0;
    while (fullPath[j] && fullPath[j] != '?') j++;
    if(fullPath[j] == '?') {
        fullPath[j] = 0;
        query = fullPath + j + 1;
    }
    CQueryParams qp;
    ParseQueryString(query, &qp);
    // get only the path (for routing)
    i = pathStart;
    while (reqBuf[i] && reqBuf[i] != ' ' && reqBuf[i] != '\r' && reqBuf[i] != '\n' &&reqBuf[i] != '?') i++;
    pathLen = i - pathStart;
    if (pathLen >= sizeof(path)) pathLen = sizeof(path) - 1;
    MemCpy(path, reqBuf + pathStart, pathLen);
    path[pathLen] = 0;

    I64 r;
    for (r = 0; r < num_routes; r++) {
        if (!StrCmp(routes[r].method, method) && !StrCmp(routes[r].path, path)) {
            U0 (*h)(I32, CQueryParams *) = routes[r].handler;
            h(sockfd, &qp);
            return;
        }
    }
    HandleHttp(sockfd, "text/html", "404 Not Found", "<!DOCTYPE html><html><body><h1>404 Not Found</h1></body></html>");
}

U0 HttpServer()
{
    I32 serverfd = NetCreateServer(PORT, NULL, 128);
    if (!serverfd) {
        "Failed to create server\n";
        return;
    }
    "HTTP server listening on port %d\n", PORT;
    while (TRUE) {
        I32 sockfd = NetAccept(serverfd);
        if (sockfd < 0) {
            "Accept error\n";
            continue;
        }
        ReadRequest(sockfd);
    }
}