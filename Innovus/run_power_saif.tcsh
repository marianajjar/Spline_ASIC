#!/bin/tcsh
# GitHub-friendly Innovus launcher.
# Paths are resolved relative to this script; no user workspace path is required.

setenv LANG C
setenv LC_ALL C
setenv TMPDIR /tmp

# Expected location:
#   Innovus/run/<this_file>.tcsh
cd `dirname $0`
set RUN_DIR     = $cwd
set INNOVUS_DIR = `cd $RUN_DIR/.. && pwd`

mkdir -p $INNOVUS_DIR/work
mkdir -p $INNOVUS_DIR/logfile

# Allow a site-specific Innovus executable to be supplied externally:
#   setenv INNOVUS_BIN /path/to/innovus
if ($?INNOVUS_BIN) then
    set INNOVUS = $INNOVUS_BIN
else if (-x /tools/cadence/DDI/22.15/bin/innovus) then
    set INNOVUS = /tools/cadence/DDI/22.15/bin/innovus
else
    set INNOVUS = innovus
endif

# Runs the final SAIF-based post-route power analyses.
#
# Required SAIF files:
#   Innovus/datain/saif/core_sf_L2.saif
#   Innovus/datain/saif/core_sf_L3.saif
#   Innovus/datain/saif/core_sf_L4.saif
#   Innovus/datain/saif/core_sf_L5.saif

set SLOW_TCL = $INNOVUS_DIR/scripts/power_slow_saif.tcl
set FT_TCL   = $INNOVUS_DIR/scripts/power_fast_typ_saif.tcl

foreach F ($SLOW_TCL $FT_TCL)
    if (! -e $F) then
        echo "ERROR: missing $F"
        exit 1
    endif
end

foreach L (2 3 4 5)
    set SF = $INNOVUS_DIR/datain/saif/core_sf_L${L}.saif
    if (! -s $SF) then
        echo "ERROR: missing/empty SAIF: $SF"
        exit 1
    endif
end

cd $INNOVUS_DIR/work

echo "== SlowView SAIF power =="

$INNOVUS \
    -64 \
    -nowin \
    -overwrite \
    -log $INNOVUS_DIR/logfile/power_slow_saif.log \
    -files $SLOW_TCL

set RC = $status

if ($RC != 0) then
    echo "SLOW SAIF POWER FAILED rc=$RC"
    exit $RC
endif

echo "== FastView + TypView SAIF power =="

$INNOVUS \
    -64 \
    -nowin \
    -overwrite \
    -log $INNOVUS_DIR/logfile/power_fast_typ_saif.log \
    -files $FT_TCL

set RC = $status

if ($RC != 0) then
    echo "FAST/TYP SAIF POWER FAILED rc=$RC"
    exit $RC
endif

echo "SAIF_POWER_DONE"
