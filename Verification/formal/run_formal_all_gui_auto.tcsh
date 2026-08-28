#!/bin/tcsh

cd /project/verif/users/marianajjar/ws/spline_opt_tape_singed_blocktest

setenv LANG C
setenv LC_ALL C

module load VCFORMAL/X-2025.6-SP2

mkdir -p formal_blocks/formal_submit_logs
mkdir -p formal_blocks/formal_reports

# Make every block TCL exit after reports are written. This makes each GUI
# close when its formal run finishes.
foreach f ( formal_blocks/run_formal_*.tcl )
  set last_line = `tail -1 $f`
  if ( "$last_line" != "exit" ) then
    echo "exit" >> $f
  endif
end

set scripts = ( \
  formal_blocks/run_formal_spi_cfg4.tcl \
  formal_blocks/run_formal_spi_i.tcl \
  formal_blocks/run_formal_spi_q.tcl \
  formal_blocks/run_formal_word_history3.tcl \
  formal_blocks/run_formal_window_latch.tcl \
  formal_blocks/run_formal_sample_shift_I.tcl \
  formal_blocks/run_formal_sample_shift_Q.tcl \
  formal_blocks/run_formal_minaj2_interp.tcl \
  formal_blocks/run_formal_fir20.tcl \
)

foreach s ( $scripts )
  echo "============================================================"
  echo "RUNNING GUI: $s"
  echo "============================================================"

  rm -rf vcst_rtdb
  rm -f vcf.log vcst_command.log

  set base = `basename $s .tcl`
  vcf -gui -f $s |& tee formal_blocks/formal_submit_logs/${base}.gui_submit.log

  set jobid = `grep "Your job" formal_blocks/formal_submit_logs/${base}.gui_submit.log | tail -1 | sed 's/.*job \([0-9][0-9]*\).*/\1/'`

  if ( "$jobid" == "" ) then
    echo "ERROR: no job id found for $s"
    echo "Check formal_blocks/formal_submit_logs/${base}.gui_submit.log and vcf.log"
    exit 1
  endif

  echo "Submitted GUI job $jobid. Waiting..."

  set alive = `qstat | grep -c "^ *$jobid "`
  while ( $alive != 0 )
    qstat | grep "^ *$jobid "
    sleep 30
    set alive = `qstat | grep -c "^ *$jobid "`
  end

  if ( -e vcf.log ) then
    cp vcf.log formal_blocks/formal_submit_logs/${base}.vcf.log
  endif

  echo "DONE: $s"
  echo ""
  sleep 5
end

echo "============================================================"
echo "ALL GUI FORMAL RUNS FINISHED"
echo "Reports: formal_blocks/formal_reports/"
echo "Logs:    formal_blocks/formal_submit_logs/"
echo "============================================================"
