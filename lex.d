module qien.lex;

import qien.err;
import qien.file;
import qien.id;
import qien.token;

bool empty(T)(T[] a) { return a.length == 0; }
ref T front(T)(T[] a) { return a[0]; }
void popFront(T)(ref T[] a) { a = a[1 .. $]; }

public alias TOK = qien.token.TOK;
public alias Token = qien.token.Token;

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

struct Lexer
{
private:
    Loc scanLoc;
    ubyte* pLineStart;

    ubyte[] buffer;
    Token t;

public:
    this(File* f)
    {
        this.scanLoc = Loc(f.path, 1, 1);
        this.buffer = f.buffer;
        this.pLineStart = buffer.ptr;

        scan(&t);
    }

    bool empty()
    {
        return t.value == TOK.eof;
    }

    Token front()
    {
        return t;
    }

    void popFront()
    {
        scan(&t);
    }

private:
    void scan(Token* t)
    {
        while (buffer.length)
        {
            switch (buffer.front)
            {
                case 0:
                case 0x1A:
                    t.value = TOK.eof;
                    return;

                case ' ':
                case '\t':
                case '\v':
                case '\f':
                    buffer.popFront();
                    continue;

                case '\r':
                    buffer.popFront();
                    if (buffer.front != '\n')
                        reachToEOL();
                    continue;

                case '\n':
                    buffer.popFront();
                    reachToEOL();
                    continue;

                case '0':
                case '1':
                case '2':
                case '3':
                case '4':
                case '5':
                case '6':
                case '7':
                case '8':
                case '9':
                Lnumber:
                    t.value = number(t);
                    return;

                case '"':
                    t.value = escapeString();
                    return;

                case 'a':
                case 'b':
                case 'c':
                case 'd':
                case 'e':
                case 'f':
                case 'g':
                case 'h':
                case 'i':
                case 'j':
                case 'k':
                case 'l':
                case 'm':
                case 'n':
                case 'o':
                case 'p':
                case 'q':
                case 'r':
                case 's':
                case 't':
                case 'u':
                case 'v':
                case 'w':
                case 'x':
                case 'y':
                case 'z':
                case 'A':
                case 'B':
                case 'C':
                case 'D':
                case 'E':
                case 'F':
                case 'G':
                case 'H':
                case 'I':
                case 'J':
                case 'K':
                case 'L':
                case 'M':
                case 'N':
                case 'O':
                case 'P':
                case 'Q':
                case 'R':
                case 'S':
                case 'T':
                case 'U':
                case 'V':
                case 'W':
                case 'X':
                case 'Y':
                case 'Z':
                case '_':
                case_ident:
                    auto b = buffer;
                    while (1)
                    {
                        buffer.popFront();
                        const c = buffer.front;
                        if ('a' <= c && c <= 'z' || 'A' <= c && c <= 'Z')
                            continue;
                        break;
                    }
                    auto id = Id.pool((cast(char[])b)[0 .. $ - buffer.length]);
                    t.ident = id;
                    t.value = Token.checkKeyword(id);
                    return;

                case '.':
                    buffer.popFront();
                    t.value = TOK.dot;
                    return;

                case '+':
                    buffer.popFront();
                    t.value = TOK.add;
                    return;

                case '-':
                    buffer.popFront();
                    t.value = TOK.sub;
                    return;

                case '*':
                    buffer.popFront();
                    t.value = TOK.mul;
                    return;

                case '/':
                    buffer.popFront();
                    t.value = TOK.div;
                    return;

                case '%':
                    buffer.popFront();
                    t.value = TOK.mod;
                    return;

                case '&':
                    buffer.popFront();
                    if (buffer.front == '|')
                    {
                        buffer.popFront();
                        t.value = TOK.andand;
                    }
                    else
                        t.value = TOK.and;
                    return;

                case '|':
                    buffer.popFront();
                    if (buffer.front == '|')
                    {
                        buffer.popFront();
                        t.value = TOK.oror;
                    }
                    else
                        t.value = TOK.or;
                    return;

                case '=':
                    buffer.popFront();
                    if (buffer.front == '=')
                    {
                        buffer.popFront();
                        t.value = TOK.eq;
                    }
                    else if (buffer.front == '>')
                    {
                        buffer.popFront();
                        t.value = TOK.goesto;
                    }
                    else
                        t.value = TOK.assign;
                    return;

                case '!':
                    buffer.popFront();
                    if (buffer.front == '=')
                    {
                        buffer.popFront();
                        t.value = TOK.noteq;
                    }
                    else
                        t.value = TOK.not;
                    return;

                case '<':
                    buffer.popFront();
                    if (buffer.front == '=')
                    {
                        buffer.popFront();
                        t.value = TOK.le;
                    }
                    else
                        t.value = TOK.lt;
                    return;

                case '>':
                    buffer.popFront();
                    if (buffer.front == '=')
                    {
                        buffer.popFront();
                        t.value = TOK.ge;
                    }
                    else
                        t.value = TOK.gt;
                    return;

                case '~':
                    buffer.popFront();
                    t.value = TOK.tilde;
                    return;

                case '(':   buffer.popFront();   t.value = TOK.lparen;      return;
                case ')':   buffer.popFront();   t.value = TOK.rparen;      return;
                case '[':   buffer.popFront();   t.value = TOK.lbracket;    return;
                case ']':   buffer.popFront();   t.value = TOK.rbracket;    return;
                case '{':   buffer.popFront();   t.value = TOK.lcurly;      return;
                case '}':   buffer.popFront();   t.value = TOK.rcurly;      return;

                case ',':   buffer.popFront();   t.value = TOK.comma;       return;

                case ';':   buffer.popFront();   t.value = TOK.semicolon;   return;

                case ':':
                    buffer.popFront();
                    t.value = TOK.colon;
                    return;

                case '$':
                    buffer.popFront();
                    t.value = TOK.dollar;
                    return;

                case '@':
                    buffer.popFront();
                    t.value = TOK.at;
                    return;

                default:
                    dchar c = buffer.front;
                    error("character '%c' is not a valid token", c);
                    buffer.popFront();
                    continue;
            }
        }
    }

    final TOK number(Token* t)
    {
        ulong n = 0;
        bool err = false;
        bool overflow = false;

        while (1)
        {
            dchar c = buffer.front;
            int d = void;

            switch (c)
            {
                case '0':
                case '1':
                case '2':
                case '3':
                case '4':
                case '5':
                case '6':
                case '7':
                case '8':
                case '9':
                    buffer.popFront();
                    d = c - '0';
                    break;

                default:
                    goto Ldone;
            }
            // Avoid expensive overflow check if we aren't at risk of overflow
            if (n <= 0x0FFF_FFFF_FFFF_FFFFUL)
                n = n * 10 + d;
            else
            {
                import core.checkedint : mulu, addu;

                n = mulu(n, 10, overflow);
                n = addu(n, d, overflow);
            }
        }
    Ldone:
        if (overflow && !err)
        {
            error("integer overflow");
            err = true;
        }
        t.uns64value = n;
        return TOK.integer;
    }

    uint escapeSequence()
    {
        uint c = buffer.front;
        switch (c)
        {
            case '\'':
            case '"':
            case '?':
            case '\\':
            Lconsume:
                buffer.popFront();
                break;

            case 'a':   c = 7;  goto Lconsume;
            case 'b':   c = 8;  goto Lconsume;
            case 'f':   c = 12; goto Lconsume;
            case 'n':   c = 10; goto Lconsume;
            case 'r':   c = 13; goto Lconsume;
            case 't':   c = 9;  goto Lconsume;
            case 'v':   c = 11; goto Lconsume;

            // Unicode code point
            //case 'u':
            //case 'U':
            //case 'x':
            //    break;

            case 0:
            case 0x1A:
                // end of file
                c = '\\';
                break;

            default:
                error("undefined escape sequence \\%c", c);
                break;
        }
        return c;
    }

    TOK escapeString()
    {
        const startLoc = this.loc;
        assert(buffer.front == '"');
        buffer.popFront();

        char[] buf;
        while (1)
        {
            dchar c = buffer.front;
            switch (c)
            {
            case '\\':
                buffer.popFront();
            //  switch (*p)
            //  {
            //  case 'u':
            //  case 'U':
            //  case '&':
            //      c = escapeSequence();
            //      buf ~= decodeToUTF8(c);
            //      continue;
            //  default:
                    c = escapeSequence();
            //      break;
            //  }
                break;

            case '\r':
                buffer.popFront();
                if (buffer.front == '\n')
                    continue; // ignore
                // treat EOL as \n character in string literal
                c = '\n';
                reachToEOL();
                break;

            case '\n':
                buffer.popFront();
                reachToEOL();
                break;

            case '"':
                buffer.popFront();
                t.strvalue = buf.idup;
                return TOK.string;

            case 0:
            case 0x1A:
                error("unterminated string literal starting at %s", startLoc.toChars());
                t.strvalue = "";
                return TOK.string;

            default:
                buffer.popFront();
                break;
            }
            buf ~= c;
        }
        assert(0);
    }

    Loc loc()
    {
        scanLoc.cnum = 1 + cast(uint)(buffer.ptr - pLineStart);
        return scanLoc;
    }

    void reachToEOL()
    {
        scanLoc.lnum++;
        pLineStart = buffer.ptr;
    }
}
