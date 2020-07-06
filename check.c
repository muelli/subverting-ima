
#include <stdio.h>

int main (int argc, char* argv[]) {

    const int sentinel_front = 0x41414141;
    //const int compromised = 0xFFFFFFFF;
    const int compromised = 0;
    const int sentinel_back = 0x41414141;

    const char red[] = "\033[0;41m";
    const char green[] = "\033[0;42m";
    const char normal[] = "System Unmodified!";
    const char hacked[] = "System Hacked!!!11";
    const char blank[] =  "                  ";
    const char reset[] = "\033[0m";

    const char* prefix = compromised ? red : green;
    const char* text = compromised ? hacked : normal;

    printf ("%s                                     %s\n", prefix, reset);
    printf ("%s                                     %s\n", prefix, reset);
    printf ("%s                                     %s\n", prefix, reset);

    printf ("%s      %s  %s  %s         %s\n", prefix, reset, blank, prefix, reset);
    printf ("%s      %s  %s  %s         %s\n", prefix, reset, text, prefix, reset);
    printf ("%s      %s  %s  %s         %s\n", prefix, reset, blank, prefix, reset);

    printf ("%s                                     %s\n", prefix, reset);
    printf ("%s                                     %s\n", prefix, reset);
    printf ("%s                                     %s\n", prefix, reset);

    if (compromised) {
    } else {
    }
    return 0;
}
