#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define NEED_sv_2pv_flags
#include "ppport.h"

#include <time.h>
#include <sys/resource.h>

static int (*runops_original)(pTHX);
static int is_runnning = 0;
static U16 before_op_seq = 0;

#define USEC 1000000

HV *capture;

/*
 * capture of running opes status
 */
void
opcode_capture(OP *op, COP *cop, IV sec) {
    HV *op_stash;
    char seq[64];
    I32 seq_len;

    seq_len = sprintf(seq, "%d", op->op_seq);

    /* fetch the op stash */
    if (hv_exists(capture, seq, seq_len)) {
        SV **rv;
        rv = hv_fetch(capture, seq, seq_len, 0);
        if (!rv) {
            is_runnning = 0;
            croak("broken the capture hash");
        }
        op_stash = (HV *) SvRV(*rv);
    } else {
        /* create new entry */
        op_stash = newHV();
        hv_store(op_stash, "type",  4, newSViv(op->op_type), 0); 
        hv_store(op_stash, "steps", 5, newSViv(0), 0);
        hv_store(op_stash, "usec",  4, newSViv(0), 0);

        /* takes by COP */
        hv_store(op_stash, "cop_seq", 7, newSViv(cop->cop_seq), 0); 
        if (CopSTASHPV(cop)) hv_store(op_stash, "package", 7, newSVpv(CopSTASHPV(cop), strlen(CopSTASHPV(cop))), 0); 
        if (CopFILESV(cop)) hv_store(op_stash, "file",    4, newSVpv(SvPV_nolen(CopFILESV(cop)), strlen(SvPV_nolen(CopFILESV(cop)))), 0); 
        hv_store(op_stash, "line",    4, newSVuv((UV) CopLINE(cop)), 0); 

        hv_store(capture, seq, seq_len, newRV_inc((SV *) op_stash), 0);
    }

    /* increment of status */
    if (op_stash) {
        SV **count;
        SV **usec;
        count = hv_fetch(op_stash, "steps", 5, 0);
        usec  = hv_fetch(op_stash, "usec", 4, 0);
        if (!count || !usec) {
            is_runnning = 0;
            croak("broken the capture hash seq: %s", seq);
        }
        SvIV_set(*count, SvIV(*count) + 1);
        SvIV_set(*usec, SvIV(*usec) + sec);

        /* set the before current op_seq */
        hv_store(op_stash, "before_op_seq", 13, newSViv((IV) before_op_seq), 0);
    }

    before_op_seq = op->op_seq;
}

/*
 * PL_runopes for Devel::RunOpsAnalyze
 */
int
analyzer_runops(pTHX)
{   
    struct timeval tv;
    int status;
    IV sec;
    struct rusage rusage1, rusage2;
    OP *op;
    COP *cop, *last_cop;

    last_cop = NULL;
    while (1) {

        if (is_runnning) {
            /* trace mode */
            op  = PL_op;
            cop = PL_curcop;

            /* getting first time */
            getrusage(RUSAGE_SELF, &rusage1);

            /* we need boolean value */
            status = !!!(PL_op = CALL_FPTR(PL_op->op_ppaddr)(aTHX));

            /* making running time of op */
            getrusage(RUSAGE_SELF, &rusage2);
            sec = ((rusage2.ru_utime.tv_sec * USEC) + rusage2.ru_utime.tv_usec) - ((rusage1.ru_utime.tv_sec * USEC) + rusage1.ru_utime.tv_usec);

            if (status) {
                break;
            }

            if (!CopFILESV(cop) && last_cop != NULL) {
                /* use last cop / missing filename */
                cop = last_cop;
            } else {
                last_cop = cop;
                if (PL_curcop->op_seq == op->op_seq) {
                    /* use current cop / curcop mismatch*/
                    cop = PL_curcop;
                } else if (cop->op_seq == 0) {
                    /* use current cop / not seq mismatch */
                    cop = PL_curcop;
                }
            }

            opcode_capture(op, cop, sec);
        } else {
            if (!(PL_op = CALL_FPTR(PL_op->op_ppaddr)(aTHX))) {
                break;
            }
        }
        PERL_ASYNC_CHECK();
    }

    TAINT_NOT;
    return 0;
}

MODULE = Devel::RunOpsAnalyze          PACKAGE = Devel::RunOpsAnalyze

PROTOTYPES: DISABLE

void
start(capture_hash)
    HV *capture_hash
    CODE:
        hv_clear(capture_hash);
        capture     = capture_hash;
        is_runnning = 1;

void
stop()
    CODE:
        is_runnning = 0;

BOOT:
    runops_original = PL_runops;
    PL_runops = analyzer_runops;
