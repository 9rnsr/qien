module qien.visitor;

import qien.decl;
import qien.expr;
import qien.stmt;

class Visitor
{
    void visit(Module m)         { assert(0); }

    void visit(Decl d)           { assert(0); }
    void visit(FuncDecl d)       { visit(cast(Decl)d); }
    void visit(VarDecl d)        { visit(cast(Decl)d); }
    void visit(TypeDecl d)       { visit(cast(Decl)d); }

    void visit(Stmt)             { assert(0); }
    void visit(ExprStmt s)       { visit(cast(Stmt)s); }
    void visit(DefStmt s)        { visit(cast(Stmt)s); }
    void visit(CompoundStmt s)   { visit(cast(Stmt)s); }
    void visit(ScopeStmt s)      { visit(cast(Stmt)s); }

    void visit(Expr e)           { assert(0); }
    void visit(ErrorExpr e)      { visit(cast(Expr)e); }
    void visit(IntegerExpr e)    { visit(cast(Expr)e); }
    void visit(StringExpr e)     { visit(cast(Expr)e); }
    void visit(FuncExpr e)       { visit(cast(Expr)e); }
    void visit(IdentifierExpr e) { visit(cast(Expr)e); }
    void visit(UnaExpr e)        { visit(cast(Expr)e); }
    void visit(BinExpr e)        { visit(cast(Expr)e); }
    void visit(CallExpr e)       { visit(cast(UnaExpr)e); }
    void visit(AddExpr e)        { visit(cast(BinExpr)e); }
    void visit(SubExpr e)        { visit(cast(BinExpr)e); }
    void visit(MulExpr e)        { visit(cast(BinExpr)e); }
    void visit(DivExpr e)        { visit(cast(BinExpr)e); }
    void visit(ModExpr e)        { visit(cast(BinExpr)e); }
    void visit(AndAndExpr e)     { visit(cast(BinExpr)e); }
    void visit(AndExpr e)        { visit(cast(BinExpr)e); }
    void visit(OrOrExpr e)       { visit(cast(BinExpr)e); }
    void visit(OrExpr e)         { visit(cast(BinExpr)e); }
    void visit(EqExpr e)         { visit(cast(BinExpr)e); }
    void visit(CmpExpr e)        { visit(cast(BinExpr)e); }
    void visit(AssignExpr e)     { visit(cast(BinExpr)e); }
}
