#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <systemd/sd-journal.h>

#include "test-ima-cache-evict.h"

extern char __executable_start, etext;

static char hello[] = "Hello, World!";
/* Compile with -fno-zero-initialized-in-bss to get this variable into the data section rather than the BSS section */
//static char foo[4096 /* pages, 4k */
//    *  256 /* 1MB */
//    *  128
//    ] = {0};
//__attribute__((section(".text#")))
static char foo[QEMU_MANIPULATE_SIZE] = {0};

static char bye[] = "Good bye!";

int main()
{
    printf ("%s from %p, %p to %p\n", hello, &__executable_start, &main, &etext);
    sd_journal_send ( "MESSAGE=Adresses  %p, %p to %p", hello, &__executable_start, &main, &etext,
                      "MESSAGE_ID=ba51ad4293834fa695b4c548971d9a71",
                      "HELLO_ADDR=%p", hello,
                      "EXEC_START_ADDR=%p", &__executable_start,
                      "MAIN_ADDR=%p", &main,
                      "ETEXT_ADDR=%p", &etext,
                      NULL);
    printf ("Waiting for stress-ng\n");
    system ("systemctl start stress-ng.service\n");
    printf ("Finished sleeping...\n");
    int manipulated_bytes = 0;
    bool previously_manipulated = 0;
    for (size_t i = 0; i < sizeof(foo); i++) {
        if (foo[i] != 0) {
            if (previously_manipulated != 1) {
                printf ("%8lu (%p) Toggling from unmanipulated to manipulated\n", i, &foo[i]);
                sd_journal_send ( "MESSAGE=Toggling from unmanipulated to manipulated at %8lu (%p)", i, &foo[i],
                                  "MESSAGE_ID=66143216050d45968af3ad6ea904bd74",
                                  "I=%lu", i,
                                  "ADDR=%p", &foo[i],
                                  NULL);
            }
            manipulated_bytes += 1;
            if (manipulated_bytes == 1) {
                printf ("first manipulation found at %lu (%p).\n", i, &foo[i]);
	        }
            previously_manipulated = 1;
        } else {
            if (previously_manipulated != 0) {
                printf ("%lu (%p) Toggling from manipulated to unmanipulated\n", i, &foo[i]);
                sd_journal_send ( "MESSAGE=Toggling from manipulated to unmanipulated at %lu (%p)", i, &foo[i],
                                  "MESSAGE_ID=e363be7ee1db462b9fcf6492173fcc78",
                                  "I=%lu", i,
                                  "ADDR=%p", &foo[i],
                                  NULL);
            }
            previously_manipulated = 0;
        }
    }
    printf ("%i bytes (of %lu) were manipulated.\n", manipulated_bytes, sizeof (foo));
    printf ("test-ima-cache-evict: %.04f\n", manipulated_bytes / (double) sizeof (foo));
    sd_journal_send ( "MESSAGE=Manipulated %i  bytes out of %lu (%.04f)", manipulated_bytes, sizeof (foo), manipulated_bytes / (double) sizeof (foo),
                      "MESSAGE_ID=75017a97fdd044cf894e037a7fcabd78",
                      "SIZEOF_FOO=%lu", sizeof (foo),
                      "MANIPULATED_BYTES=%i", manipulated_bytes,
                      "MANIPULATED_BYTES_PCT=%.04f", manipulated_bytes / (double) sizeof (foo),
                      NULL);

    printf ("%s\n", bye);
    return 0;
}

