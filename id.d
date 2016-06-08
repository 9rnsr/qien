module qien.id;

struct Id
{
private:
    static Id*[char[]] aa;

public:
    static Id* pool(const char[] s)
    {
        if (auto id = s in aa)
            return *id;
        auto id = new Id(s.idup);
        aa[id.str] = id;
        return id;
    }

private:
    string str;

public:
    string asstr()
    {
        return str;
    }
}
