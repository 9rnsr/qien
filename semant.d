module qien.semant;

import qien.decl;
import qien.err;
import qien.expr;
import qien.id;
import qien.sc;
import qien.stmt;
import qien.visitor;

class SemantVisitor : Visitor
{
    alias visit = super.visit;

    Scope* sc;

    this(Scope* sc)
    {
        this.sc = sc;
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
        if (vd.einit)
            vd.einit.accept(this);
    }

    override void visit(FuncDecl fd)
    {
        foreach (vd; fd.fparams)
        {
            vd.accept(this);
        }
        if (fd.sbody)
            fd.sbody.accept(this);
    }

    override void visit(ExprStmt es)
    {
        if (es.expr)
            es.expr.accept(this);
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
        if (ss.stmt)
            ss.stmt.accept(this);
    }

    override void visit(ErrorExpr e)
    {
    }

    override void visit(IntegerExpr e)
    {
    }

    override void visit(StringExpr e)
    {
    }

    override void visit(FuncExpr e)
    {
        e.fd.accept(this);
    }

    override void visit(IdentifierExpr e)
    {
        //if (e.ident == "print")
        //{
        //    new DeclExpr(builtInFunc("print"))
        //}
        error(e.loc, "undefined identifier %s", e.ident.toChars());
    }
}

void runSemant(Scope* sc, Expr e)
{
    if (!e)
        return;
    scope v = new SemantVisitor(sc);
    e.accept(v);
}
