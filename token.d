module qien.token;

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
}

struct Token
{
    TOK value;

    Id* ident;

    // unsigned 64 bit integer type
    ulong uns64value;

    string strvalue;

    string asstr()
    {
        final switch (value)
        {
            case TOK.reserved:      return "<reserved>";

            case TOK.eof:           return "<eof>";
            case TOK.eol:           return "<eol>";

            case TOK.integer:       return "<integer>";
            case TOK.identifier:    return "<identifier>";
            case TOK.string:        return "<string>";

            case TOK.dot:           return ".";

            case TOK.add:           return "+";
            case TOK.sub:           return "-";
            case TOK.mul:           return "*";
            case TOK.div:           return "/";
            case TOK.mod:           return "%";

            case TOK.not:           return "!";
            case TOK.andand:        return "&&";
            case TOK.and:           return "&";
            case TOK.oror:          return "||";
            case TOK.or:            return "|";

            case TOK.eq:            return "==";
            case TOK.noteq:         return "!=";
            case TOK.le:            return "<=";
            case TOK.lt:            return "<";
            case TOK.ge:            return ">=";
            case TOK.gt:            return ">";

            case TOK.goesto:        return "=>";
            case TOK.assign:        return "=";

            case TOK.lparen:        return "(";
            case TOK.rparen:        return ")";
            case TOK.lbracket:      return "[";
            case TOK.rbracket:      return "]";
            case TOK.lcurly:        return "{";
            case TOK.rcurly:        return "}";

            case TOK.tilde:         return "~";
            case TOK.comma:         return ",";
            case TOK.colon:         return ":";
            case TOK.semicolon:     return ";";
            case TOK.dollar:        return "$";
            case TOK.at:            return "@";
        }
    }
}
