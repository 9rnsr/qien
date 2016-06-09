module qien.stmt;

import qien.decl;
import qien.expr;
import qien.loc;
import qien.visitor;

class Stmt
{
    Loc loc;

    this(Loc loc)
    {
        this.loc = loc;
    }

    void accept(Visitor v) { v.visit(this); }
}

class ExprStmt : Stmt
{
    Expr expr;

    this(Loc loc, Expr expr)
    {
        super(loc);
        this.expr = expr;
    }

    override void accept(Visitor v) { v.visit(this); }
}

class DefStmt : Stmt
{
    Decl decl;

    this(Loc loc, Decl decl)
    {
        super(loc);
        this.decl = decl;
    }

    override void accept(Visitor v) { v.visit(this); }
}

class CompoundStmt : Stmt
{
    Stmt[] statements;

    this(Loc loc, Stmt[] statements)
    {
        super(loc);
        this.statements = statements;
    }

    override void accept(Visitor v) { v.visit(this); }
}

class ScopeStmt : Stmt
{
    Stmt stmt;

    this(Loc loc, Stmt stmt)
    {
        super(loc);
        this.stmt = stmt;
    }

    override void accept(Visitor v) { v.visit(this); }
}
