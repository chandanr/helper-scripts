#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
	unsigned long long mem;
	long pgsize;
	char *ptr;
	int nr_pages;

	if (argc != 2) {
		fprintf(stderr, "Usage: %s <memory in MiB>.\n",
				argv[0]);
		exit(1);
	}

	mem = strtoull(argv[1], NULL, 0);
	printf("Consuming %llu MiB of memory\n", mem);

	pgsize = sysconf(_SC_PAGESIZE);
	printf("Page size = %ld.\n", pgsize);

	nr_pages = (mem << 20) >> 12;
	printf("nr_pages = %d.\n", nr_pages);

	while (nr_pages--) {
		ptr = malloc(pgsize);
		*ptr = 1;
	}

	printf("Sleeping ... ");
	sleep(60);
	printf("\n");

	exit(0);
}
