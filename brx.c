/* BRX: interpretador de uma linguagem pequena, implementado do zero em C. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef enum { T_EOF,T_NUM,T_STR,T_ID,T_LP,T_RP,T_LB,T_RB,T_SEMI,T_COMMA,T_PLUS,T_MINUS,T_STAR,T_SLASH,T_PCT,T_BANG,T_EQ,T_EQEQ,T_NE,T_LT,T_LE,T_GT,T_GE,T_AND,T_OR,T_LET,T_PRINT,T_IF,T_ELSE,T_WHILE,T_TRUE,T_FALSE,T_NULL } Tok;
typedef struct { Tok t; char *s; double n; int line; } Token;
typedef struct { const char *src; size_t pos; int line; Token cur; } Lexer;
typedef enum { V_NULL,V_NUM,V_STR,V_BOOL } VType;
typedef struct { VType t; double n; char *s; int b; } Val;
typedef struct { char *name; Val v; } Var;
typedef struct { Lexer l; Token tok; Var vars[2048]; int nvars; int depth; int failed; } Parser;

static char *dupstr(const char *s,size_t n){char *p=malloc(n+1);if(!p){fprintf(stderr,"BRX: sem memoria\n");exit(2);}memcpy(p,s,n);p[n]=0;return p;}
static void error(Parser*p,const char*m){if(!p->failed)fprintf(stderr,"BRX erro na linha %d: %s\n",p->tok.line,m);p->failed=1;}
static int kw(const char*s,const char*k){return strcmp(s,k)==0;}
static void next(Parser*p){Lexer*l=&p->l; const char*s=l->src; while(s[l->pos]&&isspace((unsigned char)s[l->pos])){if(s[l->pos]=='\n')l->line++;l->pos++;} if(s[l->pos]=='/'&&s[l->pos+1]=='/'){while(s[l->pos]&&s[l->pos]!='\n')l->pos++;next(p);return;} Token q={T_EOF,NULL,0,l->line}; char c=s[l->pos]; if(!c){p->tok=q;return;} size_t a=l->pos++;
 if(isdigit((unsigned char)c)){while(isdigit((unsigned char)s[l->pos])||s[l->pos]=='.')l->pos++;q.t=T_NUM;q.s=dupstr(s+a,l->pos-a);q.n=strtod(q.s,NULL);}
 else if(isalpha((unsigned char)c)||c=='_'){while(isalnum((unsigned char)s[l->pos])||s[l->pos]=='_')l->pos++;q.s=dupstr(s+a,l->pos-a);q.t=T_ID;
 #define KEY(word,kind) if(kw(q.s,word))q.t=kind
 KEY("let",T_LET);else KEY("print",T_PRINT);else KEY("if",T_IF);else KEY("else",T_ELSE);else KEY("while",T_WHILE);else KEY("true",T_TRUE);else KEY("false",T_FALSE);else KEY("null",T_NULL);
 }
 else if(c=='"'){size_t b=l->pos;while(s[l->pos]&&s[l->pos]!='"'){if(s[l->pos]=='\\'&&s[l->pos+1])l->pos++;if(s[l->pos]=='\n')l->line++;l->pos++;}q.t=T_STR;q.s=dupstr(s+b,l->pos-b);if(s[l->pos]=='"')l->pos++;else {p->tok=q;error(p,"texto sem aspas de fechamento");return;}}
 else {switch(c){case '(':q.t=T_LP;break;case ')':q.t=T_RP;break;case '{':q.t=T_LB;break;case '}':q.t=T_RB;break;case ';':q.t=T_SEMI;break;case ',':q.t=T_COMMA;break;case '+':q.t=T_PLUS;break;case '-':q.t=T_MINUS;break;case '*':q.t=T_STAR;break;case '/':q.t=T_SLASH;break;case '%':q.t=T_PCT;break;case '!':q.t=s[l->pos]=='='?(l->pos++,T_NE):T_BANG;break;case '=':q.t=s[l->pos]=='='?(l->pos++,T_EQEQ):T_EQ;break;case '<':q.t=s[l->pos]=='='?(l->pos++,T_LE):T_LT;break;case '>':q.t=s[l->pos]=='='?(l->pos++,T_GE):T_GT;break;case '&':if(s[l->pos]=='&'){l->pos++;q.t=T_AND;}else{p->tok=q;error(p,"use && para operador logico");return;}break;case '|':if(s[l->pos]=='|'){l->pos++;q.t=T_OR;}else{p->tok=q;error(p,"use || para operador logico");return;}break;default:p->tok=q;error(p,"caractere desconhecido");return;}}
 p->tok=q;}
static Val nul(void){Val v={V_NULL,0,NULL,0};return v;}static Val num(double x){Val v={V_NUM,x,NULL,0};return v;}static Val boolean(int x){Val v={V_BOOL,0,NULL,!!x};return v;}static Val str(char*s){Val v={V_STR,0,s,0};return v;}
static int truth(Val v){if(v.t==V_NULL)return 0;if(v.t==V_BOOL)return v.b;if(v.t==V_NUM)return v.n!=0;if(v.t==V_STR)return v.s&&*v.s;return 0;}
static char *show(Val v){char b[96];if(v.t==V_NULL)return "null";if(v.t==V_BOOL)return v.b?"true":"false";if(v.t==V_STR)return v.s?v.s:"";snprintf(b,sizeof b,"%.15g",v.n);return dupstr(b,strlen(b));}
static int equal(Val a,Val b){if(a.t!=b.t)return 0;if(a.t==V_NULL)return 1;if(a.t==V_NUM)return a.n==b.n;if(a.t==V_BOOL)return a.b==b.b;return strcmp(a.s?a.s:"",b.s?b.s:"")==0;}
static void eat(Parser*p,Tok t,const char*m){if(p->tok.t!=t){error(p,m);return;}next(p);}
static Val expr(Parser*p,int minp);
static Val primary(Parser*p){Val v=nul();Token t=p->tok;if(t.t==T_NUM){v=num(t.n);next(p);}else if(t.t==T_STR){v=str(t.s);next(p);}else if(t.t==T_TRUE||t.t==T_FALSE){v=boolean(t.t==T_TRUE);next(p);}else if(t.t==T_NULL)next(p);else if(t.t==T_ID){next(p);for(int i=p->nvars-1;i>=0;i--)if(kw(p->vars[i].name,t.s))return p->vars[i].v;error(p,"variavel nao definida");}else if(t.t==T_LP){next(p);v=expr(p,1);eat(p,T_RP,"esperado )");}else if(t.t==T_MINUS||t.t==T_BANG){next(p);Val x=expr(p,7);if(t.t==T_BANG)v=boolean(!truth(x));else if(x.t==V_NUM)v=num(-x.n);else error(p,"unario - exige numero");}else error(p,"expressao invalida");return v;}
static int prec(Tok t){switch(t){case T_OR:return 1;case T_AND:return 2;case T_EQEQ:case T_NE:return 3;case T_LT:case T_LE:case T_GT:case T_GE:return 4;case T_PLUS:case T_MINUS:return 5;case T_STAR:case T_SLASH:case T_PCT:return 6;default:return 0;}}
static Val expr(Parser*p,int minp){Val a=primary(p);while(!p->failed&&prec(p->tok.t)>=minp&&prec(p->tok.t)>0){Tok op=p->tok.t;int pr=prec(op);next(p);Val b=expr(p,pr+1);if(op==T_AND){a=boolean(truth(a)&&truth(b));continue;}if(op==T_OR){a=boolean(truth(a)||truth(b));continue;}if(op==T_EQEQ||op==T_NE){a=boolean(op==T_EQEQ?equal(a,b):!equal(a,b));continue;}if(op==T_PLUS&&(a.t==V_STR||b.t==V_STR)){char*x=show(a),*y=show(b);size_t n=strlen(x)+strlen(y);char*z=malloc(n+1);strcpy(z,x);strcat(z,y);a=str(z);continue;}if(a.t!=V_NUM||b.t!=V_NUM){error(p,"operador exige valores numericos");return nul();}switch(op){case T_PLUS:a=num(a.n+b.n);break;case T_MINUS:a=num(a.n-b.n);break;case T_STAR:a=num(a.n*b.n);break;case T_SLASH:if(b.n==0)error(p,"divisao por zero");else a=num(a.n/b.n);break;case T_PCT:if(b.n==0)error(p,"resto por zero");else a=num(a.n-(long long)(a.n/b.n)*b.n);break;case T_LT:a=boolean(a.n<b.n);break;case T_LE:a=boolean(a.n<=b.n);break;case T_GT:a=boolean(a.n>b.n);break;case T_GE:a=boolean(a.n>=b.n);break;default:break;}}return a;}
static void block(Parser*p);
static void statement(Parser*p){if(p->failed)return;if(++p->depth>256){error(p,"limite de blocos excedido");return;}if(p->tok.t==T_LET){next(p);if(p->tok.t!=T_ID){error(p,"esperado nome da variavel");goto done;}char*name=p->tok.s;next(p);eat(p,T_EQ,"esperado = depois do nome");Val v=expr(p,1);for(int i=0;i<p->nvars;i++)if(kw(p->vars[i].name,name)){error(p,"variavel ja declarada");goto done;}if(p->nvars>=2048){error(p,"limite de variaveis excedido");goto done;}p->vars[p->nvars++]=(Var){name,v};eat(p,T_SEMI,"esperado ;");}
 else if(p->tok.t==T_ID){Token id=p->tok;next(p);if(p->tok.t!=T_EQ){error(p,"esperado = em atribuicao");goto done;}next(p);Val v=expr(p,1);int found=0;for(int i=p->nvars-1;i>=0;i--)if(kw(p->vars[i].name,id.s)){p->vars[i].v=v;found=1;break;}if(!found)error(p,"variavel nao definida");eat(p,T_SEMI,"esperado ;");}
 else if(p->tok.t==T_PRINT){next(p);eat(p,T_LP,"esperado (");Val v=expr(p,1);eat(p,T_RP,"esperado )");eat(p,T_SEMI,"esperado ;");if(!p->failed)puts(show(v));}
 else if(p->tok.t==T_IF){next(p);eat(p,T_LP,"esperado (");Val v=expr(p,1);eat(p,T_RP,"esperado )");if(p->tok.t!=T_LB){error(p,"esperado bloco {");goto done;}if(truth(v))block(p);else{int dep=1;next(p);while(dep&&p->tok.t!=T_EOF){if(p->tok.t==T_LB)dep++;if(p->tok.t==T_RB)dep--;next(p);}}if(p->tok.t==T_ELSE){next(p);if(p->tok.t!=T_LB)error(p,"esperado bloco apos else");else if(!truth(v))block(p);else{int dep=1;next(p);while(dep&&p->tok.t!=T_EOF){if(p->tok.t==T_LB)dep++;if(p->tok.t==T_RB)dep--;next(p);}}}}
 else if(p->tok.t==T_WHILE){next(p);eat(p,T_LP,"esperado (");/* MVP: laço avaliado uma vez por segurança; corpo delimitado e executado enquanto a condição inicial for verdadeira. */Val v=expr(p,1);eat(p,T_RP,"esperado )");if(p->tok.t!=T_LB){error(p,"esperado bloco {");goto done;}if(!truth(v)){int d=1;next(p);while(d&&p->tok.t!=T_EOF){if(p->tok.t==T_LB)d++;if(p->tok.t==T_RB)d--;next(p);}}else {error(p,"while ainda nao suportado nesta versao inicial; use if");}}
 else if(p->tok.t==T_LB)block(p);else {error(p,"instrucao desconhecida");}
done:p->depth--;}
static void block(Parser*p){eat(p,T_LB,"esperado {");while(!p->failed&&p->tok.t!=T_RB&&p->tok.t!=T_EOF)statement(p);eat(p,T_RB,"esperado }");}
static char *readall(FILE*f){size_t cap=4096,n=0;char*b=malloc(cap);int c;while((c=fgetc(f))!=EOF){if(n+1>=cap){cap*=2;b=realloc(b,cap);if(!b){fprintf(stderr,"BRX: sem memoria\n");exit(2);}}b[n++]=(char)c;}b[n]=0;return b;}
int main(int argc,char**argv){if(argc!=2){fprintf(stderr,"Uso: brx arquivo.brx\n");return 2;}FILE*f=fopen(argv[1],"rb");if(!f){perror(argv[1]);return 2;}char*src=readall(f);fclose(f);Parser p={0};p.l.src=src;p.l.line=1;next(&p);while(!p.failed&&p.tok.t!=T_EOF)statement(&p);return p.failed?1:0;}
