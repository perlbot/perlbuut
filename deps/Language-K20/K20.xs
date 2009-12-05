#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "const-c.inc"

#include <k20.h>
#include <stdio.h>

MODULE = Language::K20		PACKAGE = Language::K20		

INCLUDE: const-xs.inc

void
k20eval(x)
		char* x
	CODE:
		cd(ksk("",0));
		
		int fd = dup(fileno(stderr));
		freopen("/dev/null", "w", stderr);
		K foo = ksk(x, 0);
		if(foo->t != 6){
			K s = ksk("{_ssr[5:x;\"\\n\";\";\"]}",gnk(1,foo));
			printf("%s\n", KC(s));
			cd(s);
		}
		else if(foo->n != 0)
			printf("%s error\n", (S)foo->n);
		cd(foo);
		dup2(fd, fileno(stderr));
		close(fd);
		clearerr(stderr);

