module qien.interp;

import qien.decl;
import qien.err;
import qien.expr;
import qien.stmt;
import qien.visitor;

class Interpreter : Visitor
{
    alias visit = super.visit;

    this()
    {
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
        error("ICE: unexpected compilation result: ErrorExp");
    }

    override void visit(IntegerExpr e)
    {
    }

    override void visit(StringExpr e)
    {
    }

    override void visit(FuncExpr e)
    {
        //e.fd.accept(this);
    }

    override void visit(IdentifierExpr e)
    {
        error("ICE: unexpected compilation result: IdentifierExp");
    }
}

void interpret(Expr e)
{
    if (!e)
        return;
    scope v = new Interpreter();
    e.accept(v);
}
