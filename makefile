# Requires: DigitalMars make
# http://www.digitalmars.com/ctg/make.html

DMD=dmd
SRCS=\
	main.d err.d file.d loc.d visitor.d \
	token.d id.d lex.d parse.d \
	decl.d expr.d stmt.d \
	sc.d semant.d \
	interp.d \
	printer.d

TARGET=qc

all: release

release:
	$(DMD) -g -of$(TARGET) $(SRCS)

debug:
	$(DMD) -g -of$(TARGET) -debug $(SRCS)

clean:
	@DEL *.obj