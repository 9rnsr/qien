module qien.semant;

import qien.decl;
import qien.err;
import qien.expr;
import qien.id;
import qien.sc;
import qien.stmt;
import qien.visitor;

void runSemant(Module md)
{
    auto sc = new Scope();

    // makes members visible
    foreach (d; md.members)
    {
        if (d)
            sc.tab.insert(d);
    }

    scope v = new SemantVisitor(sc);
    foreach (d; md.members)
    {
        if (d)
            d.accept(v);
    }

    sc.pop();
}

void runSemant(Scope* sc, Expr e)
{
    if (!e)
        return;
    scope v = new SemantVisitor(sc);
    e.accept(v);
}

class SemantVisitor : Visitor
{
    alias visit = super.visit;

    Scope* sc;

    this(Scope* sc)
    {
        this.sc = sc;
    }

    override void visit(VarDecl vd)
    {
        if (vd.einit)
            vd.einit.accept(this);

        //if (sc.func)
        //    sc.tab.insert(vd);
    }

    override void visit(FuncDecl fd)
    {
        foreach (vd; fd.fparams)
        {
            vd.accept(this);
        }
        if (fd.sbody)
        {
            auto sc2 = sc.push();
            sc2.func = fd;
            scope v = new SemantVisitor(sc2);
            fd.sbody.accept(v);
            sc2.pop();
        }
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
        if (auto d = sc.search(e.ident))
        {
            // OK
            return;
        }
        //if (e.ident == "print")
        //{
        //    new DeclExpr(builtInFunc("print"))
        //}
        error(e.loc, "undefined identifier %s", e.ident.toChars());
    }

    override void visit(CallExpr e)
    {
        e.e1.accept(this);
        foreach (earg; e.arguments)
        {
            earg.accept(this);
        }
    }
}
