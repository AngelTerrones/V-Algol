//
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
//

#include <stdarg.h>
#include <stdint.h>

#define MTIME ((volatile uint32_t *)(0x20000008))
#define UART_CFG ((volatile uint32_t *)(0x20010000))
#define UART_TX ((volatile uint32_t *)(0x20010004))
#define UART_TX_STATUS ((volatile uint32_t *)(0x2001000C))

// needed for dhrystone
void setStats(int enable){}

void printf_c(int c) {
        putchar(c);
}

void printf_s(char *p) {
        while(*p != 0)
                putchar(*(p++));
}

void printf_d(int val) {
        char buffer[20];
        char *p=  buffer;
        if (val < 0) {
                putchar('-');
                val = -val;
        }
        while (val || p == buffer){
                *(p++) = 0x30 + (val % 10);
                val /= 10;
        }
        while (p != buffer)
                putchar(*(--p));
}

void putchar(char c){
        while (!((*UART_TX_STATUS) & 0x1));
        *UART_TX = c;
}

//Time in microsecond
long time(){
        uint32_t ht = MTIME[1];
        uint32_t lt = MTIME[0];
        return (ht << 32) | lt; // FIXME : read the time in a better way
}

int printf(const char *format, ...)
{
        int i;
        va_list ap;

        va_start(ap, format);

        for (i = 0; format[i]; i++) {
                if (format[i] == '%') {
                        while (format[++i]) {
                                if (format[i] == 'c') {
                                        printf_c(va_arg(ap,int));
                                        break;
                                }
                                if (format[i] == 's') {
                                        printf_s(va_arg(ap,char*));
                                        break;
                                }
                                if (format[i] == 'd') {
                                        printf_d(va_arg(ap,int));
                                        break;
                                }
                        }
                } else
                        printf_c(format[i]);
        }

        va_end(ap);
}

void uart_init() {
        *UART_CFG = 100; // 1MBaud
}
