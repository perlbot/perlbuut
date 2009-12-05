/* K(f:obj 2:("f";2)) call C(K f(K x,K y){}) MAX 7 args*/
#define R return
#define O printf
#define Z static
#define DO(n,x) {I i=0,_i=(n);for(;i<_i;++i){x;}}
typedef int I;typedef double F;typedef char C;typedef C*S;typedef unsigned char UC;
typedef struct k0{I c,t,n;struct k0*k[1];}*K;

/* atom accessors, e.g.	Ki(x)=2 */
#define Ki(x) ((x)->n)
#define Kf(x) (*KF(x))
#define Kc(x) (*(UC*)&(x)->n)
#define Ks(x) (*(S*)&(x)->n)

/* list accessors, e.g. KF(x)[i]=2.0 */
#define KI(x) ((I*)((x)->k))
#define KF(x) ((F*)((x)->k))
#define KC(x) ((UC*)((x)->k))
#define KS(x) ((S*)((x)->k))
#define KK(x) ((K*)((x)->k))

#ifdef __cplusplus
extern "C" {
#endif

extern S sp(S); /* symbol from phrase */

/* atom generators, e.g. gi(2),gf(2.0),gc('2'),gs(sp("2")) */
extern K gi(I),gf(F),gc(C),gs(S),gn(void);

/* list generator (t as in 4::), e.g. gtn(-1,9) integer vector */
extern K gtn(I t,I n);

/* phrase (-3=4::) generators, e.g. gp("asdf");C*s;gpn(s,4); */
extern K gp(S),gpn(S,I);

/* error, e.g. if(x->t!=-1)return kerr("need integer vector");*/
extern K kerr(S),gsk(S,K),gnk(I,...),ci(K),ksk(S,K),kap(K*,void*);
extern I cd(K),jd(I),dj(I),scd(I),sdf(I,I(*)(void)),sfn(S,K(*)(void),I);

#ifdef __cplusplus 
}
#endif

/* e.g. 
load function(s) from a.c

#include "k20.h"
K f(K x,K y){return gi(Ki(x)+Ki(y));} // add 2 integers
K g(K x){return gf(Kf(x)+1);}	// add 1 to float
...

LINUX(dlopen): cc -shared a.c -o a.so

in k,
  f:"[path]/a"2:("f";2)
  g:"[path]/a"2:("g";1)

  f[2;3]
5
  g[2.3]
3.3

FILES: .l(k binary) 16 byte header: -3 1 type count
types -1(int) -2(float) -3(byte) can be mapped as is.
syms are null terminated. 

*/

