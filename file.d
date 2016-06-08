module qien.file;

struct File
{
    private import core.stdc.stdlib : malloc, free;

    string path;
    ubyte[] buffer;

    ~this()
    {
        if (buffer.ptr)
        {
            free(buffer.ptr);
            buffer = null;
        }
    }

    // return false if file read succeed.
    bool read()
    {
        version (Windows)
        {
            import core.sys.windows.windows;

            DWORD size;
            DWORD numread;
            auto h = CreateFileA(
                path.ptr, GENERIC_READ, FILE_SHARE_READ, null, OPEN_EXISTING,
                FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, null);
            if (h == INVALID_HANDLE_VALUE)
                return true;

            auto len = GetFileSize(h, null);
            auto buf = cast(ubyte*)malloc(len + 2);
            if (buf &&
                ReadFile(h, buf, len, &numread, null) == TRUE &&
                numread == len &&
                CloseHandle(h))
            {
                // Always store a wchar ^Z past end of buffer so scanner has a sentinel
                // ???
                buf[len] = 0; // ^Z is obsolete, use 0
                buf[len + 1] = 0;
                this.buffer = buf[0 .. len + 2];

                return false;
            }
            else
            {
                CloseHandle(h);
                free(buf);
                return true;
            }
        }
        else
            static assert(0);
    }
}
