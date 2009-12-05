#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

// j intepreter plugin for buubot

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define OUTPUT_MAXLEN 50*1024*1024

typedef void *Jinterp_t;
Jinterp_t JInit(void);
int JDo(Jinterp_t jsess, const char *cmd);
int JFree(Jinterp_t jsess);
int JGetM(Jinterp_t jsess, char *cmd, long *type, long *rank, long **shape, void **data);

int
jplugin(char *cmd) {
	Jinterp_t jp = JInit();
	if (JDo(jp, "9!:25]1")) {
		fprintf(stderr, "|jplugin error: jdo safe\n");
		goto error;
	}
	if (JDo(jp, /*"(9!:1](2^31)|6!:9$0)["*/"(9!:33]50)[(9!:21]2^25)[(9!:7]'+++++++++|-')")) {
		fprintf(stderr, "|jplugin error: jdo config\n");
		goto error;
	}
	static const char cmd_prefix[] = "res_boti_=: ";
	char *lcmd = malloc(sizeof(cmd_prefix) + strlen(cmd) + 5);
	if (!lcmd) {
		fprintf(stderr, "|jplugin error: no memory\n");
		goto error;
	}
	stpcpy(stpcpy(lcmd, cmd_prefix), cmd);
	if (JDo(jp, lcmd)) {
		if (JDo(jp, "out_boti_=: ]13!:12''")) {
			fprintf(stderr, "|jplugin error: jdo geterrmsg\n");
			goto error;
		}
	} else {
		if (JDo(jp, "out_boti_=: 3 :'d=.5!:5 y if. 4!:0 y do. d else.if. ((1>:#@$)*.3!:0 e.2^1 17\"_)y@.0 do. 1 u:,y@.0 else. d end.end.' <'res_boti_'")) {
			fprintf(stderr, "|jplugin error: jdo fmtoutput\n");
			goto error;
		}
	}
	long tp = -1, rk = -1; long *di = 0; void *da = 0;
	if (JGetM(jp, "out_boti_", &tp, &rk, &di, &da)) {
		fprintf(stderr, "|jplugin error: jgetm output\n");
		goto error;
	}
	//fprintf(stderr, "[tp=%d rk=%d di0=%d]\n", tp, rk, di[0]);
	if (!(2 == tp && 1 == rk)) {
		fprintf(stderr, "|jplugin error: jgetm nonstring\n");
		goto error;
	}
	size_t sz = di[0];
	if (OUTPUT_MAXLEN < sz) 
		sz = OUTPUT_MAXLEN;
	if (1 != fwrite((char *)da, sz, 1, stdout)) {
		fprintf(stderr, "|jplugin error: write stdout\n");
		goto error;
	}
	if (0 != fflush(stdout)) {
		fprintf(stderr, "|jplugin error: flush stdout\n");
		goto error;
	}
	JFree(jp);
	return 0;
error:
		JFree(jp);
		return 1;
}


MODULE = Jplugin		PACKAGE = Jplugin		

PROTOTYPES: DISABLE

int
jplugin(cmd)
	char *cmd



