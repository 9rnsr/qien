module qien.err;

import core.stdc.stdio;

enum COLOR : int
{
    BLACK       = 0,
    RED         = 1,
    GREEN       = 2,
    BLUE        = 4,
    YELLOW      = RED | GREEN,
    MAGENTA     = RED | BLUE,
    CYAN        = GREEN | BLUE,
    WHITE       = RED | GREEN | BLUE,
}

version (Windows)
{
    import core.sys.windows.windows;

    WORD consoleAttributes(HANDLE h)
    {
        static CONSOLE_SCREEN_BUFFER_INFO sbi;
        static bool sbiInitialized = false;
        if (!sbiInitialized)
            sbiInitialized = GetConsoleScreenBufferInfo(h, &sbi) != FALSE;
        return sbi.wAttributes;
    }

    enum : int
    {
        FOREGROUND_WHITE = FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE,
    }
}

void setConsoleColorBright(bool bright)
{
    version (Windows)
    {
        auto h = GetStdHandle(STD_ERROR_HANDLE);
        auto attr = consoleAttributes(h);
        SetConsoleTextAttribute(h, attr | (bright ? FOREGROUND_INTENSITY : 0));
    }
    else
        static assert(0);
}

void setConsoleColor(COLOR color, bool bright)
{
    version (Windows)
    {
        auto h = GetStdHandle(STD_ERROR_HANDLE);
        auto attr = consoleAttributes(h);
        attr = (attr & ~(FOREGROUND_WHITE | FOREGROUND_INTENSITY)) |
               ((color & COLOR.RED)   ? FOREGROUND_RED   : 0) |
               ((color & COLOR.GREEN) ? FOREGROUND_GREEN : 0) |
               ((color & COLOR.BLUE)  ? FOREGROUND_BLUE  : 0) |
               (bright ? FOREGROUND_INTENSITY : 0);
        SetConsoleTextAttribute(h, attr);
    }
    else
        static assert(0);
}

void resetConsoleColor()
{
    version (Windows)
    {
        auto h = GetStdHandle(STD_ERROR_HANDLE);
        SetConsoleTextAttribute(h, consoleAttributes(h));
    }
    else
        static assert(0);
}

void error(const(char)* format, ...)
{
    import core.vararg;

    va_list ap;
    va_start(ap, format);

    setConsoleColorBright(true);
    fputs("command: ", stderr);
    setConsoleColor(COLOR.RED, true);
    fputs("Error: ", stderr);
    resetConsoleColor();
    vfprintf(stderr, format, ap);
    fputs("\n", stderr);
    fflush(stderr);

    va_end(ap);
}
