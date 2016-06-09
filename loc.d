module qien.loc;

struct Loc
{
    string file;
    uint lnum;
    uint cnum;

    const(char)* toChars() const
    {
        import std.array : appender;
        import std.format;

        auto w = appender!string;
        if (file)
            w.put(file);
        if (lnum)
            formattedWrite(w, "(%s,%s)", lnum, cnum);
        return w.data.ptr;
    }
}
