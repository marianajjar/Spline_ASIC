if {![namespace exists ::IMEX]} { namespace eval ::IMEX {} }
set ::IMEX::dataVar [file dirname [file normalize [info script]]]
set ::IMEX::libVar ${::IMEX::dataVar}/libs

create_library_set -name Max\
   -timing\
    [list ${::IMEX::libVar}/mmmc/tcbn65lplvtwc.lib\
    ${::IMEX::libVar}/mmmc/tcbn65lphvtwc.lib\
    ${::IMEX::libVar}/mmmc/tcbn65lpwc.lib\
    ${::IMEX::libVar}/mmmc/tpdn65lpnv2od3wc.lib]
create_library_set -name Typ\
   -timing\
    [list ${::IMEX::libVar}/mmmc/tcbn65lplvttc.lib\
    ${::IMEX::libVar}/mmmc/tcbn65lphvttc.lib\
    ${::IMEX::libVar}/mmmc/tcbn65lptc.lib\
    ${::IMEX::libVar}/mmmc/tpdn65lpnv2od3tc.lib]
create_library_set -name Min\
   -timing\
    [list ${::IMEX::libVar}/mmmc/tcbn65lplvtbc.lib\
    ${::IMEX::libVar}/mmmc/tcbn65lphvtbc.lib\
    ${::IMEX::libVar}/mmmc/tcbn65lpbc.lib\
    ${::IMEX::libVar}/mmmc/tpdn65lpnv2od3bc.lib]
create_rc_corner -name SlowRC\
   -preRoute_res 1\
   -postRoute_res 1\
   -preRoute_cap 1\
   -postRoute_cap 1\
   -postRoute_xcap 1\
   -preRoute_clkres 0\
   -preRoute_clkcap 0\
   -T 125
create_rc_corner -name FastRC\
   -preRoute_res 1\
   -postRoute_res 1\
   -preRoute_cap 1\
   -postRoute_cap 1\
   -postRoute_xcap 1\
   -preRoute_clkres 0\
   -preRoute_clkcap 0\
   -T -40
create_delay_corner -name SlowDC\
   -library_set Max\
   -rc_corner SlowRC
create_delay_corner -name FastDC\
   -library_set Min\
   -rc_corner FastRC
create_constraint_mode -name TypCM\
   -sdc_files\
    [list ${::IMEX::libVar}/mmmc/top_interpolator_dac.sdc]
create_analysis_view -name FastView -constraint_mode TypCM -delay_corner FastDC
create_analysis_view -name SlowView -constraint_mode TypCM -delay_corner SlowDC
set_analysis_view -setup [list SlowView] -hold [list FastView]
