# Add filler and decaps
addFiller -cell FILL1 FILL2 FILL64 FILL32 -prefix FILLER -doDRC -fitGap
ecoRoute -fix_drc
