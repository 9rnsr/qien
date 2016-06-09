module qien.token;

import qien.loc;
import qien.id;

enum TOK
{
    reserved,

    eof,
    eol,

    integer,
    identifier,
    string,

    dot,

    add,
    sub,
    mul,
    div,
    mod,

    not,
    andand,
    and,
    oror,
    or,

    eq,
    noteq,
    le,
    lt,
    ge,
    gt,

    goesto,
    assign,

    lparen,
    rparen,
    lbracket,
    rbracket,
    lcurly,
    rcurly,

    tilde,
    comma,
    colon,
    semicolon,
    dollar,
    at,

    // keywords
    def,
}

struct Token
{
    TOK value;
    Loc loc;

    Id* ident;

    // unsigned 64 bit integer type
    ulong uns64value;

    string strvalue;

    string asstr()
    {
        foreach (s, t; map)
        {
            if (t == value)
                return s;
        }
        assert(0);
    }

    static TOK checkKeyword(Id* id)
    {
        if (auto e = id.asstr in map)
            return *e;
        else
            return TOK.identifier;
    }

private:
    static immutable TOK[string] map;

    static this()
    {
        map =
        [
            "<reserved>"    : TOK.reserved,

            "<eof>"         : TOK.eof,
            "<eol>"         : TOK.eol,

            "<integer>"     : TOK.integer,
            "<identifier>"  : TOK.identifier,
            "<string>"      : TOK.string,

            "."             : TOK.dot,

            "+"             : TOK.add,
            "-"             : TOK.sub,
            "*"             : TOK.mul,
            "/"             : TOK.div,
            "%"             : TOK.mod,

            "!"             : TOK.not,
            "&&"            : TOK.andand,
            "&"             : TOK.and,
            "||"            : TOK.oror,
            "|"             : TOK.or,

            "=="            : TOK.eq,
            "!="            : TOK.noteq,
            "<="            : TOK.le,
            "<"             : TOK.lt,
            ">="            : TOK.ge,
            ">"             : TOK.gt,

            "=>"            : TOK.goesto,
            "="             : TOK.assign,

            "("             : TOK.lparen,
            ")"             : TOK.rparen,
            "["             : TOK.lbracket,
            "]"             : TOK.rbracket,
            "{"             : TOK.lcurly,
            "}"             : TOK.rcurly,

            "~"             : TOK.tilde,
            ","             : TOK.comma,
            ":"             : TOK.colon,
            ";"             : TOK.semicolon,
            "$"             : TOK.dollar,
            "@"             : TOK.at,

            "def"           : TOK.def,
        ];
    }
}
