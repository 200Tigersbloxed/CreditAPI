Json *GetData()
{
    I64 len = 0;
    U8 *buffer = FileRead("./database.json", &len);
    Json *json = JsonParse(buffer,len);
    if (!JsonOk(json)) {
        JsonPrintError(json);
        JsonRelease(json);
        return NULL;
    }
    return json;
}

Bool SaveData(Json *json)
{
    U8 *data = JsonToString(json);
    I64 len = StrLen(data);
    // Create Permissions, Read/Write, and Truncate file
    if (!FileWrite("./database.json", data, len, O_CREAT | O_RDWR | O_TRUNC)) {
        Free(data);
        return FALSE;
    }
    Free(data);
    return TRUE;
}