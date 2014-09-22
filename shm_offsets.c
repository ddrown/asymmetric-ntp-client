#include <time.h>
#include <stdio.h>

// structure from ntp-4.2.6p5/ntpd/refclock_shm.c
struct shmTime {
	int    mode; /* 0 - if valid set
		      *       use values, 
		      *       clear valid
		      * 1 - if valid set 
		      *       if count before and after read of values is equal,
		      *         use values 
		      *       clear valid
		      */
	int    count;
	time_t clockTimeStampSec;
	int    clockTimeStampUSec;
	time_t receiveTimeStampSec;
	int    receiveTimeStampUSec;
	int    leap;
	int    precision;
	int    nsamples;
	int    valid;
	int    dummy[10]; 
} a;

int main() {
  printf("sizeof = %d  time_t = %d\n", sizeof(a), sizeof(time_t));
  printf("r.s = %d  r.us = %d\n", (void *)&a.clockTimeStampSec - (void *)&a, (void *)&a.clockTimeStampUSec - (void *)&a);
  printf("l.s = %d  l.us = %d\n", (void *)&a.receiveTimeStampSec - (void *)&a, (void *)&a.receiveTimeStampUSec - (void *)&a);
  printf("leap = %d  valid = %d\n", (void *)&a.leap - (void *)&a, (void *)&a.valid - (void *)&a);
  printf("lastdummy = %d\n", (void *)&a.dummy[9] - (void *)&a);
  /* Output
  x86_64, Linux:

  sizeof = 96  time_t = 8
  r.s = 8  r.us = 16
  l.s = 24  l.us = 32
  leap = 36  valid = 48
  lastdummy = 88

  i686, Linux:

  sizeof = 80  time_t = 4
  r.s = 8  r.us = 12
  l.s = 16  l.us = 20
  leap = 24  valid = 36
  lastdummy = 76

  */
}
