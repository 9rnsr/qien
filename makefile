# Requires: DigitalMars make
# http://www.digitalmars.com/ctg/make.html

DMD=dmd
SRCS=\
	main.d err.d file.d

TARGET=qc

all: release

release:
	$(DMD) -g -of$(TARGET) $(SRCS)

debug:
	$(DMD) -g -of$(TARGET) -debug $(SRCS)

clean:
	@DEL *.obj
