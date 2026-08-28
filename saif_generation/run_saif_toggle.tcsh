#!/bin/tcsh
# Generate one synthesized-gate-level SAIF for each supported interpolation factor.
#
# Expected repository structure:
#
#   Spline_ASIC/
#   ├── SAIF_Generation/
#   │   ├── run_saif_toggle.tcsh
#   │   ├── tb_saif.sv
#   │   ├── inputs/
#   │   │   ├── iq_L2.txt
#   │   │   ├── iq_L3.txt
#   │   │   ├── iq_L4.txt
#   │   │   └── iq_L5.txt
#   │   └── saif/                  # generated locally
#   ├── Synthesis/
#   │   └── netlist/
#   │       └── top_interpolator_dac.v
#   └── Innovus/
#       └── datain/
#           └── saif/              # staged for Innovus power analysis
#
# Operating modes used by tb_saif.sv:
#   L=2,4 -> 960 MHz and 16-bit serial input words
#   L=3,5 -> 900 MHz and 15-bit serial input words

setenv LANG C
setenv LC_ALL C
setenv TMPDIR /tmp

source /tools/modules/5.5.0/init/tcsh
module load VCS/X-2025.06-1
rehash

# ------------------------------------------------------------------
# Resolve everything relative to this script.
# This allows the script to be launched from any working directory.
# ------------------------------------------------------------------
cd `dirname $0`

set G    = $cwd
set ROOT = `cd $G/.. && pwd`

set INPUT_DIR = $G/inputs
set SAIF_DIR  = $G/saif
set STAGE     = $ROOT/Innovus/datain/saif

mkdir -p $SAIF_DIR
mkdir -p $STAGE

# ------------------------------------------------------------------
# Synthesized core netlist.
# Preferred path matches the cleaned GitHub repository structure.
# A fallback is kept for the original project workspace.
# ------------------------------------------------------------------
set NETLIST = $ROOT/Synthesis/netlist/top_interpolator_dac.v

if (! -e $NETLIST) then
    set NETLIST = $ROOT/synthesis/dataout/top_interpolator_dac.v
endif

if (! -e $NETLIST) then
    echo "ERROR: synthesized netlist not found."
    echo "Checked:"
    echo "  $ROOT/Synthesis/netlist/top_interpolator_dac.v"
    echo "  $ROOT/synthesis/dataout/top_interpolator_dac.v"
    exit 1
endif

# ------------------------------------------------------------------
# Standard-cell simulation models.
#
# Keep foundry models OUT of the public GitHub repository.
# If your installation is different, set TSMC65_SIM_DIR before running:
#
#   setenv TSMC65_SIM_DIR /your/local/path/to/simulation/models
# ------------------------------------------------------------------
if (! $?TSMC65_SIM_DIR) then
    setenv TSMC65_SIM_DIR /data/tsmc/65LP/Synopsys
endif

set LIB_TT  = $TSMC65_SIM_DIR/tcbn65lp.v
set LIB_LVT = $TSMC65_SIM_DIR/tcbn65lplvt.v
set LIB_HVT = $TSMC65_SIM_DIR/tcbn65lphvt.v

foreach F ($LIB_TT $LIB_LVT $LIB_HVT)
    if (! -e $F) then
        echo "ERROR: missing simulation library: $F"
        exit 1
    endif
end

# ------------------------------------------------------------------
# Check local SAIF-generation inputs.
# ------------------------------------------------------------------
if (! -e $G/tb_saif.sv) then
    echo "ERROR: missing $G/tb_saif.sv"
    exit 1
endif

foreach L (2 3 4 5)
    if (! -e $INPUT_DIR/iq_L${L}.txt) then
        echo "ERROR: missing input vector $INPUT_DIR/iq_L${L}.txt"
        exit 1
    endif
end

# ------------------------------------------------------------------
# Build once. Runtime +L selects the mode-specific clock and word size.
# ------------------------------------------------------------------
echo "== build gate-level SAIF simulation =="
echo "ROOT    = $ROOT"
echo "NETLIST = $NETLIST"
echo "WORK    = $G"
echo "STAGE   = $STAGE"

cd $G

rm -rf simv_saif csrc_saif
rm -f comp_saif.log

$VCS_HOME/bin/vcs \
    -full64 \
    -sverilog \
    -kdb \
    -timescale=1ns/1ps \
    +delay_mode_zero \
    -Mdir=csrc_saif \
    -o simv_saif \
    -top tb_top_interpolator_dac \
    $NETLIST \
    $LIB_TT \
    $LIB_LVT \
    $LIB_HVT \
    tb_saif.sv \
    -l comp_saif.log

if ($status != 0 || ! -x ./simv_saif) then
    echo "SAIF BUILD FAILED - see $G/comp_saif.log"
    tail -20 $G/comp_saif.log
    exit 1
endif

# ------------------------------------------------------------------
# Run one mode at a time.
#
# tb_saif.sv reads the common temporary name iq_in_iq_16_12.txt.
# Before each run, copy the appropriate mode-specific vector to it.
# ------------------------------------------------------------------
foreach L (2 3 4 5)

    cp -f $INPUT_DIR/iq_L${L}.txt $G/iq_in_iq_16_12.txt

    set OUTSAIF = $SAIF_DIR/core_sf_L${L}.saif
    set LOGFILE = $G/log_saif_L${L}

    rm -f $OUTSAIF $LOGFILE

    echo ""
    echo "== run L=$L =="

    timeout 900 ./simv_saif \
        +L=$L \
        +SAIF \
        +SAIFFILE=$OUTSAIF \
        -l $LOGFILE >& /dev/null

    set RC = $status

    if ($RC != 0) then
        echo "SAIF RUN FAILED: L=$L status=$RC"
        tail -30 $LOGFILE
        exit 2
    endif

    if (! -s $OUTSAIF) then
        echo "SAIF RUN FAILED: missing/empty $OUTSAIF"
        exit 3
    endif

    # Stage a copy for the Innovus power-analysis flow.
    cp -f $OUTSAIF $STAGE/core_sf_L${L}.saif

    set dur = `grep -m1 -oE 'DURATION[ ]+[0-9.]+' $OUTSAIF | awk '{print $2}'`

    grep -hE 'SAIF mode:|SAIF_PROBE|SAIF_WRITTEN|DONE L=' $LOGFILE | tail -4

    echo "   L=$L DURATION=$dur"
    echo "   saif_bytes=`stat -c%s $OUTSAIF`"
    echo "   staged -> $STAGE/core_sf_L${L}.saif"
end

# The common input filename is only a run-time temporary file.
rm -f $G/iq_in_iq_16_12.txt

echo ""
echo "== distinct SAIF bodies (strip header) =="

foreach L (2 3 4 5)
    sed '1,15d' $SAIF_DIR/core_sf_L${L}.saif | md5sum | \
        awk -v l=$L '{print "L"l" bodymd5="$1}'
end

echo ""
echo "SAIFGEN_DONE"
