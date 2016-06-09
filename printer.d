module qien.printer;

import core.stdc.stdio;

import qien.decl;
import qien.expr;
import qien.stmt;
import qien.token;
import qien.visitor;

void printer(T)(T t)
{
    scope v = new PrintVisitor();
    t.accept(v);
}

class PrintVisitor : Visitor
{
    alias visit = super.visit;

    uint level;

    this(uint level = 0)
    {
        this.level = level;
    }

    void enter()
    {
        ++level;
    }

    void exit()
    {
        --level;
    }

    void indent()
    {
        foreach (i; 0 .. cast(ulong)level * 4)
        {
            printf(" ");
        }
    }

    override void visit(Module md)
    {
        foreach (d; md.members)
        {
            if (d)
                d.accept(this);
        }
    }

    override void visit(VarDecl vd)
    {
        indent();
        printf("%s ", Token.toChars(TOK.def));
        printf("%s", vd.ident.toChars());
        if (vd.einit)
        {
            printf(" = ");
            vd.einit.accept(this);
        }
        printf(";\n");
    }

    override void visit(FuncDecl fd)
    {
        indent();
        printf("%s ", Token.toChars(TOK.def));
        printf("%s", fd.ident.toChars());

        printf("(");
        foreach (vd; fd.fparams)
        {
            vd.accept(this);
        }
        printf(")");
        if (fd.sbody)
        {
            printf("\n");
            indent(); printf("{\n");
            enter();
            fd.sbody.accept(this);
            exit();
            indent(); printf("}\n");
        }
        else
            printf(";\n");
    }

    override void visit(ExprStmt es)
    {
        indent();
        if (es.expr)
            es.expr.accept(this);
        printf(";\n");
    }

    override void visit(DefStmt ds)
    {
        ds.decl.accept(this);
    }

    override void visit(CompoundStmt cs)
    {
        foreach (s; cs.statements)
        {
            if (s)
                s.accept(this);
        }
    }

    override void visit(ScopeStmt ss)
    {
        indent(); printf("{\n");
        enter();
        if (ss.stmt)
            ss.stmt.accept(this);
        exit();
        indent(); printf("}\n");
    }

    override void visit(ErrorExpr e)
    {
        printf("__error");
    }

    override void visit(IntegerExpr e)
    {
        printf("%llu", e.value);
    }

    override void visit(StringExpr e)
    {
        printf("\"");
        foreach (char c; e.value)
        {
            switch (c)
            {
                case '"':
                case '\\':
                    printf("\\%c", c);
                    break;

                default:
                    printf("%c", c);
            }
        }
        printf("\"");
    }

    override void visit(FuncExpr e)
    {
        e.fd.accept(this);
    }

    override void visit(IdentifierExpr e)
    {
        printf("%s", e.ident.toChars());
    }

    override void visit(CallExpr e)
    {
        e.e1.accept(this);
        printf("(");
        foreach (i, earg; e.arguments)
        {
            earg.accept(this);
            if (i < e.arguments.length - 1)
                printf(", ");
        }
        printf(")");
    }
}
