module qien.expr;

import qien.decl;
import qien.id;
import qien.loc;

class Expr
{
    Loc loc;

    this(Loc loc)
    {
        this.loc = loc;
    }
}

class ErrorExpr : Expr
{
    this()
    {
        super(Loc());
    }
}

class IntegerExpr : Expr
{
    ulong value;

    this(Loc loc, ulong value)
    {
        super(loc);
        this.value = value;
    }
}

class StringExpr : Expr
{
    string value;

    this(Loc loc, string value)
    {
        super(loc);
        this.value = value;
    }
}

class FuncExpr : Expr
{
    FuncDecl fd;

    this(Loc loc, FuncDecl fd)
    {
        super(loc);
        this.fd = fd;
    }
}

class IdentifierExp : Expr
{
    Id* ident;

    this(Loc loc, Id* ident)
    {
        super(loc);
        this.ident = ident;
    }
}

class UnaExpr : Expr
{
    Expr e1;

    this(Loc loc, Expr e1)
    {
        super(loc);
        this.e1 = e1;
    }
}

class CallExpr : UnaExpr
{
    Expr[] arguments;

    this(Loc loc, Expr e1, Expr[] arguments)
    {
        super(loc, e1);
        this.arguments = arguments;
    }
}

class BinExpr : Expr
{
    Expr e1;
    Expr e2;

    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc);
        this.e1 = e1;
        this.e2 = e2;
    }
}

class AddExpr : BinExpr
{
    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc, e1, e2);
    }
}

class SubExpr : BinExpr
{
    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc, e1, e2);
    }
}

class MulExpr : BinExpr
{
    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc, e1, e2);
    }
}

class DivExpr : BinExpr
{
    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc, e1, e2);
    }
}

class ModExpr : BinExpr
{
    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc, e1, e2);
    }
}

class AndAndExpr : BinExpr
{
    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc, e1, e2);
    }

    invariant
    {
        //assert e1.type.checkBoolean;
        //assert e2.type.checkBoolean;
    }
}

class AndExpr : BinExpr
{
    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc, e1, e2);
    }

    invariant
    {
        //assert e1.type.checkBitwise;
        //assert e2.type.checkBitwise;
    }
}

class OrOrExpr : BinExpr
{
    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc, e1, e2);
    }

    invariant
    {
        //assert e1.type.checkBoolean;
        //assert e2.type.checkBoolean;
    }
}

class OrExpr : BinExpr
{
    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc, e1, e2);
    }

    invariant
    {
        //assert e1.type.checkBitwise;
        //assert e2.type.checkBitwise;
    }
}

class EqExpr : BinExpr
{
    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc, e1, e2);
    }
}

class CmpExpr : BinExpr
{
    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc, e1, e2);
    }
}

class AssignExpr : BinExpr  // ?
{
    this(Loc loc, Expr e1, Expr e2)
    {
        super(loc, e1, e2);
    }
}
