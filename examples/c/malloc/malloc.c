#include <stdlib.h>
#include <stdint.h>
#include <flexpret_io.h>

#include <_syslist.h>

#define __print(val) ({ \
    write_csr(CSR_TOHOST, 0xbaaabaaa); \
    write_csr(CSR_TOHOST, val); \
})

void *
_sbrk (incr)
     int incr;
{
   extern char   end; /* Set by linker.  */
   static char * heap_end;
   char *        prev_heap_end;

   if (heap_end == 0)
     heap_end = & end;

   prev_heap_end = heap_end;
   heap_end += incr;

   return (void *) prev_heap_end;
}

int main() {
    __print(4);
    uint32_t* p = malloc(sizeof(uint32_t));
    *p = 100;
    __print(5);
    __print(*p);
    free(p);

    // Terminate the simulation
    _fp_finish();
    while(1) {}
    __builtin_unreachable();
}
