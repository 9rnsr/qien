module qien.parse;

import core.stdc.stdio;
import qien.decl;
import qien.err;
import qien.expr;
import qien.file;
import qien.id;
import qien.lex;
import qien.stmt;
import qien.token;

struct Parser
{
    Lexer lexer;

    this(File* f)
    {
        this.lexer = Lexer(f);
    }

    void enforce(TOK tok)
    {
        auto t = lexer.front;
        if (t.value == tok)
            lexer.popFront();
        else
            error("unexpected token: %.*s", t.asstr.ptr, t.asstr.length);
    }

    Module parseModule()
    {
        Decl[] members;
        while (!lexer.empty)
        {
            auto d = parseDecl();
            members ~= d;
        }
        auto m = new Module(members);
        return m;
    }

    Decl parseDecl()
    {
        auto t = lexer.front;

        switch (t.value)
        {
            case TOK.def:
                //auto loc;
                lexer.popFront();
                Id* ident;
                if (lexer.front.value == TOK.identifier)
                {
                    ident = lexer.front.ident;
                    lexer.popFront();
                }
                else
                    enforce(TOK.identifier);

                auto fparams = parseParameters();

                auto sbody = parseBlock();

                auto d = new FuncDecl(Loc(), Loc(), ident, fparams, sbody);
                return d;

            default:
                /*t.*/error("unexpected token: %.*s", t.asstr.length, t.asstr.ptr);
                lexer.popFront();
                return null;
        }
    }

    VarDecl[] parseParameters()
    {
        enforce(TOK.lparen);
        //for ()
        //    parseDecl
        enforce(TOK.rparen);
        return null;
    }

    Stmt parseBlock()
    {
        Stmt[] statements;

        enforce(TOK.lcurly);
        while (lexer.front.value != TOK.rcurly)
        {
            auto s = parseStmt();
            statements ~= s;
        }
        enforce(TOK.rcurly);

        return new CompoundStmt(Loc(), statements);
    }

    Stmt parseStmt()
    {
        auto e = parseExpr();
        enforce(TOK.semicolon);
        return new ExprStmt(Loc(), e);
    }

    Expr parseExpr()
    {
        if (lexer.front.value == TOK.lparen)
        {
            lexer.popFront();
            auto e = parseExpr();
            enforce(TOK.rparen);
            return e;
        }
        auto e = parsePostExpr();
        return e;
    }

    Expr parsePostExpr()
    {
        auto e = parsePrimaryExpr();
        if (lexer.front.value == TOK.lparen)
        {
            lexer.popFront();

            Expr[] arguments;
            while (lexer.front.value != TOK.rparen)
            {
                auto earg = parseExpr();
                arguments ~= earg;

                if (lexer.front.value == TOK.comma)
                {
                    lexer.popFront();
                    if (lexer.front.value != TOK.rparen)
                        continue;
                }
                if (lexer.front.value == TOK.rparen)
                {
                    lexer.popFront();
                    break;
                }
                enforce(TOK.comma);
                break;
            }

            e = new CallExpr(Loc(), e, arguments);
        }
        return e;
    }

    Expr parsePrimaryExpr()
    {
        if (lexer.front.value == TOK.identifier)
        {
            auto id = lexer.front.ident;
            lexer.popFront();

            auto e = new IdentifierExp(Loc(), id);
            return e;
        }
        if (lexer.front.value == TOK.string)
        {
            auto str = lexer.front.strvalue;
            lexer.popFront();

            auto e = new StringExpr(Loc(), str);
            return e;
        }

        error("unexpected token");
        return null;
    }
}
