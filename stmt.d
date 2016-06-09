module qien.stmt;

import qien.decl;
import qien.expr;
import qien.loc;

class Stmt
{
    Loc loc;

    this(Loc loc)
    {
        this.loc = loc;
    }
}

class ExprStmt : Stmt
{
    Expr expr;

    this(Loc loc, Expr expr)
    {
        super(loc);
        this.expr = expr;
    }
}

class DefStmt : Stmt
{
    Decl decl;

    this(Loc loc, Decl decl)
    {
        super(loc);
        this.decl = decl;
    }
}

class CompoundStmt : Stmt
{
    Stmt[] statements;

    this(Loc loc, Stmt[] statements)
    {
        super(loc);
        this.statements = statements;
    }
}

class ScopeStmt : Stmt
{
    Stmt stmt;

    this(Loc loc, Stmt stmt)
    {
        super(loc);
        this.stmt = stmt;
    }
}
