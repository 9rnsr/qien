# Requires: DigitalMars make
# http://www.digitalmars.com/ctg/make.html

DMD=dmd
SRCS=\
	main.d

TARGET=qc

all:
	$(DMD) -of$(TARGET) $(SRCS)
