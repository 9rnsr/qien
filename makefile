# Requires: DigitalMars make
# http://www.digitalmars.com/ctg/make.html

DMD=dmd
SRCS=\
	main.d err.d file.d \
	token.d id.d lex.d parse.d

TARGET=qc

all: release

release:
	$(DMD) -g -of$(TARGET) $(SRCS)

debug:
	$(DMD) -g -of$(TARGET) -debug $(SRCS)

clean:
	@DEL *.obj
