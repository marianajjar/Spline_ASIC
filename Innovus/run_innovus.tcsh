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

set TCL = $INNOVUS_DIR/scripts/full.tcl
set LOG = $INNOVUS_DIR/logfile/pnr.log

if (! -e $TCL) then
    echo "ERROR: missing $TCL"
    exit 1
endif

cd $INNOVUS_DIR/work

echo "== Innovus implementation flow =="
echo "TCL : $TCL"
echo "LOG : $LOG"

$INNOVUS \
    -64 \
    -nowin \
    -overwrite \
    -log $LOG \
    -files $TCL

set RC = $status

if ($RC != 0) then
    echo "INNOVUS FLOW FAILED rc=$RC"
    exit $RC
endif

echo "INNOVUS_FLOW_DONE"
